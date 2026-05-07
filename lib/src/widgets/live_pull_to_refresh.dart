import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Lightweight, theme-friendly pull-to-refresh.
///
/// - No native [RefreshIndicator] or large platform spinners.
/// - Tracks overscroll via [NotificationListener] only — zero extra rebuilds
///   when the user is not pulling.
/// - Shows a small ring that fills with the primary color as the user pulls,
///   then becomes a thin indeterminate spinner while the refresh runs.
class LivePullToRefresh extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final bool isDark;
  final bool isRefreshing;
  final Color progressColor;
  final double triggerExtent;

  const LivePullToRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
    required this.isDark,
    this.isRefreshing = false,
    this.progressColor = const Color(0xFF111111),
    this.triggerExtent = 72,
  });

  /// Bouncing physics that caps the top overscroll so the pull feels
  /// controlled rather than rubber-band-elastic.
  static ScrollPhysics cappedScrollPhysics({double maxTopOverscroll = 96}) {
    return _CappedTopBouncingPhysics(
      maxTopOverscroll: maxTopOverscroll,
      parent: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
    );
  }

  @override
  State<LivePullToRefresh> createState() => _LivePullToRefreshState();
}

class _LivePullToRefreshState extends State<LivePullToRefresh>
    with SingleTickerProviderStateMixin {
  double _pullExtent = 0;
  bool _refreshing = false;
  bool _armedHaptic = false;
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isRefreshing) _spin.repeat();
  }

  @override
  void didUpdateWidget(covariant LivePullToRefresh old) {
    super.didUpdateWidget(old);
    final shouldSpin = _refreshing || widget.isRefreshing;
    if (shouldSpin && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!shouldSpin && _spin.isAnimating) {
      _spin.stop();
      _spin.value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;

    final overscroll = n.metrics.minScrollExtent - n.metrics.pixels;

    if (n is ScrollUpdateNotification || n is OverscrollNotification) {
      final next = overscroll > 0
          ? overscroll.clamp(0.0, widget.triggerExtent * 1.6).toDouble()
          : 0.0;
      if ((next - _pullExtent).abs() > 0.5) {
        setState(() => _pullExtent = next);
      }
      if (!_armedHaptic && next >= widget.triggerExtent) {
        _armedHaptic = true;
        HapticFeedback.selectionClick();
      } else if (_armedHaptic && next < widget.triggerExtent * 0.8) {
        _armedHaptic = false;
      }
    } else if (n is ScrollEndNotification) {
      final shouldFire = _pullExtent >= widget.triggerExtent && !_refreshing;
      if (shouldFire) {
        _fire();
      } else if (_pullExtent != 0) {
        setState(() {
          _pullExtent = 0;
          _armedHaptic = false;
        });
      }
    }
    return false;
  }

  Future<void> _fire() async {
    setState(() {
      _refreshing = true;
      _pullExtent = widget.triggerExtent;
    });
    _spin.repeat();
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        _spin.stop();
        _spin.value = 0;
        setState(() {
          _refreshing = false;
          _pullExtent = 0;
          _armedHaptic = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showing = _refreshing || widget.isRefreshing;
    final progress = (_pullExtent / widget.triggerExtent).clamp(0.0, 1.0);
    final headerHeight = showing
        ? 36.0
        : (_pullExtent > 0 ? (24 + progress * 12) : 0.0);

    return Column(
      children: [
        SizedBox(
          height: headerHeight,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 140),
            opacity: headerHeight > 0 ? 1 : 0,
            child: Center(
              child: _PullIndicator(
                color: widget.progressColor,
                progress: progress,
                spin: _spin,
                isRefreshing: showing,
              ),
            ),
          ),
        ),
        Expanded(
          child: NotificationListener<OverscrollIndicatorNotification>(
            onNotification: (notification) {
              notification.disallowIndicator();
              return true;
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}

class _PullIndicator extends StatelessWidget {
  final Color color;
  final double progress;
  final AnimationController spin;
  final bool isRefreshing;

  const _PullIndicator({
    required this.color,
    required this.progress,
    required this.spin,
    required this.isRefreshing,
  });

  @override
  Widget build(BuildContext context) {
    final scale = (0.6 + progress * 0.4).clamp(0.6, 1.0);
    return Transform.scale(
      scale: scale,
      child: SizedBox(
        width: 22,
        height: 22,
        child: AnimatedBuilder(
          animation: spin,
          builder: (context, _) {
            return CustomPaint(
              painter: _RingPainter(
                color: color,
                progress: progress,
                rotation: isRefreshing ? spin.value * 6.2832 : 0,
                isRefreshing: isRefreshing,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Color color;
  final double progress;
  final double rotation;
  final bool isRefreshing;

  _RingPainter({
    required this.color,
    required this.progress,
    required this.rotation,
    required this.isRefreshing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 2.2;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth;

    final track = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, track);

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);

    if (isRefreshing) {
      const sweep = 4.7124;
      canvas.drawArc(rect, -1.5708 + rotation, sweep, false, arcPaint);
      return;
    }

    final sweep = progress * 6.2832;
    canvas.drawArc(rect, -1.5708, sweep, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) {
    return old.color != color ||
        old.progress != progress ||
        old.rotation != rotation ||
        old.isRefreshing != isRefreshing;
  }
}

class _CappedTopBouncingPhysics extends BouncingScrollPhysics {
  final double maxTopOverscroll;

  const _CappedTopBouncingPhysics({
    required this.maxTopOverscroll,
    super.parent,
  });

  @override
  _CappedTopBouncingPhysics applyTo(ScrollPhysics? ancestor) {
    return _CappedTopBouncingPhysics(
      maxTopOverscroll: maxTopOverscroll,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final min = position.minScrollExtent;
    final current = position.pixels;
    final allowedTop = min - maxTopOverscroll;
    if (value < current && value < allowedTop) {
      return value - allowedTop;
    }
    return super.applyBoundaryConditions(position, value);
  }
}
