import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../services/chat_service.dart';
import '../../services/firebase_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String productId;
  final String sellerId;
  final String sellerName;
  final String productTitle;

  const ChatScreen({
    super.key,
    required this.chatRoomId,
    required this.productId,
    required this.sellerId,
    required this.sellerName,
    required this.productTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseService _firebaseService = FirebaseService();
  String? _buyerId;

  @override
  void initState() {
    super.initState();
    _loadBuyerId();
    // Scroll to bottom when messages load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  Future<void> _loadBuyerId() async {
    try {
      final chatRoomDoc = await _firestore
          .collection(AppConstants.chatRoomsCollection)
          .doc(widget.chatRoomId)
          .get();
      
      if (chatRoomDoc.exists) {
        final data = chatRoomDoc.data();
        setState(() {
          _buyerId = data?['buyerId'] as String?;
        });
      } else {
        // If chat room doesn't exist yet, extract buyerId from chatRoomId
        // Format: buyerId_sellerId_productId (product-specific)
        // Better approach: get buyerId from current user if they're not seller
        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId != null && currentUserId != widget.sellerId) {
          setState(() {
            _buyerId = currentUserId;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading buyerId: $e');
    }
  }

  Future<String?> _getOtherParticipantName() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return null;

      // If current user is seller, fetch buyer name
      // If current user is buyer, return seller name (already passed as widget.sellerName)
      if (currentUserId == widget.sellerId) {
        // Fetch buyer name
        final buyerId = _buyerId;
        if (buyerId == null || buyerId.isEmpty) return null;
        
        final buyer = await _firebaseService.getUserById(buyerId);
        if (buyer != null && buyer.displayName.isNotEmpty) {
          return buyer.displayName;
        } else if (buyer != null && buyer.email.isNotEmpty) {
          return buyer.email; // Fallback to email if name is empty
        }
        return null;
      } else {
        // Current user is buyer, return seller name
        return widget.sellerName.isNotEmpty ? widget.sellerName : null;
      }
    } catch (e) {
      debugPrint('Error fetching other participant name: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to send messages'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Determine receiver:
    // - If current user is seller, receiver is buyer
    // - If current user is buyer, receiver is seller
    String receiverId;
    if (currentUserId == widget.sellerId) {
      // Current user is seller, receiver is buyer
      receiverId = _buyerId ?? currentUserId; // Fallback to currentUserId if buyerId not loaded
      if (receiverId == currentUserId) {
        // This shouldn't happen, but handle it
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to determine receiver. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else {
      // Current user is buyer, receiver is seller
      receiverId = widget.sellerId;
    }

    try {
      await _chatService.sendMessage(
        chatRoomId: widget.chatRoomId,
        senderId: currentUserId,
        receiverId: receiverId,
        content: text,
        productId: widget.productId,
        sellerId: widget.sellerId,
      );

      _messageController.clear();
      
      // Mark messages as read for current user
      _markMessagesAsRead();

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markMessagesAsRead() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final messages = await _firestore
          .collection(AppConstants.chatRoomsCollection)
          .doc(widget.chatRoomId)
          .collection(AppConstants.messagesCollection)
          .where('receiverId', isEqualTo: currentUserId)
          .where('readStatus', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in messages.docs) {
        batch.update(doc.reference, {'readStatus': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;
    final isSeller = currentUserId == widget.sellerId;

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: FutureBuilder<String?>(
          future: _getOtherParticipantName(),
          builder: (context, nameSnapshot) {
            // Get the other participant's name (buyer if seller, seller if buyer)
            final otherParticipantName = nameSnapshot.data ?? 
                (isSeller ? 'Buyer' : widget.sellerName);
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  otherParticipantName,
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  widget.productTitle,
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chatService.streamMessages(widget.chatRoomId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryYellow),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading messages',
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Mark messages as read when viewing
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _markMessagesAsRead();
                });

                // Scroll to bottom when new messages arrive
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message['senderId'] == currentUserId;
                    
                    return _buildMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),

          // Message Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: AppTheme.secondaryGrey,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFE500), // Brand yellow
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: AppTheme.black),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    // Parse timestamp
    DateTime timestamp;
    if (message['timestamp'] is Timestamp) {
      timestamp = (message['timestamp'] as Timestamp).toDate();
    } else if (message['timestamp'] is String) {
      timestamp = DateTime.parse(message['timestamp']);
    } else {
      timestamp = DateTime.now();
    }

    final timeFormat = DateFormat('HH:mm');
    final messageTime = timeFormat.format(timestamp);
    final text = message['text'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isMe 
                    ? const Color(0xFFFFE500) // Brand yellow for sent messages
                    : AppTheme.secondaryGrey, // Grey for received messages
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: isMe ? AppTheme.black : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        messageTime,
                        style: GoogleFonts.roboto(
                          fontSize: 10,
                          color: isMe
                              ? AppTheme.black.withOpacity(0.6)
                              : AppTheme.textSecondary,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message['readStatus'] == true
                              ? Icons.done_all
                              : Icons.done,
                          size: 12,
                          color: AppTheme.black.withOpacity(0.6),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
