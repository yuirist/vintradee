import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message_model.dart';
import '../services/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatProvider with ChangeNotifier {
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<ChatMessageModel> _messages = [];
  List<Map<String, dynamic>> _chatList = [];
  bool _isLoading = false;
  String? _error;

  List<ChatMessageModel> get messages => _messages;
  List<Map<String, dynamic>> get chatList => _chatList;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get or create chat ID
  String getChatId(String userId1, String userId2) {
    return _chatService.getChatId(userId1, userId2);
  }

  // Load messages for a chat
  void loadMessages(String chatId) {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _chatService.streamMessages(chatId).listen(
      (messagesData) {
        // Map Firestore data to ChatMessageModel objects
        try {
          _messages = messagesData.map((data) {
            // Convert Firestore data to ChatMessageModel
            // Handle timestamp conversion
            DateTime timestamp;
            if (data['timestamp'] is Timestamp) {
              timestamp = (data['timestamp'] as Timestamp).toDate();
            } else if (data['timestamp'] is String) {
              timestamp = DateTime.parse(data['timestamp']);
            } else {
              timestamp = DateTime.now();
            }

            return ChatMessageModel(
              id: data['id'] ?? '',
              chatId: chatId,
              senderId: data['senderId'] ?? '',
              receiverId: data['receiverId'] ?? '',
              content: data['text'] ?? data['content'] ?? '', // Support both 'text' and 'content'
              type: MessageType.text, // Default to text
              timestamp: timestamp,
              isRead: data['readStatus'] ?? data['isRead'] ?? false,
              productId: data['productId'],
            );
          }).toList();
          
          _isLoading = false;
          _error = null;
          notifyListeners();
        } catch (e) {
          _isLoading = false;
          _error = 'Error parsing messages: $e';
          notifyListeners();
        }
      },
      onError: (error) {
        _isLoading = false;
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  // Send message
  Future<bool> sendMessage({
    required String receiverId,
    required String content,
    String? productId,
    String? chatRoomId,
    String? sellerId,
    MessageType type = MessageType.text,
  }) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return false;

      // If chatRoomId and sellerId are provided, use the new chat room structure
      if (chatRoomId != null && sellerId != null && productId != null) {
        await _chatService.sendMessage(
          chatRoomId: chatRoomId,
          senderId: currentUserId,
          receiverId: receiverId,
          content: content,
          productId: productId,
          sellerId: sellerId,
        );
        return true;
      }

      // Fallback to old chat structure (for backward compatibility)
      // Note: This won't work with the new chat service structure
      // Consider removing this fallback if not needed
      throw Exception('Chat room ID, product ID, and seller ID are required');
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Load user's chat list
  void loadChatList() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _chatService.streamUserChats(userId).listen(
      (chats) {
        _chatList = chats;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _chatService.markMessagesAsRead(chatId, userId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Clear messages (when leaving chat)
  void clearMessages() {
    _messages = [];
    notifyListeners();
  }
}



