import 'package:flutter/material.dart';

/// A shimmer animation widget that creates a loading skeleton effect.
class TalqShimmer extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  const TalqShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<TalqShimmer> createState() => _TalqShimmerState();
}

class _TalqShimmerState extends State<TalqShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.baseColor ?? Colors.grey.shade200;
    final highlight = widget.highlightColor ?? Colors.grey.shade50;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.0 + 2.0 * _controller.value, -0.3),
              end: Alignment(1.0 + 2.0 * _controller.value, 0.3),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A single rounded shimmer box.
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Skeleton for the home screen (rooms_list_view) while workspace data loads.
class HomeScreenSkeleton extends StatelessWidget {
  final Color? baseColor;
  final Color? highlightColor;

  const HomeScreenSkeleton({super.key, this.baseColor, this.highlightColor});

  @override
  Widget build(BuildContext context) {
    return TalqShimmer(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo placeholder
            const ShimmerBox(width: 40, height: 40, borderRadius: 10),
            const SizedBox(height: 34),
            // Welcome text lines
            const ShimmerBox(width: 280, height: 30, borderRadius: 6),
            const SizedBox(height: 10),
            const ShimmerBox(width: 220, height: 30, borderRadius: 6),
            const SizedBox(height: 14),
            // Subtitle
            const ShimmerBox(width: 260, height: 14, borderRadius: 4),
            const SizedBox(height: 6),
            const ShimmerBox(width: 140, height: 14, borderRadius: 4),
          ],
        ),
      ),
    );
  }
}

/// Skeleton card that mimics the start conversation card shape.
class ConversationCardSkeleton extends StatelessWidget {
  final Color? baseColor;
  final Color? highlightColor;

  const ConversationCardSkeleton({
    super.key,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return TalqShimmer(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(27),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const ShimmerBox(width: 180, height: 20, borderRadius: 6),
            const SizedBox(height: 16),
            // Avatar row
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  // 3 overlapping avatars
                  const ShimmerBox(width: 90, height: 34, borderRadius: 17),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(width: 110, height: 12, borderRadius: 4),
                      SizedBox(height: 6),
                      ShimmerBox(width: 80, height: 14, borderRadius: 4),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Button
            const ShimmerBox(
              width: double.infinity,
              height: 50,
              borderRadius: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for the messages list (conversation list).
class MessagesListSkeleton extends StatelessWidget {
  final int itemCount;
  final Color? baseColor;
  final Color? highlightColor;

  const MessagesListSkeleton({
    super.key,
    this.itemCount = 5,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return TalqShimmer(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  // Avatar
                  const ShimmerBox(width: 48, height: 48, borderRadius: 16),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ShimmerBox(
                              width: 100 + (index % 3) * 30,
                              height: 14,
                              borderRadius: 4,
                            ),
                            const ShimmerBox(
                              width: 40,
                              height: 10,
                              borderRadius: 4,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ShimmerBox(
                          width: 180 + (index % 2) * 40,
                          height: 12,
                          borderRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Skeleton for chat messages while loading.
class ChatMessagesSkeleton extends StatelessWidget {
  final Color? baseColor;
  final Color? highlightColor;

  const ChatMessagesSkeleton({super.key, this.baseColor, this.highlightColor});

  @override
  Widget build(BuildContext context) {
    return TalqShimmer(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // Agent message (left-aligned)
            _buildMessageRow(isMe: false, width: 220),
            const SizedBox(height: 16),
            _buildMessageRow(isMe: false, width: 180),
            const SizedBox(height: 24),
            // User message (right-aligned)
            _buildMessageRow(isMe: true, width: 200),
            const SizedBox(height: 16),
            // Agent message
            _buildMessageRow(isMe: false, width: 260),
            const SizedBox(height: 16),
            _buildMessageRow(isMe: false, width: 140),
            const SizedBox(height: 24),
            // User message
            _buildMessageRow(isMe: true, width: 170),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageRow({required bool isMe, required double width}) {
    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMe) ...[
          const ShimmerBox(width: 28, height: 28, borderRadius: 14),
          const SizedBox(width: 8),
        ],
        ShimmerBox(width: width, height: 42, borderRadius: 18),
      ],
    );
  }
}

/// Skeleton for FAQ list items.
class FAQSkeleton extends StatelessWidget {
  final int itemCount;
  final Color? baseColor;
  final Color? highlightColor;

  const FAQSkeleton({
    super.key,
    this.itemCount = 3,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return TalqShimmer(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        children: List.generate(itemCount, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                const ShimmerBox(width: 36, height: 36, borderRadius: 12),
                const SizedBox(width: 14),
                Expanded(
                  child: ShimmerBox(
                    width: double.infinity,
                    height: 14,
                    borderRadius: 4,
                  ),
                ),
                const SizedBox(width: 12),
                const ShimmerBox(width: 16, height: 16, borderRadius: 4),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Animated bouncing dots typing indicator.
class TypingIndicatorDots extends StatefulWidget {
  final Color color;
  final double dotSize;
  final double spacing;

  const TypingIndicatorDots({
    super.key,
    this.color = Colors.grey,
    this.dotSize = 7,
    this.spacing = 4,
  });

  @override
  State<TypingIndicatorDots> createState() => _TypingIndicatorDotsState();
}

class _TypingIndicatorDotsState extends State<TypingIndicatorDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final t = (_controller.value - delay) % 1.0;
            // Smooth bounce: goes up then back down in first half of cycle
            final bounce = t < 0.5 ? (t * 2) : (1.0 - (t - 0.5) * 2);
            final offset =
                -4.0 * Curves.easeOut.transform(bounce.clamp(0.0, 1.0));

            return Padding(
              padding: EdgeInsets.only(left: index == 0 ? 0 : widget.spacing),
              child: Transform.translate(
                offset: Offset(0, offset),
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(
                      alpha: 0.4 + 0.6 * bounce.clamp(0.0, 1.0),
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
