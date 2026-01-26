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
                                return _ChatBubble(
                                  message: message,
                                  primaryColor: widget.primaryColor,
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
  final Color primaryColor;

  const _ChatBubble({required this.message, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    if (message.senderType == SenderType.system) {
      return _buildSystemMessage();
    }
    final isMe = message.senderType == SenderType.visitor;
    final isImage = message.contentType == ContentType.image;
    final timeStr = DateFormat('jm').format(message.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) _buildAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe && message.senderName != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      message.senderName!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Container(
                  padding: isImage
                      ? const EdgeInsets.all(4)
                      : const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
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
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 20),
                    ),
                  ),
                  child: isImage
                      ? _buildImage(context)
                      : message.contentType == ContentType.pdf
                      ? _buildPdf(context)
                      : Text(
                          message.content,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Text(
                    timeStr,
                    style: TextStyle(color: Colors.grey[400], fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isMe) _buildAvatar(),
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
