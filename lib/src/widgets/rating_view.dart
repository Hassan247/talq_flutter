import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/talq_controller.dart';
import '../theme/talq_theme.dart';

class RatingView extends StatefulWidget {
  final TalqTheme theme;

  const RatingView({super.key, this.theme = const TalqTheme()});

  @override
  State<RatingView> createState() => _RatingViewState();
}

class _RatingViewState extends State<RatingView>
    with SingleTickerProviderStateMixin {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    _animationController.forward();

    final controller = Provider.of<TalqController>(context, listen: false);
    if (controller.rating != null) {
      _rating = controller.rating!;
      _commentController.text = controller.ratingComment ?? '';
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onStarTap(int index) {
    setState(() {
      _rating = index + 1;
    });
  }

  Future<void> _submit(TalqController controller) async {
    if (_rating == 0) return;
    await controller.rateRoom(_rating, comment: _commentController.text);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: widget.theme.surfaceColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: widget.theme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.star_rounded,
                  color: widget.theme.primaryColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'How did we do?',
                style: widget.theme.titleStyle.copyWith(
                  fontSize: 22,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please rate your conversation',
                style: widget.theme.subtitleStyle.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final isSelected = index < _rating;
                  return GestureDetector(
                    onTap: () => _onStarTap(index),
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 300),
                      tween: Tween(begin: 1.0, end: isSelected ? 1.2 : 1.0),
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: Icon(
                            isSelected
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: isSelected ? Colors.amber : Colors.grey[300],
                            size: 44,
                          ),
                        );
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              if (_rating > 0) ...[
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  style: widget.theme.bodyStyle,
                  decoration: InputDecoration(
                    hintText: 'Share your feedback (optional)',
                    hintStyle: widget.theme.subtitleStyle.copyWith(
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: widget.theme.backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 24),
                Consumer<TalqController>(
                  builder: (context, controller, child) {
                    return SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () => _submit(controller),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.theme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Submit Feedback',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
