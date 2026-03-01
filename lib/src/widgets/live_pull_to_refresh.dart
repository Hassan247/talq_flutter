import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.triggerExtent = 96,
  });

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

class _LivePullToRefreshState extends State<LivePullToRefresh> {
  RefreshIndicatorStatus? _refreshStatus;
  double _pullExtent = 0;
  bool _refreshInFlight = false;
  bool _snapLock = false;
  bool _snappedThisPull = false;

  bool get _isPulling =>
      _refreshStatus == RefreshIndicatorStatus.drag ||
      _refreshStatus == RefreshIndicatorStatus.armed;

  bool get _isArmed => _refreshStatus == RefreshIndicatorStatus.armed;

  bool get _showTopProgress => widget.isRefreshing || _refreshInFlight;

  @override
  Widget build(BuildContext context) {
    final pullProgress = (_pullExtent / widget.triggerExtent).clamp(0.0, 1.0);
    final showLiquidPull = !_showTopProgress && _isPulling && _pullExtent > 1;
    final liquidHeight = Curves.easeOutCubic.transform(pullProgress) * 120;

    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _showTopProgress
              ? LinearProgressIndicator(
                  key: const ValueKey('live_pull_refresh_progress'),
                  minHeight: 2,
                  color: widget.progressColor,
                  backgroundColor: Colors.transparent,
                )
              : const SizedBox(
                  key: ValueKey('live_pull_refresh_spacer'),
                  height: 2,
                ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: showLiquidPull
              ? ClipRect(
                  child: SizedBox(
                    height: liquidHeight.clamp(0.0, 120.0),
                    width: double.infinity,
                    child: _LiquidPullIndicator(
                      color: widget.progressColor,
                      progress: pullProgress,
                      isDark: widget.isDark,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(
          child: RefreshIndicator.noSpinner(
            onStatusChange: _onStatusChanged,
            onRefresh: _handleRefresh,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (_isPulling) {
                  final overscrollExtent =
                      notification.metrics.minScrollExtent -
                      notification.metrics.pixels;
                  if (_isArmed &&
                      overscrollExtent > widget.triggerExtent + 1 &&
                      !_snapLock &&
                      !_snappedThisPull) {
                    _snappedThisPull = true;
                    _snapToTrigger(notification);
                  }
                  final nextPullExtent = overscrollExtent > 0
                      ? overscrollExtent
                            .clamp(0.0, widget.triggerExtent)
                            .toDouble()
                      : 0.0;
                  if ((nextPullExtent - _pullExtent).abs() > 0.5 && mounted) {
                    setState(() => _pullExtent = nextPullExtent);
                  }
                } else if (_pullExtent > 0 &&
                    notification is ScrollEndNotification &&
                    mounted) {
                  setState(() => _pullExtent = 0);
                }
                return false;
              },
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }

  void _onStatusChanged(RefreshIndicatorStatus? status) {
    if (!mounted) return;
    final shouldResetPullExtent =
        status == null ||
        (status != RefreshIndicatorStatus.drag &&
            status != RefreshIndicatorStatus.armed);
    if (_refreshStatus == status && !shouldResetPullExtent) {
      return;
    }
    setState(() {
      _refreshStatus = status;
      if (shouldResetPullExtent) {
        _pullExtent = 0;
        _snapLock = false;
        _snappedThisPull = false;
      }
    });

    if (status == RefreshIndicatorStatus.armed) {
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _handleRefresh() async {
    if (_refreshInFlight) return;
    if (mounted) {
      setState(() => _refreshInFlight = true);
    }
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() => _refreshInFlight = false);
      }
    }
  }

  void _snapToTrigger(ScrollNotification notification) {
    final notificationContext = notification.context;
    if (notificationContext == null) return;
    final scrollable = Scrollable.maybeOf(notificationContext);
    final position = scrollable?.position;
    if (position == null) return;

    final targetPixels = notification.metrics.minScrollExtent;
    if (position.pixels >= targetPixels) return;

    _snapLock = true;
    try {
      position.jumpTo(targetPixels);
    } catch (_) {
      // Ignore jump failures and continue gracefully.
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _snapLock = false;
    });
  }
}

class _LiquidPullIndicator extends StatelessWidget {
  final Color color;
  final double progress;
  final bool isDark;

  const _LiquidPullIndicator({
    required this.color,
    required this.progress,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedProgress = progress.clamp(0.0, 1.0);
    final surface = color.withValues(alpha: isDark ? 0.88 : 0.72);

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: CustomPaint(
        painter: _LiquidWavePainter(
          color: surface,
          progress: normalizedProgress,
        ),
      ),
    );
  }
}

class _LiquidWavePainter extends CustomPainter {
  final Color color;
  final double progress;

  const _LiquidWavePainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final waveDepth = size.height * (0.18 + (progress * 0.5));
    final crestY = size.height - waveDepth;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, crestY)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height + (waveDepth * 0.2),
        0,
        crestY,
      )
      ..close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LiquidWavePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.progress != progress;
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
