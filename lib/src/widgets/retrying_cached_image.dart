import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Waits between automatic attempts after a failed load. A dropped request, a
/// CDN hiccup or a short throttle on the storage host should heal by itself.
const List<Duration> kTalqImageRetryDelays = [
  Duration(seconds: 1),
  Duration(seconds: 3),
  Duration(seconds: 8),
];

/// Asks for the same object under a fresh URL so no cache layer can replay the
/// previous failure. R2 public URLs ignore query strings. Signed URLs and
/// non-http URLs are returned untouched because changing them would break or
/// mean nothing.
String talqWithRetryParam(String url, int attempt) {
  if (attempt == 0) return url;
  final uri = Uri.tryParse(url);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return url;
  }
  const signed = {'x-amz-signature', 'signature', 'sig'};
  if (uri.queryParameters.keys.any((k) => signed.contains(k.toLowerCase()))) {
    return url;
  }
  final sep = url.contains('?') ? '&' : '?';
  return '$url${sep}_r=$attempt';
}

/// A [CachedNetworkImage] that retries on failure, treats a stalled download
/// as a failure, and ends in a tap-to-retry state. Tapping the failure state
/// retries instead of passing the tap through, so an image that never loaded
/// doesn't open an empty viewer.
class RetryingCachedImage extends StatefulWidget {
  const RetryingCachedImage({
    super.key,
    required this.url,
    required this.placeholderBuilder,
    required this.failedBuilder,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.retryDelays = kTalqImageRetryDelays,
    this.loadTimeout = const Duration(seconds: 20),
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Shown while loading and between automatic retries.
  final WidgetBuilder placeholderBuilder;

  /// Shown once automatic retries are used up. The whole area retries on tap.
  final WidgetBuilder failedBuilder;

  final List<Duration> retryDelays;

  /// An attempt that hasn't produced an image by now counts as failed.
  final Duration loadTimeout;

  @override
  State<RetryingCachedImage> createState() => _RetryingCachedImageState();
}

enum _Status { loading, retrying, failed }

class _RetryingCachedImageState extends State<RetryingCachedImage>
    with WidgetsBindingObserver {
  // Only ever grows, so every request URL is new.
  int _attempt = 0;
  // Misses in the current round; a manual or automatic revive resets it.
  int _failures = 0;
  int _handledErrorFor = -1;
  int _loadedFor = -1;
  _Status _status = _Status.loading;
  Timer? _timer;
  Timer? _watchdog;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _armWatchdog();
  }

  @override
  void didUpdateWidget(covariant RetryingCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _timer?.cancel();
      _attempt = 0;
      _failures = 0;
      _handledErrorFor = -1;
      _loadedFor = -1;
      _status = _Status.loading;
      _armWatchdog();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _status == _Status.failed) {
      _retry();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  void _armWatchdog() {
    _watchdog?.cancel();
    final attempt = _attempt;
    _watchdog = Timer(widget.loadTimeout, () => _onError(attempt));
  }

  void _onLoaded(int attempt) {
    if (attempt != _attempt || _loadedFor == attempt) return;
    _loadedFor = attempt;
    _watchdog?.cancel();
  }

  void _onError(int attempt) {
    if (!mounted ||
        attempt != _attempt ||
        _handledErrorFor == attempt ||
        _loadedFor == attempt) {
      return;
    }
    _handledErrorFor = attempt;
    _timer?.cancel();
    _watchdog?.cancel();
    if (_failures >= widget.retryDelays.length) {
      setState(() {
        _failures++;
        _status = _Status.failed;
      });
      return;
    }
    final delay = widget.retryDelays[_failures];
    setState(() {
      _failures++;
      _status = _Status.retrying;
    });
    _timer = Timer(delay, () {
      if (!mounted) return;
      _evictCurrent();
      setState(() {
        _attempt++;
        _status = _Status.loading;
      });
      _armWatchdog();
    });
  }

  /// Every attempt shares [RetryingCachedImage.url] as its cache key, and
  /// the image provider's equality is that key, so Flutter's image cache would
  /// hand the next attempt the previous one's stream. A failed stream is
  /// evicted by the loader, but a stalled one is still pending and would be
  /// reused forever. Drop it so the next attempt really downloads.
  void _evictCurrent() {
    PaintingBinding.instance.imageCache.evict(
      CachedNetworkImageProvider(widget.url, cacheKey: widget.url),
    );
  }

  void _retry() {
    _timer?.cancel();
    _evictCurrent();
    setState(() {
      _attempt++;
      _failures = 0;
      _status = _Status.loading;
    });
    _armWatchdog();
  }

  @override
  Widget build(BuildContext context) {
    if (_status == _Status.failed) {
      return Semantics(
        button: true,
        label: 'Image unavailable. Tap to retry.',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _retry,
          child: widget.failedBuilder(context),
        ),
      );
    }
    if (_status == _Status.retrying) return widget.placeholderBuilder(context);

    final attempt = _attempt;
    return CachedNetworkImage(
      key: ValueKey(attempt),
      imageUrl: talqWithRetryParam(widget.url, attempt),
      // Cache under the real URL so a success on any attempt is reused by
      // every later view of this image.
      cacheKey: widget.url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: (context, _) => widget.placeholderBuilder(context),
      imageBuilder: (context, provider) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _onLoaded(attempt));
        return Image(
          image: provider,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
        );
      },
      errorWidget: (context, _, __) {
        // errorWidget runs during build; react to the failure after it.
        WidgetsBinding.instance.addPostFrameCallback((_) => _onError(attempt));
        return widget.placeholderBuilder(context);
      },
    );
  }
}
