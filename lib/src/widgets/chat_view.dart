import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../state/livechat_controller.dart';
import 'rating_view.dart';

class LivechatView extends StatefulWidget {
  final String title;
  final Color primaryColor;

  const LivechatView({
    super.key,
    this.title = 'Live Chat',
    this.primaryColor = Colors.blueAccent,
  });

  @override
  State<LivechatView> createState() => _LivechatViewState();
}

class _LivechatViewState extends State<LivechatView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  Timer? _typingThrottle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
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

  @override
  Widget build(BuildContext context) {
    return Consumer<LivechatController>(
      builder: (context, controller, child) {
        if (!controller.isInitialized && controller.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.workspace?.name ?? widget.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  controller.workspace?.responseTime != null
                      ? 'Reply in ${controller.workspace!.responseTime}'
                      : 'Usually replies in minutes',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.normal,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            backgroundColor: widget.primaryColor,
            foregroundColor: Colors.white,
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () =>
                          controller.fetchMessages(roomId: controller.roomId),
                      child: controller.messages.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.6,
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32.0),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.chat_bubble_outline,
                                            size: 64,
                                            color: widget.primaryColor
                                                .withOpacity(0.2),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            controller
                                                            .workspace
                                                            ?.autoReplyEnabled ==
                                                        true &&
                                                    controller
                                                            .workspace
                                                            ?.autoReplyMessage !=
                                                        null
                                                ? controller
                                                      .workspace!
                                                      .autoReplyMessage!
                                                : 'Start a conversation!',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          if (controller
                                                      .workspace
                                                      ?.autoReplyEnabled !=
                                                  true ||
                                              controller
                                                      .workspace
                                                      ?.autoReplyMessage ==
                                                  null)
                                            Text(
                                              'Type a message below to begin.',
                                              style: TextStyle(
                                                color: Colors.grey[400],
                                                fontSize: 14,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: controller.messages.length,
                              itemBuilder: (context, index) {
                                final message = controller.messages[index];
                                final messages = controller.messages;

                                // Determine if this is the first/last message in a group
                                final isFirstInGroup =
                                    index == 0 ||
                                    messages[index - 1].senderType !=
                                        message.senderType;
                                final isLastInGroup =
                                    index == messages.length - 1 ||
                                    messages[index + 1].senderType !=
                                        message.senderType;

                                return _ChatBubble(
                                  message: message,
                                  primaryColor: widget.primaryColor,
                                  isFirstInGroup: isFirstInGroup,
                                  isLastInGroup: isLastInGroup,
                                  onSwipe: () =>
                                      controller.setReplyingTo(message),
                                  onLongPress: () => _showReactions(
                                    context,
                                    controller,
                                    message,
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  if (controller.isAgentTyping)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Support is typing...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (controller.replyingTo != null)
                    _buildReplyOverlay(controller),
                  _buildInputArea(controller),
                  if (controller.roomStatus == RoomStatus.resolved)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 24,
                      ),
                      color: Colors.amber[50],
                      child: SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'This conversation was marked as resolved.',
                              style: TextStyle(
                                color: Colors.amber[900],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sending a new message will reopen it.',
                              style: TextStyle(
                                color: Colors.amber[800],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              if (controller.showRatingPrompt)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: RatingView(primaryColor: widget.primaryColor),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputArea(LivechatController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.add_circle_outline,
                  color: Colors.grey[600],
                  size: 28,
                ),
                onPressed: () => _showAttachmentOptions(context, controller),
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Message',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    fillColor: Colors.grey[100],
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  maxLines: 5,
                  minLines: 1,
                  onChanged: (text) => _onTextChanged(text, controller),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  Icons.send_rounded,
                  color: widget.primaryColor,
                  size: 28,
                ),
                onPressed: () => _handleSend(controller),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAttachmentOptions(
    BuildContext context,
    LivechatController controller,
  ) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildOption(
                icon: Icons.image,
                label: 'Image',
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (image != null) {
                    await controller.sendFile(image.path);
                    _scrollToBottom();
                  }
                },
              ),
              _buildOption(
                icon: Icons.camera_alt,
                label: 'Camera',
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (image != null) {
                    await controller.sendFile(image.path);
                    _scrollToBottom();
                  }
                },
              ),
              _buildOption(
                icon: Icons.insert_drive_file,
                label: 'Document',
                onTap: () async {
                  Navigator.pop(context);
                  FilePickerResult? result = await FilePicker.platform
                      .pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf'],
                      );
                  if (result != null) {
                    await controller.sendFile(result.files.single.path!);
                    _scrollToBottom();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: widget.primaryColor.withOpacity(0.1),
            child: Icon(icon, color: widget.primaryColor, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _handleSend(LivechatController controller) {
    if (_messageController.text.trim().isEmpty) return;
    controller.sendMessage(_messageController.text);
    _messageController.clear();
    _typingThrottle?.cancel(); // Clear throttle on send
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _onTextChanged(String text, LivechatController controller) {
    if (text.isEmpty) return;
    if (controller.roomId == null) return;

    if (_typingThrottle == null || !_typingThrottle!.isActive) {
      _typingThrottle = Timer(const Duration(seconds: 2), () {});
      controller.sendTyping(controller.roomId!);
    }
  }

  Widget _buildReplyOverlay(LivechatController controller) {
    final reply = controller.replyingTo!;
    final senderName =
        reply.senderName ??
        (reply.senderType == SenderType.visitor ? 'YOU' : 'AGENT');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: widget.primaryColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    senderName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: widget.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reply.contentType == ContentType.image
                        ? 'Image'
                        : reply.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20, color: Colors.grey),
              onPressed: () => controller.setReplyingTo(null),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  void _showReactions(
    BuildContext context,
    LivechatController controller,
    LivechatMessage message,
  ) {
    final reactions = ['❤️', '👍', '😂', '😮', '😢', '🔥'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: reactions
              .map(
                (emoji) => InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    controller.addReaction(message.id, emoji);
                  },
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingThrottle?.cancel();
    super.dispose();
  }
}

class _ChatBubble extends StatelessWidget {
  final LivechatMessage message;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final VoidCallback onSwipe;
  final VoidCallback onLongPress;
  final Color primaryColor;

  const _ChatBubble({
    required this.message,
    required this.primaryColor,
    required this.onSwipe,
    required this.onLongPress,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
  });

  @override
  Widget build(BuildContext context) {
    if (message.senderType == SenderType.system) {
      return _buildSystemMessage();
    }
    final isMe = message.senderType == SenderType.visitor;
    final isImage = message.contentType == ContentType.image;
    final timeStr = DateFormat('jm').format(message.createdAt);

    return Padding(
      padding: EdgeInsets.only(
        bottom: isLastInGroup ? 12 : 3,
        top: isFirstInGroup && !isMe ? 0 : 0,
      ),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Only show avatar for the last message in a group, or reserve space
          if (!isMe)
            isLastInGroup
                ? _buildAvatar()
                : const SizedBox(width: 32), // Reserve space for alignment
          const SizedBox(width: 8),
          Flexible(
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! < -100) {
                  onSwipe();
                }
              },
              onLongPress: onLongPress,
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: isImage
                            ? const EdgeInsets.all(4)
                            : const EdgeInsets.only(
                                left: 14,
                                right: 14,
                                top: 8,
                                bottom: 14,
                              ),
                        decoration: BoxDecoration(
                          color: isMe ? primaryColor : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 16),
                          ),
                        ),
                        child: isImage
                            ? _buildImage(context)
                            : message.contentType == ContentType.pdf
                            ? _buildPdf(context)
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (message.replyTo != null)
                                    _buildQuote(context, isMe),
                                  Text(
                                    message.content,
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                ],
                              ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 10,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              timeStr,
                              style: TextStyle(
                                color: (isMe && !isImage)
                                    ? Colors.white.withOpacity(0.7)
                                    : Colors.grey[400],
                                fontSize: 9,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.done_all,
                                size: 13,
                                color: isImage
                                    ? Colors.blueAccent
                                    : Colors.white.withOpacity(0.8),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (message.reactions.isNotEmpty)
                        Positioned(
                          bottom: -10,
                          right: isMe ? 0 : null,
                          left: isMe ? null : 0,
                          child: _buildReactionsDisplay(),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isMe) _buildAvatar(),
        ],
      ),
    );
  }

  Widget _buildReactionsDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: message.reactions.keys
            .map(
              (emoji) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Text(emoji, style: const TextStyle(fontSize: 12)),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildQuote(BuildContext context, bool isMe) {
    final quote = message.replyTo!;
    final senderName =
        quote.senderName ??
        (quote.senderType == SenderType.visitor ? 'VISITOR' : 'AGENT');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withOpacity(0.15)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white70 : primaryColor,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderName.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isMe ? Colors.white : primaryColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            quote.contentType == ContentType.image
                ? 'Sent a image: ${quote.content}'
                : quote.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isMe ? Colors.white.withOpacity(0.9) : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final avatarUrl = message.senderAvatarUrl;
    final isAgent = message.senderType == SenderType.agent;

    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.grey[200],
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
      child: avatarUrl == null
          ? Icon(
              isAgent ? Icons.support_agent : Icons.person,
              size: 14,
              color: Colors.grey[400],
            )
          : null,
    );
  }

  Widget _buildSystemMessage() {
    final isReassignment = message.content.startsWith('Reassigned to');
    final timeStr = DateFormat('MMM d, h:mm a').format(message.createdAt);

    if (isReassignment) {
      // Beautiful divider with horizontal lines for reassignment events
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.grey[300]!,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.swap_horiz_rounded,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '• $timeStr',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.grey[300]!,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Default system message style
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        message.fileUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 200,
            height: 200,
            color: Colors.grey[100],
            child: const Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }

  Widget _buildPdf(BuildContext context) {
    final isMe = message.senderType == SenderType.visitor;
    return InkWell(
      onTap: () async {
        if (message.fileUrl != null) {
          final uri = Uri.parse(message.fileUrl!);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.picture_as_pdf,
            color: isMe ? Colors.white : primaryColor,
            size: 28,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message.fileName ?? 'Document.pdf',
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
