import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get chat room ID: productId_buyerId
  String getChatRoomId(String productId, String buyerId) {
    return '${productId}_$buyerId';
  }

  // Get product-specific chat ID: buyerId_sellerId_productId
  String getProductChatId({
    required String buyerId,
    required String sellerId,
    required String productId,
  }) {
    return '${buyerId}_${sellerId}_$productId';
  }

  // Get or create chat ID between two users (legacy method - kept for backward compatibility)
  // Returns a sorted, combined string of the two IDs to ensure unique room
  String getChatId(String userId1, String userId2) {
    final List<String> ids = [userId1, userId2];
    ids.sort();
    return ids.join('_');
  }

  // Create or get chat room document (product-specific)
  Future<String> createOrGetChatRoom({
    required String sellerId,
    required String buyerId,
    required String productId,
    String? productTitle,
  }) async {
    try {
      // Use product-specific chat ID: buyerId_sellerId_productId
      final roomId = getProductChatId(
        buyerId: buyerId,
        sellerId: sellerId,
        productId: productId,
      );
      
      // Create or update room with participants array
      await _firestore
          .collection(AppConstants.chatRoomsCollection)
          .doc(roomId)
          .set({
        'participants': [sellerId, buyerId], // Array with both user IDs
        'productId': productId,
        'productName': productTitle ?? '', // Store productName
        'sellerId': sellerId,
        'buyerId': buyerId,
        'productTitle': productTitle, // Keep for backward compatibility
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('💬 Chat room created/updated: $roomId (product-specific) with participants: [$sellerId, $buyerId]');
      return roomId;
    } catch (e) {
      throw Exception('Error creating/getting chat room: $e');
    }
  }

  // Send a message
  Future<void> sendMessage({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required String content,
    required String productId,
    required String sellerId,
  }) async {
    try {
      final messageData = {
        'text': content,
        'senderId': senderId,
        'receiverId': receiverId,
        'timestamp': FieldValue.serverTimestamp(),
        'readStatus': false,
        'productId': productId,
      };

      // Add message to messages sub-collection
      await _firestore
          .collection(AppConstants.chatRoomsCollection)
          .doc(chatRoomId)
          .collection(AppConstants.messagesCollection)
          .add(messageData);
      
      // Determine buyerId (the one who is not the seller)
      // If sender is seller, then receiver is buyer; otherwise sender is buyer
      final buyerId = senderId == sellerId ? receiverId : senderId;
      
      // Get productName from chat room document if available
      final chatRoomDoc = await _firestore
          .collection(AppConstants.chatRoomsCollection)
          .doc(chatRoomId)
          .get();
      final productName = chatRoomDoc.data()?['productName'] as String? ?? 
                         chatRoomDoc.data()?['productTitle'] as String? ?? '';
      
      // Update chat room metadata
      await _firestore
          .collection(AppConstants.chatRoomsCollection)
          .doc(chatRoomId)
          .set({
        'productId': productId,
        'productName': productName, // Ensure productName is stored
        'buyerId': buyerId,
        'sellerId': sellerId,
        'participants': [sellerId, buyerId], // Ensure participants array exists
        'lastMessage': content,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('💬 Chat room updated: $chatRoomId, buyerId: $buyerId, sellerId: $sellerId');
    } catch (e) {
      throw Exception('Error sending message: $e');
    }
  }

  // Stream messages for a chat room
  Stream<List<Map<String, dynamic>>> streamMessages(String chatRoomId) {
    return _firestore
        .collection(AppConstants.chatRoomsCollection)
        .doc(chatRoomId)
        .collection(AppConstants.messagesCollection)
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    ...doc.data(),
                  })
              .toList();
          
          // Sort by timestamp client-side to handle null timestamps
          messages.sort((a, b) {
            final aTime = a['timestamp'];
            final bTime = b['timestamp'];
            
            // Handle null timestamps
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1; // Put null timestamps at end
            if (bTime == null) return -1;
            
            // Convert to DateTime for comparison
            DateTime aDate;
            DateTime bDate;
            
            if (aTime is Timestamp) {
              aDate = aTime.toDate();
            } else if (aTime is String) {
              aDate = DateTime.parse(aTime);
            } else {
              return 0;
            }
            
            if (bTime is Timestamp) {
              bDate = bTime.toDate();
            } else if (bTime is String) {
              bDate = DateTime.parse(bTime);
            } else {
              return 0;
            }
            
            return aDate.compareTo(bDate); // Ascending order (oldest first)
          });
          
          return messages;
        });
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatRoomId, String userId) async {
    try {
      // Try new chat_rooms collection first
      final messages = await _firestore
          .collection(AppConstants.chatRoomsCollection)
          .doc(chatRoomId)
          .collection(AppConstants.messagesCollection)
          .where('receiverId', isEqualTo: userId)
          .where('readStatus', isEqualTo: false)
          .get();

      if (messages.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in messages.docs) {
          batch.update(doc.reference, {'readStatus': true});
        }
        await batch.commit();
        return;
      }

      // Fallback to old chats collection (for backward compatibility)
      final oldMessages = await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatRoomId)
          .collection(AppConstants.messagesCollection)
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in oldMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Error marking messages as read: $e');
    }
  }

  // Get user's chat list from chat_rooms collection
  Stream<List<Map<String, dynamic>>> streamUserChats(String userId) {
    return _firestore
        .collection(AppConstants.chatRoomsCollection)
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final chats = snapshot.docs
              .map((doc) => {
                    'chatRoomId': doc.id,
                    'roomId': doc.id,
                    ...doc.data(),
                  })
              .toList();
          
          // Sort by lastMessageTime descending (most recent first)
          chats.sort((a, b) {
            final aTime = a['lastMessageTime'];
            final bTime = b['lastMessageTime'];
            
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1; // Put nulls at end
            if (bTime == null) return -1;
            
            DateTime aDate;
            DateTime bDate;
            
            if (aTime is Timestamp) {
              aDate = aTime.toDate();
            } else if (aTime is String) {
              aDate = DateTime.parse(aTime);
            } else {
              return 0;
            }
            
            if (bTime is Timestamp) {
              bDate = bTime.toDate();
            } else if (bTime is String) {
              bDate = DateTime.parse(bTime);
            } else {
              return 0;
            }
            
            return bDate.compareTo(aDate); // Descending (newest first)
          });
          
          return chats;
        });
  }

  // Delete chat
  Future<void> deleteChat(String chatId) async {
    try {
      // Delete all messages
      final messages = await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .collection(AppConstants.messagesCollection)
          .get();

      final batch = _firestore.batch();
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Delete chat document
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .delete();
    } catch (e) {
      throw Exception('Error deleting chat: $e');
    }
  }
}



