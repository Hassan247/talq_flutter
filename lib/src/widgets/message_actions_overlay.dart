import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/talq_theme.dart';

const List<String> kTalqQuickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

const List<String> kTalqMoreReactions = [
  '👍',
  '👎',
  '❤️',
  '🔥',
  '🎉',
  '👏',
  '😂',
  '🤣',
  '😊',
  '😍',
  '🥰',
  '😎',
  '🤔',
  '😮',
  '😯',
  '😢',
  '😭',
  '😡',
  '🙏',
  '💯',
  '✅',
  '❌',
  '⭐',
  '💪',
  '👀',
  '🙌',
  '🤝',
  '👌',
  '✨',
  '🚀',
  '💡',
  '⚡',
  '☕',
  '🎯',
  '📌',
  '🏆',
];

const TextStyle _kBase = TextStyle(
  fontFamily: 'Inter',
  package: 'talq_flutter',
);

/// Long-press menu for a message, mirroring the agent app: the thread blurs
/// away, the pressed bubble stays put with a reaction bar above it and a
/// Reply / Copy menu beneath.
Future<void> showTalqMessageActions({
  required BuildContext context,
  required TalqTheme theme,
  required Widget preview,
  required bool isRightAligned,
  required bool canReact,
  required bool canReply,
  required bool canCopy,
  required Set<String> myReactions,
  required ValueChanged<String> onToggleReaction,
  required VoidCallback onReply,
  required String copyText,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (context, animation, _, __) {
      return _MessageActionsOverlay(
        animation: animation,
        theme: theme,
        preview: preview,
        isRightAligned: isRightAligned,
        canReact: canReact,
        canReply: canReply,
        canCopy: canCopy,
        myReactions: myReactions,
        onToggleReaction: onToggleReaction,
        onReply: onReply,
        copyText: copyText,
      );
    },
  );
}

class _MessageActionsOverlay extends StatelessWidget {
  final Animation<double> animation;
  final TalqTheme theme;
  final Widget preview;
  final bool isRightAligned;
  final bool canReact;
  final bool canReply;
  final bool canCopy;
  final Set<String> myReactions;
  final ValueChanged<String> onToggleReaction;
  final VoidCallback onReply;
  final String copyText;

  const _MessageActionsOverlay({
    required this.animation,
    required this.theme,
    required this.preview,
    required this.isRightAligned,
    required this.canReact,
    required this.canReply,
    required this.canCopy,
    required this.myReactions,
    required this.onToggleReaction,
    required this.onReply,
    required this.copyText,
  });

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    final align = isRightAligned
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: AnimatedBuilder(
                animation: fade,
                builder: (context, child) {
                  return BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 14 * fade.value,
                      sigmaY: 14 * fade.value,
                    ),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.32 * fade.value),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                child: Align(
                  alignment: isRightAligned
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: FadeTransition(
                    opacity: fade,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.94,
                        end: 1.0,
                      ).animate(curved),
                      alignment: isRightAligned
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: align,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (canReact) ...[
                              _ReactionBar(
                                theme: theme,
                                myReactions: myReactions,
                                onPick: (emoji) {
                                  Navigator.of(context).pop();
                                  onToggleReaction(emoji);
                                },
                                onMore: () => _openMoreReactions(context),
                              ),
                              const SizedBox(height: 10),
                            ],
                            IgnorePointer(child: preview),
                            if (canReply || canCopy) ...[
                              const SizedBox(height: 10),
                              _ActionMenu(
                                theme: theme,
                                canReply: canReply,
                                canCopy: canCopy,
                                onReply: () {
                                  Navigator.of(context).pop();
                                  onReply();
                                },
                                onCopy: () {
                                  Navigator.of(context).pop();
                                  HapticFeedback.lightImpact();
                                  Clipboard.setData(
                                    ClipboardData(text: copyText),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMoreReactions(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _MoreReactionsSheet(theme: theme, myReactions: myReactions),
    );
    if (!context.mounted) return;
    if (picked != null) {
      Navigator.of(context).pop();
      onToggleReaction(picked);
    }
  }
}

BoxDecoration _floatingSurface(TalqTheme theme, double radius) {
  return BoxDecoration(
    color: theme.surfaceColor,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: theme.agentTextColor.withValues(alpha: 0.08)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.16),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

class _ReactionBar extends StatelessWidget {
  final TalqTheme theme;
  final Set<String> myReactions;
  final ValueChanged<String> onPick;
  final VoidCallback onMore;

  const _ReactionBar({
    required this.theme,
    required this.myReactions,
    required this.onPick,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: _floatingSurface(theme, 28),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final emoji in kTalqQuickReactions)
            GestureDetector(
              onTap: () => onPick(emoji),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: myReactions.contains(emoji)
                      ? theme.primaryColor.withValues(alpha: 0.16)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(emoji, style: _kBase.copyWith(fontSize: 26)),
              ),
            ),
          GestureDetector(
            onTap: onMore,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionMenu extends StatelessWidget {
  final TalqTheme theme;
  final bool canReply;
  final bool canCopy;
  final VoidCallback onReply;
  final VoidCallback onCopy;

  const _ActionMenu({
    required this.theme,
    required this.canReply,
    required this.canCopy,
    required this.onReply,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      if (canReply)
        _ActionMenuItem(
          theme: theme,
          icon: Icons.reply_rounded,
          label: 'Reply',
          onTap: onReply,
        ),
      if (canCopy)
        _ActionMenuItem(
          theme: theme,
          icon: Icons.copy_rounded,
          label: 'Copy text',
          onTap: onCopy,
        ),
    ];

    return Container(
      width: 232,
      decoration: _floatingSurface(theme, 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  Container(
                    height: 1,
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                items[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionMenuItem extends StatelessWidget {
  final TalqTheme theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionMenuItem({
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = theme.agentTextColor;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: _kBase.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            Icon(icon, size: 20, color: color),
          ],
        ),
      ),
    );
  }
}

class _MoreReactionsSheet extends StatelessWidget {
  final TalqTheme theme;
  final Set<String> myReactions;
  const _MoreReactionsSheet({required this.theme, required this.myReactions});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'React',
                  style: _kBase.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: theme.agentTextColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 6,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final emoji in kTalqMoreReactions)
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(emoji),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: myReactions.contains(emoji)
                              ? theme.primaryColor.withValues(alpha: 0.16)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          emoji,
                          style: _kBase.copyWith(fontSize: 26),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
