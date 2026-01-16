import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../../core/theme/app_theme.dart';
import '../../services/chat_service.dart';
import '../../services/firebase_service.dart';
import '../../models/user_model.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();
  final FirebaseService _firebaseService = FirebaseService();
  
  // Gold theme color
  static const Color goldColor = Color(0xFFdbc156);

  // Get the other participant's ID from the chat room
  // Logic: If currentUserId == buyerId, return sellerId. If currentUserId == sellerId, return buyerId.
  String _getOtherParticipantId(Map<String, dynamic> chatRoom, String currentUserId) {
    final sellerId = chatRoom['sellerId']?.toString() ?? '';
    final buyerId = chatRoom['buyerId']?.toString() ?? '';
    
    // Primary logic: Compare with buyerId and sellerId
    if (currentUserId == buyerId && sellerId.isNotEmpty) {
      // Current user is buyer, so return seller ID
      return sellerId;
    } else if (currentUserId == sellerId && buyerId.isNotEmpty) {
      // Current user is seller, so return buyer ID
      return buyerId;
    }
    
    // Fallback: Try participants array if buyerId/sellerId comparison didn't work
    final participants = chatRoom['participants'];
    if (participants is List && participants.isNotEmpty) {
      for (final participant in participants) {
        final participantId = participant.toString();
        if (participantId.isNotEmpty && participantId != currentUserId) {
          return participantId;
        }
      }
    }
    
    // Final fallback: Return the non-matching ID
    if (sellerId.isNotEmpty && sellerId != currentUserId) {
      return sellerId;
    } else if (buyerId.isNotEmpty && buyerId != currentUserId) {
      return buyerId;
    }
    
    return '';
  }


  // Format timestamp for display
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is String) {
      dateTime = DateTime.parse(timestamp);
    } else {
      return '';
    }
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;
    
    if (currentUserId == null) {
      return Scaffold(
        backgroundColor: AppTheme.white,
        appBar: AppBar(
          title: Text(
            'Chats',
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppTheme.white,
          elevation: 0,
        ),
        body: const Center(
          child: Text('Please log in to view chats'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(
          'Chats',
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _chatService.streamUserChats(currentUserId),
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
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading chats',
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No conversations yet',
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start chatting with buyers or sellers!',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final roomId = chat['roomId'] ?? chat['chatRoomId'] ?? '';
              final lastMessage = chat['lastMessage'] ?? '';
              final lastMessageTime = chat['lastMessageTime'];
              final productTitle = chat['productTitle'] ?? chat['productName'] ?? '';
              final productId = chat['productId'] ?? '';
              final sellerId = chat['sellerId'] ?? '';
              final buyerId = chat['buyerId'] ?? '';
              
              // Get the other participant's ID
              String otherParticipantId = _getOtherParticipantId(chat, currentUserId);
              
              // If empty, try to get from participants array directly
              if (otherParticipantId.isEmpty) {
                final participants = chat['participants'];
                if (participants is List) {
                  for (final p in participants) {
                    final pid = p.toString();
                    if (pid.isNotEmpty && pid != currentUserId) {
                      otherParticipantId = pid;
                      break;
                    }
                  }
                }
              }
              
              // If still empty and we have sellerId/buyerId, use the opposite
              if (otherParticipantId.isEmpty) {
                if (currentUserId == sellerId && buyerId.isNotEmpty) {
                  otherParticipantId = buyerId;
                } else if (currentUserId == buyerId && sellerId.isNotEmpty) {
                  otherParticipantId = sellerId;
                }
              }
              
              // If we still don't have a valid participant ID, show placeholder
              if (otherParticipantId.isEmpty) {
                return ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.lightGrey,
                    child: const Text('?', style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                  title: Text(
                    'Unknown User',
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  subtitle: productTitle.isNotEmpty
                      ? Text(
                          productTitle,
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  trailing: lastMessageTime != null
                      ? Text(
                          _formatTimestamp(lastMessageTime),
                          style: GoogleFonts.roboto(fontSize: 12, color: AppTheme.textSecondary),
                        )
                      : null,
                  enabled: false,
                );
              }
              
              // Use FutureBuilder to fetch the "Other User's" displayName and photoUrl
              return FutureBuilder<UserModel?>(
                future: _firebaseService.getUserById(otherParticipantId).catchError((error) {
                  debugPrint('⚠️ Error fetching user $otherParticipantId: $error');
                  return null; // Return null on error instead of throwing
                }),
                builder: (context, userSnapshot) {
                  String displayName = '';
                  String? photoUrl;
                  
                  // Role-based display: Fetch the "Other User's" data
                  // If currentUserId == buyerId: show seller's name and photo
                  // If currentUserId == sellerId: show buyer's name and photo
                  if (userSnapshot.hasData && userSnapshot.data != null) {
                    try {
                      final user = userSnapshot.data!;
                      // Get displayName from users collection, fallback to email if displayName is empty
                      if (user.displayName.isNotEmpty) {
                        displayName = user.displayName;
                      } else if (user.email.isNotEmpty) {
                        displayName = user.email;
                      } else {
                        displayName = 'User'; // Fallback if both are empty
                      }
                      photoUrl = user.photoUrl;
                    } catch (e) {
                      debugPrint('⚠️ Error parsing user data: $e');
                      displayName = 'User';
                    }
                  } else if (userSnapshot.hasError) {
                    // If there's an error, show fallback
                    debugPrint('⚠️ Error in userSnapshot: ${userSnapshot.error}');
                    displayName = 'User';
                  } else if (userSnapshot.connectionState == ConnectionState.waiting) {
                    // While loading, displayName remains empty - will show grayed placeholder
                    displayName = '';
                  } else {
                    // No data found - show fallback
                    displayName = 'User';
                  }
                  
                  // Build CircleAvatar with photoUrl or initials
                  Widget avatar;
                  
                  if (photoUrl != null && photoUrl.isNotEmpty && photoUrl.startsWith('http')) {
                    // Show profile picture with error handling
                    avatar = ClipOval(
                      child: Image.network(
                        photoUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback to initials if image fails to load
                          return CircleAvatar(
                            radius: 20,
                            backgroundColor: goldColor,
                            child: Text(
                              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                              style: GoogleFonts.roboto(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.black,
                                fontSize: 16,
                              ),
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          // Show loading placeholder with gold background
                          return CircleAvatar(
                            radius: 20,
                            backgroundColor: goldColor,
                            child: displayName.isNotEmpty
                                ? Text(
                                    displayName[0].toUpperCase(),
                                    style: GoogleFonts.roboto(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.black,
                                      fontSize: 16,
                                    ),
                                  )
                                : const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.black),
                                    ),
                                  ),
                          );
                        },
                      ),
                    );
                  } else {
                    // Show initials fallback with gold background
                    avatar = CircleAvatar(
                      radius: 20,
                      backgroundColor: goldColor,
                      child: userSnapshot.connectionState == ConnectionState.waiting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.black),
                              ),
                            )
                          : Text(
                              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                              style: GoogleFonts.roboto(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.black,
                                fontSize: 16,
                              ),
                            ),
                    );
                  }
                  
                  // Check loading state
                  final bool isLoading = userSnapshot.connectionState == ConnectionState.waiting;
                  final bool hasData = displayName.isNotEmpty && displayName != 'User';
                  
                  // If still loading, show placeholder but with actual product info
                  if (isLoading && !hasData) {
                    return Opacity(
                      opacity: 0.6,
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.lightGrey,
                          child: const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textSecondary),
                            ),
                          ),
                        ),
                        title: Container(
                          height: 16,
                          width: 120,
                          decoration: BoxDecoration(
                            color: AppTheme.lightGrey,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (productTitle.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  productTitle,
                                  style: GoogleFonts.roboto(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            Container(
                              height: 14,
                              width: 180,
                              decoration: BoxDecoration(
                                color: AppTheme.lightGrey,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                        trailing: lastMessageTime != null
                            ? Text(
                                _formatTimestamp(lastMessageTime),
                                style: GoogleFonts.roboto(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              )
                            : null,
                      ),
                    );
                  }
                  
                  // Show actual data when loaded (or fallback if data unavailable)
                  final finalDisplayName = hasData ? displayName : 'User';
                  final bool hasValidPhoto = hasData && photoUrl != null && photoUrl.isNotEmpty && photoUrl.startsWith('http');
                  
                  return ListTile(
                    leading: hasValidPhoto
                        ? avatar
                        : CircleAvatar(
                            radius: 20,
                            backgroundColor: goldColor,
                            child: Text(
                              finalDisplayName[0].toUpperCase(),
                              style: GoogleFonts.roboto(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.black,
                                fontSize: 16,
                              ),
                            ),
                          ),
                    title: Text(
                      finalDisplayName,
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Name subtitle - always show if available (product-specific chat)
                        if (productTitle.isNotEmpty) ...[
                          Text(
                            productTitle,
                            style: GoogleFonts.roboto(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          lastMessage.isNotEmpty ? lastMessage : 'No messages yet',
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            color: lastMessage.isNotEmpty 
                                ? AppTheme.textPrimary 
                                : AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    trailing: lastMessageTime != null
                        ? Text(
                            _formatTimestamp(lastMessageTime),
                            style: GoogleFonts.roboto(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          )
                        : null,
                    onTap: () {
                      // Navigate to ChatScreen with product-specific chatRoomId (buyerId_sellerId_productId)
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            chatRoomId: roomId,
                            productId: productId,
                            sellerId: sellerId,
                            sellerName: displayName, // Real name from users collection
                            productTitle: productTitle.isNotEmpty ? productTitle : 'Product',
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
