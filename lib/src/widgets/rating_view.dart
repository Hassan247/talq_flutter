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
  bool _submitted = false;
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
    // If a rating was already submitted, never show this sheet — the
    // resolved banner is the single source of truth for confirmation.
    if (controller.rating != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        controller.dismissRatingPrompt();
      });
      return;
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
    if (_submitting || _submitted) return;
    HapticFeedback.selectionClick();
    setState(() => _rating = index + 1);
  }

  Future<void> _submit(TalqController controller) async {
    if (_rating == 0 || _submitting || _submitted) return;
    HapticFeedback.lightImpact();
    setState(() => _submitting = true);
    try {
      final comment = _commentController.text.trim();
      await controller.rateRoom(
        _rating,
        comment: comment.isEmpty ? null : comment,
      );
      if (!mounted) return;
      _submitted = true;
      // Dismiss the sheet — confirmation lives on the resolved banner.
      await _close(controller);
    } catch (_) {
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
                      submitted: _submitted,
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
  final bool submitted;
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
    required this.submitted,
    required this.commentController,
    required this.onStar,
    required this.onHover,
    required this.onClose,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.surfaceColor,
      elevation: 24,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(22, 14, 22, 22 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: (theme.titleStyle.color ?? Colors.black).withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Rate your experience',
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
              _RateForm(
                theme: theme,
                isDark: isDark,
                rating: rating,
                hover: hover,
                submitting: submitting,
                commentController: commentController,
                onStar: onStar,
                onHover: onHover,
                onSubmit: onSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RateForm extends StatelessWidget {
  final TalqTheme theme;
  final bool isDark;
  final int rating;
  final int hover;
  final bool submitting;
  final TextEditingController commentController;
  final ValueChanged<int> onStar;
  final ValueChanged<int> onHover;
  final VoidCallback onSubmit;

  const _RateForm({
    required this.theme,
    required this.isDark,
    required this.rating,
    required this.hover,
    required this.submitting,
    required this.commentController,
    required this.onStar,
    required this.onHover,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final hasRating = rating > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Label ABOVE stars (App Store style).
        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              hasRating ? _subtitleFor(rating) : 'Tap to Rate',
              key: ValueKey<int>(rating),
              textAlign: TextAlign.center,
              style: theme.subtitleStyle.copyWith(
                fontSize: 14,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: _StarRow(
            rating: rating,
            hover: hover,
            onTap: onStar,
            onHover: onHover,
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: hasRating
              ? Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  String _subtitleFor(int r) {
    switch (r) {
      case 1:
        return 'Sorry to hear that';
      case 2:
        return 'Thanks for the feedback';
      case 3:
        return 'Anything we could do better?';
      case 4:
        return 'Glad it went well';
      case 5:
        return 'Awesome — thanks for the love!';
      default:
        return 'Tap to Rate';
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
        hintText: 'Tell us more (optional)',
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
