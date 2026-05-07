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
      // Already rated — jump straight to the thank-you state.
      _rating = controller.rating!;
      _submitted = true;
    }
    _slide.forward();
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  Future<void> _onStarTap(TalqController controller, int index) async {
    if (_submitting || _submitted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _rating = index + 1;
      _submitting = true;
    });
    try {
      await controller.rateRoom(_rating);
    } finally {
      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          _submitting = false;
          _submitted = true;
        });
      }
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
                      onStar: (i) => _onStarTap(controller, i),
                      onHover: (i) => setState(() => _hover = i),
                      onClose: () => _close(controller),
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
  final ValueChanged<int> onStar;
  final ValueChanged<int> onHover;
  final VoidCallback onClose;

  const _Sheet({
    required this.theme,
    required this.bottomInset,
    required this.isDark,
    required this.rating,
    required this.hover,
    required this.submitting,
    required this.submitted,
    required this.onStar,
    required this.onHover,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // Inset from screen edges so the sheet floats as a card above the device
    // chrome (visible scrim on all four sides) instead of bleeding to the
    // bottom/left/right.
    final titleColor = theme.titleStyle.color ?? Colors.black;
    final showThanks = submitted;
    final showSubmitting = submitting && !submitted;
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
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.15),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: Text(
                          showThanks
                              ? 'Thanks for rating'
                              : 'Rate your conversation',
                          key: ValueKey<bool>(showThanks),
                          style: theme.titleStyle.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ),
                    _CloseButton(theme: theme, onTap: onClose),
                  ],
                ),
                const SizedBox(height: 18),
                AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.96,
                          end: 1.0,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: showThanks
                        ? _ThanksView(
                            key: const ValueKey('thanks'),
                            theme: theme,
                            rating: rating,
                            onDone: onClose,
                          )
                        : showSubmitting
                            ? _SubmittingView(
                                key: const ValueKey('submitting'),
                                theme: theme,
                                rating: rating,
                              )
                            : _RatePromptView(
                                key: const ValueKey('rate'),
                                theme: theme,
                                titleColor: titleColor,
                                rating: rating,
                                hover: hover,
                                onStar: onStar,
                                onHover: onHover,
                              ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RatePromptView extends StatelessWidget {
  final TalqTheme theme;
  final Color titleColor;
  final int rating;
  final int hover;
  final ValueChanged<int> onStar;
  final ValueChanged<int> onHover;

  const _RatePromptView({
    super.key,
    required this.theme,
    required this.titleColor,
    required this.rating,
    required this.hover,
    required this.onStar,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
}

class _SubmittingView extends StatelessWidget {
  final TalqTheme theme;
  final int rating;

  const _SubmittingView({super.key, required this.theme, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Show the picked stars while we submit (subtle confirmation).
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              5,
              (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  i < rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 30,
                  color: i < rating
                      ? const Color(0xFFFFB300)
                      : Colors.grey.shade300,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
          ),
        ),
      ],
    );
  }
}

class _ThanksView extends StatelessWidget {
  final TalqTheme theme;
  final int rating;
  final VoidCallback onDone;

  const _ThanksView({
    super.key,
    required this.theme,
    required this.rating,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Animated check-circle in primary tint.
        Center(
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            tween: Tween(begin: 0.6, end: 1.0),
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 36,
                color: theme.primaryColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              5,
              (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  i < rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 18,
                  color: i < rating
                      ? const Color(0xFFFFB300)
                      : Colors.grey.shade300,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          rating >= 4
              ? 'Your feedback helps us improve. Thanks for taking the time!'
              : 'Thanks — your feedback helps us do better.',
          textAlign: TextAlign.center,
          style: theme.subtitleStyle.copyWith(fontSize: 13, height: 1.35),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: onDone,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Done',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
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
