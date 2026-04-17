import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/utils/pdf_thumbnail_helper.dart';
import '../models/models.dart' as models;
import '../state/talq_controller.dart';
import '../theme/talq_theme.dart';
import 'media_preview_page.dart';
import 'media_viewer_page.dart';
import 'messages_list_view.dart';
import 'rating_view.dart';
import 'shared_widgets.dart';
import 'shimmer_skeleton.dart';
import 'start_conversation_card.dart';

class TalqView extends StatefulWidget {
  final String title;
  final TalqTheme? theme;
  final bool isNewConversation;

  const TalqView({
    super.key,
    this.title = 'Live Chat',
    this.theme,
    this.isNewConversation = false,
  });

  @override
  State<TalqView> createState() => _TalqViewState();
}

class _TalqViewState extends State<TalqView> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  Timer? _typingThrottle;
  TalqController? _controller;

  // Sticky date overlay state
  String _overlayDateLabel = '';
  bool _showDateOverlay = false;
  Timer? _dateOverlayTimer;
  final Map<int, GlobalKey> _groupKeys = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // notify controller that chat is now visible
      if (mounted) {
        context.read<TalqController>().setChatVisible(true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Save reference to controller for use in dispose()
    _controller = context.read<TalqController>();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      // Load more when we are 200px from the "top" (which is maxScroll in reverse)
      if (maxScroll - currentScroll <= 200) {
        final controller = _controller ?? context.read<TalqController>();
        if (!controller.isFetchingMore && controller.hasMoreMessages) {
          controller.fetchMessages(isLoadMore: true);
        }
      }
      // Update sticky date overlay
      _updateVisibleDate();
    }
  }

  void _updateVisibleDate() {
    // Find the topmost visible date group by checking render positions
    final listRenderBox =
        _scrollController.position.context.storageContext.findRenderObject()
            as RenderBox?;
    if (listRenderBox == null) return;

    String? topDate;
    for (final entry in _groupKeys.entries) {
      final keyContext = entry.value.currentContext;
      if (keyContext == null) continue;
      final renderBox = keyContext.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.attached) continue;

      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      // If the bottom of this group is above the top of the viewport, skip it.
      // If the top of this group is below the viewport, skip it.
      // We want the group whose content spans the top area of the chat.
      // In a reversed list, higher index = older = visually higher.
      // The group is visible at top if its top edge is at or above the chat top area
      // and its bottom edge is below the chat top area.
      if (position.dy < 200 && position.dy + size.height > 0) {
        topDate = _getDateLabel(
          _lastGroupedMessages != null &&
                  entry.key < _lastGroupedMessages!.length
              ? _lastGroupedMessages![entry.key].date
              : DateTime.now(),
        );
      }
    }

    if (topDate != null && topDate != _overlayDateLabel) {
      setState(() {
        _overlayDateLabel = topDate!;
      });
    }

    if (!_showDateOverlay) {
      setState(() => _showDateOverlay = true);
    }

    _dateOverlayTimer?.cancel();
    _dateOverlayTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showDateOverlay = false);
    });
  }

  List<_MessageGroup>? _lastGroupedMessages;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Use cached controller reference safely
    _controller?.setChatVisible(false);
    _messageController.dispose();
    _scrollController.dispose();
    _typingThrottle?.cancel();
    _dateOverlayTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    context.read<TalqController>().setLifecycleState(state);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0, // 0 is bottom in reverse mode
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatResponseTime(String? time) {
    if (time == null) return 'Usually replies in minutes';
    final t = time.trim();
    if (t.toLowerCase().startsWith('replies') ||
        t.toLowerCase().startsWith('usually')) {
      return t;
    }
    // Format raw "8483 min" / "45 sec" into human-readable
    final formatted = StartConversationCard.formatReplyTime(t);
    if (formatted != t) {
      return 'Usually replies in ${formatted.toLowerCase()}';
    }
    return 'Reply in $t';
  }

  List<_MessageGroup> _groupMessages(List<models.TalqMessage> messages) {
    final groups = <_MessageGroup>[];
    if (messages.isEmpty) return groups;

    DateTime? currentDate;
    List<models.TalqMessage> currentGroupMessages = [];

    for (final message in messages) {
      final localCreatedAt = message.createdAt.toLocal();
      final messageDate = DateTime(
        localCreatedAt.year,
        localCreatedAt.month,
        localCreatedAt.day,
      );

      if (currentDate == null) {
        currentDate = messageDate;
        currentGroupMessages.add(message);
      } else if (messageDate != currentDate) {
        groups.add(
          _MessageGroup(date: currentDate, messages: currentGroupMessages),
        );
        currentDate = messageDate;
        currentGroupMessages = [message];
      } else {
        currentGroupMessages.add(message);
      }
    }

    if (currentDate != null) {
      groups.add(
        _MessageGroup(date: currentDate, messages: currentGroupMessages),
      );
    }

    return groups;
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) return 'TODAY';
    if (dateToCheck == yesterday) return 'YESTERDAY';
    return DateFormat('MMMM d').format(date).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: 'Inter', package: 'talq_flutter'),
      child: Consumer<TalqController>(
        builder: (context, controller, child) {
          if (!controller.isInitialized && controller.isLoading) {
            return Scaffold(
              backgroundColor: controller.theme.backgroundColor,
              body: ChatMessagesSkeleton(
                baseColor: controller.theme.primaryColor.withValues(
                  alpha: 0.06,
                ),
                highlightColor: controller.theme.primaryColor.withValues(
                  alpha: 0.12,
                ),
              ),
            );
          }

          // use controller's theme for reactive updates
          final theme = controller.theme;

          final hasMessages = controller.messages.isNotEmpty;
          final shouldRedirect = widget.isNewConversation && hasMessages;

          return PopScope(
            canPop: !shouldRedirect,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) {
                context.read<TalqController>().setChatVisible(false);
                return;
              }

              if (shouldRedirect) {
                context.read<TalqController>().setChatVisible(false);
                Navigator.pushReplacement(
                  context,
                  TalqPageRoute(builder: (_) => const MessagesListView()),
                );
              }
            },
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Scaffold(
                backgroundColor: theme.backgroundColor,
                appBar: AppBar(
                  systemOverlayStyle: SystemUiOverlayStyle.dark,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  surfaceTintColor: Colors.transparent,
                  backgroundColor: theme.backgroundColor,
                  leading: BackButton(color: theme.titleStyle.color),
                  centerTitle: false,
                  titleSpacing: 0,
                  title: Row(
                    children: [
                      _buildHeaderAvatar(controller, theme),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              controller.currentRoom?.assigneeName ??
                                  controller.workspace?.name ??
                                  widget.title,
                              style: theme.titleStyle.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (controller.workspace?.showResponseTime == true)
                              Text(
                                _formatResponseTime(
                                  controller.workspace?.responseTime,
                                ),
                                style: theme.subtitleStyle.copyWith(
                                  fontSize: 12,
                                  color: theme.subtitleStyle.color?.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: theme.titleStyle.color?.withValues(alpha: 0.8),
                        size: 26,
                      ),
                      onPressed: () {
                        context.read<TalqController>().setChatVisible(false);
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                body: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child:
                              controller.isRoomLoading &&
                                  controller.roomId != null
                              ? ListView(
                                  children: [
                                    SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height *
                                          0.6,
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                  ],
                                )
                              : controller.messages.isEmpty
                              ? ListView(
                                  children: [
                                    SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height *
                                          0.6,
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(32.0),
                                          child: controller.roomId != null
                                              ? Text(
                                                  'No messages yet',
                                                  style: theme.subtitleStyle
                                                      .copyWith(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                )
                                              : Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            24,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: theme
                                                            .primaryColor
                                                            .withValues(
                                                              alpha: 0.04,
                                                            ),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: SvgPicture.asset(
                                                        'assets/icons/messages.svg',
                                                        package: 'talq_flutter',
                                                        colorFilter:
                                                            ColorFilter.mode(
                                                              theme.primaryColor
                                                                  .withValues(
                                                                    alpha: 0.15,
                                                                  ),
                                                              BlendMode.srcIn,
                                                            ),
                                                        width: 56,
                                                        height: 56,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 32),
                                                    Text(
                                                      controller
                                                              .workspace
                                                              ?.welcomeMessage ??
                                                          'Hello there!\nHow can we help today?',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: theme.titleStyle
                                                          .copyWith(
                                                            fontSize: 22,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color: theme
                                                                .titleStyle
                                                                .color
                                                                ?.withValues(
                                                                  alpha: 0.8,
                                                                ),
                                                            letterSpacing: -0.5,
                                                            height: 1.2,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Text(
                                                      'Type a message below to begin.',
                                                      style: theme.subtitleStyle
                                                          .copyWith(
                                                            fontSize: 15,
                                                            color: theme
                                                                .subtitleStyle
                                                                .color
                                                                ?.withValues(
                                                                  alpha: 0.5,
                                                                ),
                                                            letterSpacing: -0.2,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Builder(
                                  builder: (context) {
                                    final groupedMessages = _groupMessages(
                                      controller.messages,
                                    );
                                    _lastGroupedMessages = groupedMessages;
                                    // Clean up stale keys
                                    _groupKeys.removeWhere(
                                      (k, _) => k >= groupedMessages.length,
                                    );
                                    return ListView.builder(
                                      controller: _scrollController,
                                      padding: const EdgeInsets.only(
                                        left: 16,
                                        right: 0,
                                        top: 16,
                                        bottom: 16,
                                      ),
                                      reverse: true,
                                      itemCount:
                                          groupedMessages.length +
                                          (controller.isFetchingMore &&
                                                  controller.hasMoreMessages
                                              ? 1
                                              : 0),
                                      itemBuilder: (context, index) {
                                        if (index == groupedMessages.length) {
                                          return const Padding(
                                            padding: EdgeInsets.all(16.0),
                                            child: Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          );
                                        }

                                        final group = groupedMessages[index];
                                        final date = group.date;
                                        final messages = group.messages;
                                        final groupKey = _groupKeys.putIfAbsent(
                                          index,
                                          () => GlobalKey(),
                                        );

                                        return Column(
                                          key: groupKey,
                                          children: [
                                            Container(
                                              width: double.infinity,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 24,
                                                  ),
                                              alignment: Alignment.center,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Color.alphaBlend(
                                                    theme.primaryColor
                                                        .withValues(alpha: 0.1),
                                                    theme.backgroundColor,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  _getDateLabel(date),
                                                  style: TextStyle(
                                                    fontFamily: 'Inter',
                                                    package: 'talq_flutter',
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: theme.primaryColor,
                                                    letterSpacing: 1.0,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            ListView.builder(
                                              shrinkWrap: true,
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              itemCount: messages.length,
                                              reverse: true,
                                              itemBuilder: (context, msgIndex) {
                                                final message =
                                                    messages[msgIndex];

                                                final isLastInGroup =
                                                    msgIndex == 0 ||
                                                    messages[msgIndex - 1]
                                                            .senderType !=
                                                        message.senderType;

                                                final isFirstInGroup =
                                                    msgIndex ==
                                                        messages.length - 1 ||
                                                    messages[msgIndex + 1]
                                                            .senderType !=
                                                        message.senderType;

                                                return _ChatBubble(
                                                  message: message,
                                                  theme: theme,
                                                  isFirstInGroup:
                                                      isFirstInGroup,
                                                  isLastInGroup: isLastInGroup,
                                                  onSwipe: () => controller
                                                      .setReplyingTo(message),
                                                  onLongPress: () =>
                                                      _showReactions(
                                                        context,
                                                        controller,
                                                        message,
                                                        theme,
                                                      ),
                                                );
                                              },
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
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
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.surfaceColor,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(18),
                                      topRight: Radius.circular(18),
                                      bottomRight: Radius.circular(18),
                                      bottomLeft: Radius.circular(4),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.cardShadowColor.withValues(
                                          alpha: 0.06,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: TypingIndicatorDots(
                                    color:
                                        theme.subtitleStyle.color ??
                                        Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (controller.replyingTo != null)
                          _buildReplyOverlay(controller, theme),
                        _buildInputArea(controller, theme),
                      ],
                    ),
                    // WhatsApp-style sticky date overlay
                    if (_showDateOverlay && _overlayDateLabel.isNotEmpty)
                      Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: Center(
                            child: AnimatedOpacity(
                              opacity: _showDateOverlay ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Color.alphaBlend(
                                    theme.primaryColor.withValues(alpha: 0.1),
                                    theme.backgroundColor,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _overlayDateLabel,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    package: 'talq_flutter',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: theme.primaryColor,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (controller.showRatingPrompt)
                      Container(
                        color: Colors.black.withValues(alpha: 0.5),
                        child: RatingView(theme: theme),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderAvatar(TalqController controller, TalqTheme theme) {
    final imageUrl =
        controller.currentRoom?.assigneeAvatarUrl ??
        controller.workspace?.avatarUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return TalqAvatar(
        imageUrl: imageUrl,
        senderType: models.SenderType.agent,
        radius: 18,
      );
    }
    // Fallback: workspace initial in a colored circle
    final name = controller.workspace?.name ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 18,
      backgroundColor: theme.primaryColor,
      child: Text(
        initial,
        style: const TextStyle(
          fontFamily: 'Inter',
          package: 'talq_flutter',
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildInputArea(TalqController controller, TalqTheme theme) {
    if (controller.roomStatus == models.RoomStatus.resolved) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: theme.resolvedBackgroundColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.resolvedTextColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, color: theme.resolvedTextColor, size: 24),
            const SizedBox(height: 10),
            Text(
              'This conversation is resolved',
              style: TextStyle(
                fontFamily: 'Inter',
                package: 'talq_flutter',
                color: theme.resolvedTextColor,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You cannot send new messages',
              style: TextStyle(
                fontFamily: 'Inter',
                package: 'talq_flutter',
                color: theme.resolvedTextColor.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      decoration: BoxDecoration(color: theme.backgroundColor),
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        minimum: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () =>
                          _showAttachmentOptions(context, controller, theme),
                      icon: SvgPicture.asset(
                        'assets/icons/plus.svg',
                        package: 'talq_flutter',
                        colorFilter: ColorFilter.mode(
                          theme.primaryColor,
                          BlendMode.srcIn,
                        ),
                        width: 24,
                        height: 24,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: theme.primaryColor.withValues(
                          alpha: 0.05,
                        ),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type something',
                          hintStyle: theme.subtitleStyle.copyWith(
                            fontSize: 15,
                            color: theme.inputHintColor,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          isDense: true,
                        ),
                        minLines: 1,
                        maxLines: 5,
                        style: theme.bodyStyle.copyWith(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        onChanged: (text) => _onTextChanged(text, controller),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: theme.primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () => _handleSend(controller),
                icon: SvgPicture.asset(
                  'assets/icons/send-message.svg',
                  package: 'talq_flutter',
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                  width: 22,
                  height: 22,
                ),
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAttachmentOptions(
    BuildContext context,
    TalqController controller,
    TalqTheme theme,
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
                theme: theme,
                iconPath: 'assets/icons/image.svg',
                label: 'File',
                onTap: () async {
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (image != null && mounted) {
                    navigator.push(
                      TalqPageRoute(
                        builder: (context) => ChangeNotifierProvider.value(
                          value: controller,
                          child: MediaPreviewPage(
                            file: File(image.path),
                            contentType: models.ContentType.image,
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
              _buildOption(
                theme: theme,
                iconPath: 'assets/icons/camera.svg',
                label: 'Camera',
                onTap: () async {
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (image != null && mounted) {
                    navigator.push(
                      TalqPageRoute(
                        builder: (context) => ChangeNotifierProvider.value(
                          value: controller,
                          child: MediaPreviewPage(
                            file: File(image.path),
                            contentType: models.ContentType.image,
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
              _buildOption(
                theme: theme,
                iconPath: 'assets/icons/document.svg',
                label: 'Document',
                onTap: () async {
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  FilePickerResult? result = await FilePicker.platform
                      .pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf'],
                      );
                  if (result != null && mounted) {
                    navigator.push(
                      TalqPageRoute(
                        builder: (context) => ChangeNotifierProvider.value(
                          value: controller,
                          child: MediaPreviewPage(
                            file: File(result.files.single.path!),
                            contentType: models.ContentType.pdf,
                          ),
                        ),
                      ),
                    );
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
    required TalqTheme theme,
    required String iconPath,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9), // Light grey background
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              iconPath,
              package: 'talq_flutter',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                theme.primaryColor,
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.subtitleStyle.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _handleSend(TalqController controller) {
    if (_messageController.text.trim().isEmpty) return;
    controller.sendMessage(_messageController.text);
    _messageController.clear();
    _typingThrottle?.cancel(); // Clear throttle on send
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _onTextChanged(String text, TalqController controller) {
    if (text.isEmpty) return;
    if (controller.roomId == null) return;

    if (_typingThrottle == null || !_typingThrottle!.isActive) {
      _typingThrottle = Timer(const Duration(seconds: 2), () {});
      controller.sendTyping(controller.roomId!);
    }
  }

  Widget _buildReplyOverlay(TalqController controller, TalqTheme theme) {
    final reply = controller.replyingTo!;
    final senderName =
        reply.senderName ??
        (reply.senderType == models.SenderType.visitor ? 'YOU' : 'AGENT');

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.cardShadowColor.withValues(alpha: 0.08),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 3.5,
              decoration: BoxDecoration(
                color: theme.primaryColor,
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
                    style: theme.titleStyle.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reply.contentType == models.ContentType.image
                        ? 'Image'
                        : reply.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.subtitleStyle.copyWith(
                      fontSize: 14,
                      color: theme.subtitleStyle.color?.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                size: 20,
                color: Colors.grey,
              ),
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
    TalqController controller,
    models.TalqMessage message,
    TalqTheme theme,
  ) {
    final reactions = ['❤️', '👍', '😂', '😮', '😢', '🔥'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
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
                  child: Text(
                    emoji,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      package: 'talq_flutter',
                      fontSize: 28,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final models.TalqMessage message;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final VoidCallback onSwipe;
  final VoidCallback onLongPress;
  final TalqTheme theme;

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
    if (message.senderType == models.SenderType.system) {
      return _buildSystemMessage();
    }
    final isMe = message.senderType == models.SenderType.visitor;
    final hasAttachment =
        message.fileUrl != null || message.localFilePath != null;
    final isImage = _isImageMessage(message, hasAttachment);
    final isDocument = _isDocumentMessage(message, hasAttachment, isImage);
    final attachmentCaption = _attachmentCaption(message);
    final timeStr = DateFormat('jm').format(message.createdAt.toLocal());

    return Padding(
      padding: EdgeInsets.only(
        bottom: isLastInGroup ? 16 : 4, // more spacing between groups
        top: 0,
        left: isMe ? 48 : 0, // offset user bubbles to match agent avatar space
        right: isMe ? 0 : 48, // offset agent bubbles to limit width on right
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
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (isLastInGroup &&
                    message.senderType != models.SenderType.system)
                  Positioned(
                    bottom: 0,
                    right: isMe ? -8 : null,
                    left: !isMe ? -8 : null,
                    child: CustomPaint(
                      size: const Size(12, 12),
                      painter: _WhatsAppTailPainter(
                        color: isMe
                            ? theme.userBubbleColor
                            : theme.agentBubbleColor,
                        isRight: isMe,
                      ),
                    ),
                  ),
                GestureDetector(
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
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: Radius.circular(
                                !isMe && isLastInGroup ? 4 : 20,
                              ),
                              bottomRight: Radius.circular(
                                isMe && isLastInGroup ? 4 : 20,
                              ),
                            ),
                            boxShadow: [
                              if (!isMe)
                                BoxShadow(
                                  color: theme.cardShadowColor.withValues(
                                    alpha: 0.06,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              if (isMe)
                                BoxShadow(
                                  color: theme.userBubbleColor.withValues(
                                    alpha: 0.12,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (message.replyTo != null)
                                _buildQuote(context, isMe),

                              if (isImage)
                                _buildImage(context)
                              else if (isDocument)
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
                              if ((isImage || isDocument) &&
                                  attachmentCaption.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  attachmentCaption,
                                  style: theme.bodyStyle.copyWith(
                                    color: isMe
                                        ? theme.userTextColor
                                        : theme.agentTextColor,
                                  ),
                                ),
                              ],
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
                                            ? theme.userTextColor.withValues(
                                                alpha: 0.7,
                                              )
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
                      if (message.reactions.isNotEmpty)
                        _buildReactionsDisplay(),
                    ],
                  ),
                ),
              ],
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
            color: Colors.black.withValues(alpha: 0.1),
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
                child: Text(
                  emoji,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    package: 'talq_flutter',
                    fontSize: 12,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildQuote(BuildContext context, bool isMe) {
    final quote = message.replyTo!;
    final quoteHasAttachment =
        quote.fileUrl != null || quote.localFilePath != null;
    final quoteIsImage = _isImageMessage(quote, quoteHasAttachment);
    final quoteIsDocument = _isDocumentMessage(
      quote,
      quoteHasAttachment,
      quoteIsImage,
    );
    final senderName =
        quote.senderName ??
        (quote.senderType == models.SenderType.visitor ? 'VISITOR' : 'AGENT');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.black.withValues(alpha: 0.1)
            : theme.backgroundColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: isMe
                ? Colors.white.withValues(alpha: 0.4)
                : theme.primaryColor,
            width: 3.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderName,
            style: theme.titleStyle.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isMe ? Colors.white : theme.primaryColor,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            quoteIsImage
                ? 'Sent an image'
                : quoteIsDocument
                ? 'Sent a document'
                : quote.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.subtitleStyle.copyWith(
              fontSize: 13,
              height: 1.3,
              color: isMe
                  ? Colors.white.withValues(alpha: 0.85)
                  : theme.subtitleStyle.color?.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return TalqAvatar(
      imageUrl: message.senderAvatarUrl,
      senderType: message.senderType,
      radius: 16,
    );
  }

  Widget _buildSystemMessage() {
    final isReassignment = message.content.startsWith('Reassigned to');
    final timeStr = DateFormat(
      'MMM d, h:mm a',
    ).format(message.createdAt.toLocal());

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
                      fontFamily: 'Inter',
                      package: 'talq_flutter',
                      fontSize: 11,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '• $timeStr',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      package: 'talq_flutter',
                      fontSize: 10,
                      color: Colors.grey[500],
                    ),
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
    const double maxHeight = 280;
    const double minHeight = 100;

    Widget imageWidget;
    if (message.localFilePath != null &&
        File(message.localFilePath!).existsSync()) {
      imageWidget = Image.file(
        File(message.localFilePath!),
        width: double.infinity,
        fit: BoxFit.cover,
      );
    } else if (message.fileUrl != null && message.fileUrl!.isNotEmpty) {
      imageWidget = CachedNetworkImage(
        imageUrl: message.fileUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (context, url) => Container(
          width: double.infinity,
          height: 180,
          color: Colors.grey[100],
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (context, url, error) => Container(
          width: double.infinity,
          height: 140,
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
                style: TextStyle(
                  fontFamily: 'Inter',
                  package: 'talq_flutter',
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      imageWidget = Container(
        width: double.infinity,
        height: 140,
        color: Colors.grey[100],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_rounded,
              color: Colors.grey[500],
              size: 44,
            ),
            const SizedBox(height: 6),
            Text(
              'Image unavailable',
              style: TextStyle(
                fontFamily: 'Inter',
                package: 'talq_flutter',
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: GestureDetector(
        onTap: () {
          if (!message.isUploading &&
              (message.fileUrl != null || message.localFilePath != null)) {
            Navigator.push(
              context,
              TalqPageRoute(
                builder: (context) => MediaViewerPage(
                  url: message.fileUrl,
                  localPath: message.localFilePath,
                  contentType: message.contentType,
                  fileName: message.fileName ?? 'Image',
                ),
              ),
            );
          }
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: maxHeight,
            minHeight: minHeight,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              imageWidget,
              if (message.isUploading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black26,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPdf(BuildContext context) {
    final isMe = message.senderType == models.SenderType.visitor;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isMe
            ? theme.userBubbleColor.withValues(alpha: 0.1)
            : theme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          if (!message.isUploading &&
              (message.fileUrl != null || message.localFilePath != null)) {
            Navigator.push(
              context,
              TalqPageRoute(
                builder: (context) => MediaViewerPage(
                  url: message.fileUrl,
                  localPath: message.localFilePath,
                  contentType: message.contentType,
                  fileName: message.fileName ?? 'Document.pdf',
                ),
              ),
            );
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder<PdfMetadata?>(
              future: (message.localFilePath != null || message.fileUrl != null)
                  ? PdfThumbnailHelper.getMetadata(
                      message.localFilePath ?? message.fileUrl!,
                    )
                  : Future.value(null),
              builder: (context, snapshot) {
                final metadata = snapshot.data;
                final thumbnail = metadata?.thumbnail;

                final sizeStr = metadata != null
                    ? (metadata.fileSize < 1024 * 1024
                          ? '${(metadata.fileSize / 1024).toStringAsFixed(1)} KB'
                          : '${(metadata.fileSize / (1024 * 1024)).toStringAsFixed(1)} MB')
                    : '';
                final pagesStr = metadata != null
                    ? '${metadata.pageCount} ${metadata.pageCount == 1 ? 'page' : 'pages'}'
                    : '';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (thumbnail != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: Image.file(
                          thumbnail,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.picture_as_pdf,
                            color: Colors.redAccent,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.fileName ?? 'Document.pdf',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.bodyStyle.copyWith(
                                    color: isMe
                                        ? theme.userTextColor
                                        : theme.agentTextColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (metadata != null)
                                  Text(
                                    '$pagesStr • $sizeStr',
                                    style: theme.bodyStyle.copyWith(
                                      fontSize: 11,
                                      color:
                                          (isMe
                                                  ? theme.userTextColor
                                                  : theme.agentTextColor)
                                              .withValues(alpha: 0.6),
                                    ),
                                  )
                                else if (message.isUploading)
                                  Text(
                                    'Uploading...',
                                    style: theme.bodyStyle.copyWith(
                                      fontSize: 11,
                                      color:
                                          (isMe
                                                  ? theme.userTextColor
                                                  : theme.agentTextColor)
                                              .withValues(alpha: 0.6),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _isImageMessage(models.TalqMessage target, bool hasAttachment) {
    if (target.contentType == models.ContentType.image) {
      return true;
    }
    if (!hasAttachment) {
      return false;
    }

    final source =
        (target.fileName ?? target.fileUrl ?? target.localFilePath)
            ?.toLowerCase() ??
        '';
    final normalizedSource = source.split('?').first.split('#').first;

    return normalizedSource.endsWith('.jpg') ||
        normalizedSource.endsWith('.jpeg') ||
        normalizedSource.endsWith('.png') ||
        normalizedSource.endsWith('.gif') ||
        normalizedSource.endsWith('.webp') ||
        normalizedSource.contains('/images/');
  }

  bool _isDocumentMessage(
    models.TalqMessage target,
    bool hasAttachment,
    bool isImage,
  ) {
    if (target.contentType == models.ContentType.pdf) {
      return true;
    }
    return hasAttachment && !isImage;
  }

  String _attachmentCaption(models.TalqMessage target) {
    final cleaned = _stripAttachmentCaption(target.content).trim();
    if (cleaned.isEmpty) {
      return '';
    }

    final fileName = target.fileName?.trim();
    if (fileName != null && fileName.isNotEmpty && cleaned == fileName) {
      return '';
    }

    return cleaned;
  }

  String _stripAttachmentCaption(String content) {
    if (content.startsWith('Sent an image:')) {
      return content.replaceFirst('Sent an image:', '').trim();
    }
    if (content.startsWith('Sent a file:')) {
      return content.replaceFirst('Sent a file:', '').trim();
    }
    return content;
  }

  Widget _buildStatusTicks() {
    if (message.isUploading) {
      return const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: Colors.white70,
        ),
      );
    }
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

class _MessageGroup {
  final DateTime date;
  final List<models.TalqMessage> messages;

  _MessageGroup({required this.date, required this.messages});
}

class _WhatsAppTailPainter extends CustomPainter {
  final Color color;
  final bool isRight;

  _WhatsAppTailPainter({required this.color, required this.isRight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    if (isRight) {
      path.moveTo(0, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
