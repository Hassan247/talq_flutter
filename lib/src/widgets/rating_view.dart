import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/talq_controller.dart';
import '../theme/talq_theme.dart';

/// Bottom-sheet style rating prompt.
///
/// - Slides up from the bottom so the conversation stays partly visible
///   above it (visitors can still read the chat history).
/// - Tap-outside or the close button dismisses without submitting.
///   The visitor can re-open it from the resolved banner via
///   [TalqController.requestRatingPrompt].
/// - Stars expand the form (feedback + submit) only after a rating is picked.
class RatingView extends StatefulWidget {
  final TalqTheme theme;

  const RatingView({super.key, this.theme = const TalqTheme()});

  @override
  State<RatingView> createState() => _RatingViewState();
}

class _RatingViewState extends State<RatingView>
    with SingleTickerProviderStateMixin {
  int _rating = 0;
  int _hover = 0;
  bool _submitting = false;
  final TextEditingController _commentController = TextEditingController();

  late final AnimationController _slide;
  late final Animation<double> _slideAnim;
  late final Animation<double> _scrimAnim;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _slideAnim = CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic);
    _scrimAnim = CurvedAnimation(parent: _slide, curve: Curves.easeOut);

    final controller = Provider.of<TalqController>(context, listen: false);
    if (controller.rating != null) {
      _rating = controller.rating!;
      _commentController.text = controller.ratingComment ?? '';
    }
    _slide.forward();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _slide.dispose();
    super.dispose();
  }

  void _onStarTap(int index) {
    HapticFeedback.selectionClick();
    setState(() => _rating = index + 1);
  }

  Future<void> _submit(TalqController controller) async {
    if (_rating == 0 || _submitting) return;
    setState(() => _submitting = true);
    try {
      await controller.rateRoom(
        _rating,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _close(TalqController controller) async {
    await _slide.reverse();
    if (!mounted) return;
    controller.dismissRatingPrompt();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final mq = MediaQuery.of(context);
    final scaffoldBgIsDark =
        ThemeData.estimateBrightnessForColor(theme.backgroundColor) ==
        Brightness.dark;

    return Consumer<TalqController>(
      builder: (context, controller, _) {
        return AnimatedBuilder(
          animation: _slide,
          builder: (context, _) {
            return Stack(
              children: [
                // Scrim — tap to dismiss.
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _close(controller),
                    child: ColoredBox(
                      color: Colors.black.withValues(
                        alpha: 0.45 * _scrimAnim.value,
                      ),
                    ),
                  ),
                ),
                // Sheet
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionalTranslation(
                    translation: Offset(0, 1 - _slideAnim.value),
                    child: _Sheet(
                      theme: theme,
                      bottomInset: mq.viewInsets.bottom,
                      isDark: scaffoldBgIsDark,
                      rating: _rating,
                      hover: _hover,
                      submitting: _submitting,
                      commentController: _commentController,
                      onStar: _onStarTap,
                      onHover: (i) => setState(() => _hover = i),
                      onClose: () => _close(controller),
                      onSubmit: () => _submit(controller),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Sheet extends StatelessWidget {
  final TalqTheme theme;
  final double bottomInset;
  final bool isDark;
  final int rating;
  final int hover;
  final bool submitting;
  final TextEditingController commentController;
  final ValueChanged<int> onStar;
  final ValueChanged<int> onHover;
  final VoidCallback onClose;
  final VoidCallback onSubmit;

  const _Sheet({
    required this.theme,
    required this.bottomInset,
    required this.isDark,
    required this.rating,
    required this.hover,
    required this.submitting,
    required this.commentController,
    required this.onStar,
    required this.onHover,
    required this.onClose,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    // Inset from screen edges so the sheet floats as a card above the device
    // chrome (visible scrim on all four sides) instead of bleeding to the
    // bottom/left/right.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Material(
        color: theme.surfaceColor,
        elevation: 24,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(22, 22, 22, 22 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header row: title left (bold), circular close button right.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Rate your conversation',
                        style: theme.titleStyle.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    _CloseButton(theme: theme, onTap: onClose),
                  ],
                ),
                const SizedBox(height: 18),
                // Once the user has rated, hide the stars and the prompt and
                // collapse straight into the comment + submit area. While
                // unrated, show the centered intrinsic-width star row plus a
                // helper label below it.
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: rating == 0
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Center(
                              child: _StarRow(
                                rating: rating,
                                hover: hover,
                                onTap: onStar,
                                onHover: onHover,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Tap a star to rate',
                              textAlign: TextAlign.center,
                              style: theme.subtitleStyle.copyWith(
                                fontSize: 13,
                                height: 1.3,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Text(
                                _subtitleFor(rating),
                                textAlign: TextAlign.center,
                                style: theme.subtitleStyle.copyWith(
                                  fontSize: 13,
                                  height: 1.3,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _CommentField(
                              theme: theme,
                              controller: commentController,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 14),
                            _SubmitButton(
                              theme: theme,
                              submitting: submitting,
                              onPressed: onSubmit,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitleFor(int r) {
    switch (r) {
      case 1:
        return 'Sorry to hear that. Tell us what went wrong.';
      case 2:
        return 'Thanks — we appreciate the feedback.';
      case 3:
        return 'Thanks! Anything we could do better?';
      case 4:
        return 'Great! Glad it went well.';
      case 5:
        return 'Awesome! 🎉 Thanks for the love.';
      default:
        return 'How was your support experience today?';
    }
  }
}

class _CloseButton extends StatelessWidget {
  final TalqTheme theme;
  final VoidCallback onTap;

  const _CloseButton({required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final iconColor = (theme.titleStyle.color ?? Colors.black).withValues(
      alpha: 0.65,
    );
    final bg = (theme.titleStyle.color ?? Colors.black).withValues(alpha: 0.06);
    return Material(
      color: bg,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(Icons.close_rounded, size: 18, color: iconColor),
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final int rating;
  final int hover;
  final ValueChanged<int> onTap;
  final ValueChanged<int> onHover;

  const _StarRow({
    required this.rating,
    required this.hover,
    required this.onTap,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final active = i < (hover > 0 ? hover : rating);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => onHover(i + 1),
          onTapCancel: () => onHover(0),
          onTap: () {
            onHover(0);
            onTap(i);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutBack,
              tween: Tween(begin: 1, end: active ? 1.15 : 1.0),
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: Icon(
                active ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 38,
                color: active ? const Color(0xFFFFB300) : Colors.grey.shade300,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _CommentField extends StatelessWidget {
  final TalqTheme theme;
  final TextEditingController controller;
  final bool isDark;

  const _CommentField({
    required this.theme,
    required this.controller,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fill = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    return TextField(
      controller: controller,
      maxLines: 3,
      minLines: 3,
      style: theme.bodyStyle.copyWith(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Share more details (optional)',
        hintStyle: theme.subtitleStyle.copyWith(fontSize: 13),
        filled: true,
        fillColor: fill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final TalqTheme theme;
  final bool submitting;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.theme,
    required this.submitting,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: submitting ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: theme.primaryColor.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: submitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Submit feedback',
                style: TextStyle(
                  fontFamily: 'Inter',
                  package: 'talq_flutter',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
      ),
    );
  }
}
