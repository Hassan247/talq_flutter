import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../state/livechat_controller.dart';
import '../theme/livechat_theme.dart';
import 'messages_list_view.dart';
import 'rating_view.dart';

class LivechatView extends StatefulWidget {
  final String title;
  final LivechatTheme theme;
  final bool isNewConversation;

  const LivechatView({
    super.key,
    this.title = 'Live Chat',
    this.theme = const LivechatTheme(),
    this.isNewConversation = false,
  });

  @override
  State<LivechatView> createState() => _LivechatViewState();
}

class _LivechatViewState extends State<LivechatView>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  Timer? _typingThrottle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      // notify controller that chat is now visible
      context.read<LivechatController>().setChatVisible(true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<LivechatController>().setChatVisible(false);
    _messageController.dispose();
    _scrollController.dispose();
    _typingThrottle?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    context.read<LivechatController>().setLifecycleState(state);
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

  String _formatResponseTime(String? time) {
    if (time == null) return 'Usually replies in minutes';
    if (time.toLowerCase().trim().startsWith('replies') ||
        time.toLowerCase().trim().startsWith('usually')) {
      return time;
    }
    return 'Reply in $time';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LivechatController>(
      builder: (context, controller, child) {
        debugPrint(
          '[LivechatView] build called: roomId=${controller.roomId}, messages.length=${controller.messages.length}, isNewConversation=${widget.isNewConversation}',
        );

        if (!controller.isInitialized && controller.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final hasMessages = controller.messages.isNotEmpty;
        final shouldRedirect = widget.isNewConversation && hasMessages;

        return PopScope(
          canPop: !shouldRedirect,
          onPopInvoked: (didPop) {
            if (didPop) {
              context.read<LivechatController>().setChatVisible(false);
              return;
            }

            if (shouldRedirect) {
              context.read<LivechatController>().setChatVisible(false);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => MessagesListView(theme: widget.theme),
                ),
              );
            }
          },
          child: Scaffold(
            backgroundColor: widget.theme.backgroundColor,
            appBar: AppBar(
              systemOverlayStyle: SystemUiOverlayStyle.dark,
              elevation: 0,
              centerTitle: true,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    controller.currentRoom?.assigneeName ??
                        controller.workspace?.name ??
                        widget.title,
                    style: widget.theme.titleStyle,
                  ),
                  Text(
                    _formatResponseTime(controller.workspace?.responseTime),
                    style: widget.theme.subtitleStyle,
                  ),
                ],
              ),
              backgroundColor: widget.theme.surfaceColor,
              foregroundColor: widget.theme.titleStyle.color,
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: widget.theme.titleStyle.color,
                    size: 24,
                  ),
                  onPressed: () {
                    context.read<LivechatController>().setChatVisible(false);
                    Navigator.pop(context);
                  },
                ),
              ],
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
                                        MediaQuery.of(context).size.height *
                                        0.6,
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
                                              color: Colors.grey[300],
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              controller
                                                              .workspace
                                                              ?.welcomeMessage !=
                                                          null &&
                                                      controller
                                                          .workspace!
                                                          .welcomeMessage!
                                                          .isNotEmpty
                                                  ? controller
                                                        .workspace!
                                                        .welcomeMessage!
                                                  : 'Start a conversation!',
                                              textAlign: TextAlign.center,
                                              style: widget.theme.bodyStyle
                                                  .copyWith(
                                                    color: Colors.grey[600],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Type a message below to begin.',
                                              style: widget.theme.subtitleStyle
                                                  .copyWith(fontSize: 14),
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
                                    theme: widget.theme,
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
                              style: widget.theme.subtitleStyle.copyWith(
                                fontSize: 12,
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
                    child: RatingView(theme: widget.theme),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputArea(LivechatController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: widget.theme.surfaceColor,
      child: SafeArea(
        child: Row(
          children: [
            // Floating pill input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: widget.theme.backgroundColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    // Plus Button
                    GestureDetector(
                      onTap: () => _showAttachmentOptions(context, controller),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: widget.theme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type something',
                          hintStyle: widget.theme.subtitleStyle.copyWith(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          isDense: true,
                        ),
                        minLines: 1,
                        maxLines: 4,
                        style: widget.theme.bodyStyle.copyWith(fontSize: 16),
                        onChanged: (text) => _onTextChanged(text, controller),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send Button
            GestureDetector(
              onTap: () => _handleSend(controller),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.send_rounded,
                  color: widget.theme.primaryColor,
                  size: 24,
                ),
              ),
            ),
          ],
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
            backgroundColor: widget.theme.primaryColor.withOpacity(0.1),
            child: Icon(icon, color: widget.theme.primaryColor, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: widget.theme.subtitleStyle.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
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
        color: widget.theme.surfaceColor,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: widget.theme.primaryColor,
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
                    style: widget.theme.titleStyle.copyWith(
                      fontSize: 12,
                      color: widget.theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reply.contentType == ContentType.image
                        ? 'Image'
                        : reply.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: widget.theme.subtitleStyle.copyWith(fontSize: 13),
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
          color: widget.theme.surfaceColor,
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
}

class _ChatBubble extends StatelessWidget {
  final LivechatMessage message;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final VoidCallback onSwipe;
  final VoidCallback onLongPress;
  final LivechatTheme theme;

  const _ChatBubble({
    required this.message,
    required this.theme,
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
        bottom: isLastInGroup ? 16 : 4, // More spacing between groups
        top: 0,
        left: isMe ? 0 : 0,
        right: isMe ? 0 : 0,
      ),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Agent Avatar (only if not me)
          if (!isMe) ...[
            isLastInGroup
                ? _buildAvatar()
                : const SizedBox(width: 36), // Alignment spacer
            const SizedBox(width: 8),
          ],

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
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.70,
                    ),
                    child: Container(
                      padding: isImage
                          ? const EdgeInsets.all(4)
                          : const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                      decoration: BoxDecoration(
                        color: isMe
                            ? theme.userBubbleColor
                            : theme.agentBubbleColor,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(theme.borderRadius),
                          topRight: Radius.circular(theme.borderRadius),
                          bottomLeft: Radius.circular(
                            isMe ? theme.borderRadius : 4,
                          ),
                          bottomRight: Radius.circular(
                            isMe ? 4 : theme.borderRadius,
                          ),
                        ),
                        boxShadow: [
                          if (!isMe)
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: IntrinsicWidth(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (message.replyTo != null)
                              _buildQuote(context, isMe),

                            if (isImage)
                              _buildImage(context)
                            else if (message.contentType == ContentType.pdf)
                              _buildPdf(context)
                            else
                              Text(
                                message.content,
                                style: theme.bodyStyle.copyWith(
                                  color: isMe
                                      ? theme.userTextColor
                                      : theme.agentTextColor,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    timeStr,
                                    style: theme.timestampStyle.copyWith(
                                      color: isMe
                                          ? theme.userTextColor.withOpacity(0.7)
                                          : theme.subtitleStyle.color,
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 4),
                                    _buildStatusTicks(),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (message.reactions.isNotEmpty) _buildReactionsDisplay(),
                ],
              ),
            ),
          ),

          if (isMe) const SizedBox(width: 16), // Right margin for user bubbles
        ],
      ),
    );
  }

  Widget _buildReactionsDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
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
            color: isMe ? Colors.white70 : theme.primaryColor,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderName.toUpperCase(),
            style: theme.titleStyle.copyWith(
              fontSize: 10,
              color: isMe ? Colors.white : theme.primaryColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            quote.contentType == ContentType.image
                ? 'Sent a image: ${quote.content}'
                : quote.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.subtitleStyle.copyWith(
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
    final isBot = message.senderType == SenderType.bot;

    if (avatarUrl == null) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: Colors.grey[200],
        child: Icon(
          isBot
              ? Icons.smart_toy_outlined
              : isAgent
              ? Icons.support_agent
              : Icons.person,
          size: 14,
          color: Colors.grey[400],
        ),
      );
    }

    return ClipOval(
      child: Image.network(
        avatarUrl,
        width: 32,
        height: 32,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 32,
            height: 32,
            color: Colors.grey[200],
            child: Icon(
              isBot
                  ? Icons.smart_toy_outlined
                  : isAgent
                  ? Icons.support_agent
                  : Icons.person,
              size: 14,
              color: Colors.grey[400],
            ),
          );
        },
      ),
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
          color: theme.backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.content,
          style: theme.subtitleStyle.copyWith(fontSize: 11),
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
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 200,
            height: 200,
            color: Colors.grey[100],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image_rounded,
                  color: Colors.grey[400],
                  size: 48,
                ),
                const SizedBox(height: 8),
                Text(
                  'Image unavailable',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
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
            color: isMe ? theme.userTextColor : theme.primaryColor,
            size: 28,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message.fileName ?? 'Document.pdf',
              style: theme.bodyStyle.copyWith(
                color: isMe ? theme.userTextColor : theme.agentTextColor,
                fontSize: 13,
                decoration: TextDecoration.underline,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTicks() {
    if (message.isRead) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(Icons.done_all, size: 14, color: theme.readTickColor)],
      );
    } else if (message.isDelivered) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done_all, size: 14, color: theme.deliveredTickColor),
        ],
      );
    } else {
      return Icon(Icons.done, size: 14, color: theme.sentTickColor);
    }
  }
}
