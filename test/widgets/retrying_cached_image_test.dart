import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talq_flutter/src/widgets/retrying_cached_image.dart';

// 1x1 PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// A loopback image server whose behaviour each test scripts per request.
class _Server {
  _Server._(this._server);
  final io.HttpServer _server;
  final List<String> requests = [];

  /// Decides the fate of the nth request (1-based): 'ok', 'fail' or 'stall'.
  String Function(int n) behaviour = (_) => 'ok';

  static Future<_Server> start() async {
    final s = _Server._(
      await io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 0),
    );
    s._server.listen((req) async {
      s.requests.add(req.uri.query.isEmpty ? '-' : req.uri.query);
      final what = s.behaviour(s.requests.length);
      if (what == 'stall') return;
      if (what == 'fail') {
        req.response.statusCode = 503;
        await req.response.close();
        return;
      }
      req.response.headers.contentType = io.ContentType('image', 'png');
      req.response.add(_png);
      await req.response.close();
    });
    return s;
  }

  String get url => 'http://127.0.0.1:${_server.port}/img.png';
  Future<void> close() => _server.close(force: true);
}

/// Stands in for the disk cache (which needs platform plugins) and downloads
/// straight from the loopback server, the way the real one would. It stores
/// nothing, so every attempt really goes to the network.
class _NetworkOnlyCacheManager implements BaseCacheManager {
  final _client = io.HttpClient();
  final List<String?> keys = [];
  int _n = 0;

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) async* {
    keys.add(key);
    final req = await _client.getUrl(Uri.parse(url));
    final res = await req.close();
    if (res.statusCode != 200) {
      await res.drain<void>();
      throw HttpExceptionWithStatus(res.statusCode, 'status ${res.statusCode}');
    }
    final bytes = await res.fold<List<int>>([], (a, b) => a..addAll(b));
    final dir = io.Directory.systemTemp.createTempSync('talq_img_');
    final path = '${dir.path}/img_${_n++}.png';
    io.File(path).writeAsBytesSync(bytes);
    yield FileInfo(
      const LocalFileSystem().file(path),
      FileSource.Online,
      DateTime.now().add(const Duration(days: 1)),
      url,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _fast = [
  Duration(milliseconds: 40),
  Duration(milliseconds: 40),
  Duration(milliseconds: 40),
];

Widget _host(Widget child, {VoidCallback? onOuterTap}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: GestureDetector(
        onTap: onOuterTap,
        child: SizedBox(width: 200, height: 200, child: child),
      ),
    ),
  ),
);

RetryingCachedImage _image(String url, {Duration? loadTimeout}) =>
    RetryingCachedImage(
      url: url,
      retryDelays: _fast,
      loadTimeout: loadTimeout ?? const Duration(seconds: 20),
      placeholderBuilder: (_) => const Text('loading'),
      failedBuilder: (_) => const Text('Image unavailable'),
    );

bool _imageShown(WidgetTester tester) => tester
    .widgetList<RawImage>(find.byType(RawImage))
    .any((r) => r.image != null);

/// Lets real IO run, then advances the fake clock that drives the widget's
/// retry and timeout timers, until [done] or the deadline.
Future<void> _settleUntil(
  WidgetTester tester,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final end = DateTime.now().add(timeout);
  while (!done() && DateTime.now().isBefore(end)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 30));
  }
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 30));
}

void main() {
  late _NetworkOnlyCacheManager cache;

  setUpAll(() => io.HttpOverrides.global = null);

  setUp(() {
    cache = _NetworkOnlyCacheManager();
    CachedNetworkImageProvider.defaultCacheManager = cache;
    // Each test uses a fresh server URL, but clear in-memory images anyway.
    PaintingBinding.instance.imageCache.clear();
  });

  group('talqWithRetryParam', () {
    test('first attempt untouched, retries get a throwaway parameter', () {
      expect(
        talqWithRetryParam('https://x.dev/a.png', 0),
        'https://x.dev/a.png',
      );
      expect(
        talqWithRetryParam('https://x.dev/a.png', 3),
        'https://x.dev/a.png?_r=3',
      );
    });
    test('signed and non-http URLs are never changed', () {
      const signed = 'https://b.s3.dev/a.png?X-Amz-Signature=abc';
      expect(talqWithRetryParam(signed, 2), signed);
      expect(talqWithRetryParam('file:///a.png', 2), 'file:///a.png');
    });
  });

  testWidgets('recovers after two failures, cached under the real URL', (
    tester,
  ) async {
    final server = (await tester.runAsync(_Server.start))!;
    addTearDown(() => tester.runAsync(server.close));
    server.behaviour = (n) => n <= 2 ? 'fail' : 'ok';

    await tester.pumpWidget(_host(_image(server.url)));
    expect(find.text('loading'), findsOneWidget);

    await _settleUntil(tester, () => _imageShown(tester));

    expect(_imageShown(tester), isTrue);
    expect(server.requests, ['-', '_r=1', '_r=2']);
    expect(cache.keys.toSet(), {server.url});
    await _finish(tester);
  });

  testWidgets('gives up, then tap-to-retry loads it without reaching the '
      'bubble', (tester) async {
    final server = (await tester.runAsync(_Server.start))!;
    addTearDown(() => tester.runAsync(server.close));
    var healed = false;
    server.behaviour = (_) => healed ? 'ok' : 'fail';
    var outerTaps = 0;

    await tester.pumpWidget(
      _host(_image(server.url), onOuterTap: () => outerTaps++),
    );
    await _settleUntil(
      tester,
      () => find.text('Image unavailable').evaluate().isNotEmpty,
    );
    expect(find.text('Image unavailable'), findsOneWidget);
    expect(server.requests.length, 4);

    healed = true;
    await tester.tap(find.text('Image unavailable'));
    await _settleUntil(tester, () => _imageShown(tester));

    expect(_imageShown(tester), isTrue);
    expect(outerTaps, 0);
    expect(server.requests.last, '_r=4');
    await _finish(tester);
  });

  testWidgets('a stalled download times out and is retried', (tester) async {
    final server = (await tester.runAsync(_Server.start))!;
    addTearDown(() => tester.runAsync(server.close));
    server.behaviour = (n) => n == 1 ? 'stall' : 'ok';

    await tester.pumpWidget(
      _host(_image(server.url, loadTimeout: const Duration(milliseconds: 300))),
    );
    await _settleUntil(tester, () => _imageShown(tester));

    expect(_imageShown(tester), isTrue);
    expect(server.requests, ['-', '_r=1']);
    await _finish(tester);
  });

  testWidgets('a healthy image is fetched once and never retried', (
    tester,
  ) async {
    final server = (await tester.runAsync(_Server.start))!;
    addTearDown(() => tester.runAsync(server.close));

    await tester.pumpWidget(
      _host(_image(server.url, loadTimeout: const Duration(milliseconds: 300))),
    );
    await _settleUntil(tester, () => _imageShown(tester));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(_imageShown(tester), isTrue);
    expect(server.requests, ['-']);
    await _finish(tester);
  });
}
