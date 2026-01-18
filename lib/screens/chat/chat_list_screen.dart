import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../services/chat_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();
  
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
                  const Icon(
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
                    const Icon(
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
                  leading: const CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.lightGrey,
                    child: Text('?', style: TextStyle(color: AppTheme.textSecondary)),
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
              
              // Fetch Real-time Data: Use StreamBuilder for real-time user data updates
              // Identify the Other User: If currentUserId == buyerId, fetch sellerId profile
              // If currentUserId == sellerId, fetch buyerId profile
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherParticipantId)
                    .snapshots(),
                builder: (context, userSnapshot) {
                  String displayName = '';
                  String? photoUrl;
                  
                  // Map UI Elements: Extract displayName and photoUrl from userData
                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    try {
                      final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                      if (userData != null) {
                        // Replace hardcoded 'User' text with userData['displayName']
                        displayName = userData['displayName']?.toString().trim() ?? '';
                        
                        // Fallback to email if displayName is empty
                        if (displayName.isEmpty) {
                          displayName = userData['email']?.toString().trim() ?? '';
                        }
                        
                        // Never show 'User' - show email or leave empty for loading
                        if (displayName.isEmpty) {
                          displayName = userData['email']?.toString().trim() ?? '';
                        }
                        
                        // Get photoUrl for CircleAvatar
                        photoUrl = userData['photoUrl']?.toString().trim();
                      }
                    } catch (e) {
                      debugPrint('⚠️ Error parsing user data: $e');
                      // On error, try to get email as fallback
                      try {
                        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                        displayName = userData?['email']?.toString().trim() ?? '';
                      } catch (_) {
                        displayName = '';
                      }
                    }
                  } else if (userSnapshot.hasError) {
                    // Error Handling: If photoUrl is empty or user data has error
                    debugPrint('⚠️ Error in userSnapshot: ${userSnapshot.error}');
                    displayName = ''; // Leave empty to show loading state
                  } else if (userSnapshot.connectionState == ConnectionState.waiting) {
                    // While loading, displayName remains empty - will show loading placeholder
                    displayName = '';
                  } else {
                    // No data found - show loading state
                    displayName = '';
                  }
                  
                  // Map UI Elements: Build CircleAvatar with photoUrl or default person icon
                  Widget avatar;
                  
                  // Error Handling: Check if photoUrl is valid
                  final bool hasValidPhotoUrl = photoUrl != null && 
                      photoUrl.isNotEmpty && 
                      (photoUrl.startsWith('http://') || photoUrl.startsWith('https://'));
                  
                  if (hasValidPhotoUrl && displayName.isNotEmpty) {
                    // Replace yellow 'U' icon with CircleAvatar(backgroundImage: NetworkImage(photoUrl))
                    avatar = CircleAvatar(
                      radius: 20,
                      backgroundColor: goldColor,
                      backgroundImage: NetworkImage(photoUrl),
                      onBackgroundImageError: (exception, stackTrace) {
                        debugPrint('⚠️ Error loading profile image: $exception');
                      },
                      child: userSnapshot.connectionState == ConnectionState.waiting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.black),
                              ),
                            )
                          : null,
                    );
                  } else if (displayName.isNotEmpty) {
                    // Show default person icon with initials if photoUrl is empty
                    avatar = CircleAvatar(
                      radius: 20,
                      backgroundColor: goldColor,
                      child: Text(
                        displayName[0].toUpperCase(),
                        style: GoogleFonts.roboto(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.black,
                          fontSize: 16,
                        ),
                      ),
                    );
                  } else {
                    // Error Handling: Show CircularProgressIndicator or default person icon while loading
                    avatar = CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.lightGrey,
                      child: userSnapshot.connectionState == ConnectionState.waiting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textSecondary),
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              color: AppTheme.textSecondary,
                              size: 20,
                            ),
                    );
                  }
                  
                  // Error Handling: Check loading state and show appropriate UI
                  final bool isLoading = userSnapshot.connectionState == ConnectionState.waiting;
                  final bool hasData = displayName.isNotEmpty;
                  
                  // If still loading and no data yet, show placeholder with loading indicator
                  if (isLoading && !hasData) {
                    return Opacity(
                      opacity: 0.6,
                      child: ListTile(
                        leading: const CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.lightGrey,
                          child: SizedBox(
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
                  
                  // Map UI Elements: Use displayName (never show hardcoded 'User')
                  // If displayName is still empty, try to get email from snapshot directly
                  String finalDisplayName = displayName;
                  if (finalDisplayName.isEmpty && userSnapshot.hasData && userSnapshot.data!.exists) {
                    try {
                      final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                      finalDisplayName = userData?['email']?.toString().trim() ?? 
                                        userData?['displayName']?.toString().trim() ?? 
                                        'User';
                    } catch (_) {
                      finalDisplayName = 'User';
                    }
                  } else if (finalDisplayName.isEmpty) {
                    // Final fallback - shouldn't happen but handle gracefully
                    finalDisplayName = 'User';
                  }
                  
                  // Fetch Product Data: Each chat document contains a productId
                  // Use StreamBuilder to fetch that specific product's document from the products collection
                  return StreamBuilder<DocumentSnapshot>(
                    stream: productId.isNotEmpty
                        ? FirebaseFirestore.instance
                            .collection('products')
                            .doc(productId)
                            .snapshots()
                        : null,
                    builder: (context, productSnapshot) {
                      String? productImageUrl;
                      
                      // Extract product image URL from productData
                      if (productSnapshot.hasData && 
                          productSnapshot.data != null && 
                          productSnapshot.data!.exists) {
                        try {
                          final productData = productSnapshot.data!.data() as Map<String, dynamic>?;
                          if (productData != null) {
                            final imageUrls = productData['imageUrls'];
                            if (imageUrls is List && imageUrls.isNotEmpty) {
                              productImageUrl = imageUrls[0]?.toString();
                            }
                          }
                        } catch (e) {
                          debugPrint('⚠️ Error extracting product image URL: $e');
                        }
                      }
                      
                      // Fix User Identity: Ensure title shows displayName and leading shows photoUrl
                      // Map UI Elements: Replace hardcoded 'User' text with userData['displayName']
                      // Replace yellow 'U' icon with CircleAvatar(backgroundImage: NetworkImage(photoUrl))
                      return ListTile(
                        leading: avatar, // Shows photoUrl from users collection
                        title: Text(
                          finalDisplayName, // Use displayName from users collection, never hardcoded 'User'
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
                        // Display Image on Right: Use trailing property to display the product image
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Product image on the right with rounded corners
                            if (productImageUrl != null && 
                                productImageUrl.isNotEmpty &&
                                (productImageUrl.startsWith('http://') || 
                                 productImageUrl.startsWith('https://')))
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8), // Rounded corners to match VinTrade theme
                                child: Image.network(
                                  productImageUrl,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Fallback if image fails to load
                                    return Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: AppTheme.lightGrey,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        color: AppTheme.textSecondary,
                                        size: 24,
                                      ),
                                    );
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    // Show loading placeholder with rounded corners
                                    return Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: AppTheme.lightGrey,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textSecondary),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              )
                            else if (productSnapshot.connectionState == ConnectionState.waiting)
                              // Show loading placeholder while fetching product
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: AppTheme.lightGrey,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textSecondary),
                                    ),
                                  ),
                                ),
                              )
                            else
                              // Fallback if no product image available
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: AppTheme.lightGrey,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.shopping_bag_outlined,
                                  color: AppTheme.textSecondary,
                                  size: 24,
                                ),
                              ),
                            // Timestamp below the product image
                            if (lastMessageTime != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _formatTimestamp(lastMessageTime),
                                style: GoogleFonts.roboto(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                        onTap: () {
                          // Navigate to ChatScreen with product-specific chatRoomId (buyerId_sellerId_productId)
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                chatRoomId: roomId,
                                productId: productId,
                                sellerId: sellerId,
                                sellerName: finalDisplayName, // Real name from users collection
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
          );
        },
      ),
    );
  }
}
