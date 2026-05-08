/// Backend-driven configuration the SDK fetches on initialization so behavior
/// (timers, upload limits, feature flags, copy) can be changed server-side
/// without forcing customer apps to ship a new build.
///
/// Every field has a safe compile-time default; if the backend hasn't yet
/// implemented `widgetConfig` (or the call fails) the SDK falls back to the
/// values defined in [TalqWidgetConfig.defaults]. This makes the SDK
/// forward-compatible: when the backend gradually adds fields, integrated
/// apps pick them up automatically on next launch — no rebuild required.
class TalqWidgetConfig {
  // ---------------- Network / realtime timers ----------------
  /// HTTP connect timeout in ms.
  final int connectTimeoutMs;

  /// HTTP send timeout in ms.
  final int sendTimeoutMs;

  /// HTTP receive timeout in ms.
  final int receiveTimeoutMs;

  /// GraphQL subscription inactivity timeout (ms) before the WebSocket
  /// considers itself stale and reconnects.
  final int wsInactivityTimeoutMs;

  /// Heartbeat (keepalive) ping interval in ms.
  final int wsHeartbeatMs;

  /// How long to wait after a typing event before clearing the indicator (ms).
  final int typingStopMs;

  /// Throttle window for outbound typing events (ms).
  final int typingThrottleMs;

  /// Auto-dismiss for in-app notification toasts (ms).
  final int notificationAutoDismissMs;

  /// Reconnect backoff for subscription/error recovery (ms).
  final int reconnectBackoffMs;

  // ---------------- Limits ----------------
  /// File extensions allowed in the document picker.
  final List<String> allowedFileExtensions;

  /// Maximum upload size in bytes. 0 means "no limit".
  final int maxUploadBytes;

  /// Maximum visitor message length. 0 means "no limit".
  final int messageMaxLength;

  // ---------------- SDK version policy ----------------
  /// Minimum SDK version the backend still accepts. SDKs below this should
  /// surface a "please update" message. Empty string means "no minimum".
  final String minSdkVersion;

  /// Recommended SDK version. Optional UI hint.
  final String recommendedSdkVersion;

  /// Optional message shown alongside a deprecation notice.
  final String deprecationMessage;

  // ---------------- TTL / cache ----------------
  /// How long the SDK should trust this snapshot before refetching (seconds).
  final int ttlSeconds;

  const TalqWidgetConfig({
    this.connectTimeoutMs = 15000,
    this.sendTimeoutMs = 30000,
    this.receiveTimeoutMs = 30000,
    this.wsInactivityTimeoutMs = 30000,
    this.wsHeartbeatMs = 15000,
    this.typingStopMs = 3000,
    this.typingThrottleMs = 2000,
    this.notificationAutoDismissMs = 5000,
    this.reconnectBackoffMs = 5000,
    this.allowedFileExtensions = const ['pdf'],
    this.maxUploadBytes = 0,
    this.messageMaxLength = 0,
    this.minSdkVersion = '',
    this.recommendedSdkVersion = '',
    this.deprecationMessage = '',
    this.ttlSeconds = 3600,
  });

  /// The compile-time defaults used when no widget config is available
  /// (backend hasn't shipped the resolver yet, network failure, etc.).
  static const TalqWidgetConfig defaults = TalqWidgetConfig();

  factory TalqWidgetConfig.fromJson(Map<String, dynamic> json) {
    int ms(dynamic v, int fallback) => v is num
        ? v.toInt()
        : (v is String ? int.tryParse(v) ?? fallback : fallback);
    String str(dynamic v, String fallback) => v is String ? v : fallback;
    List<String> strList(dynamic v, List<String> fallback) {
      if (v is List) return v.whereType<String>().toList();
      return fallback;
    }

    final timers = (json['timers'] as Map?) ?? const {};
    final limits = (json['limits'] as Map?) ?? const {};
    final sdk = (json['sdkPolicy'] as Map?) ?? const {};

    return TalqWidgetConfig(
      connectTimeoutMs: ms(timers['connectMs'], defaults.connectTimeoutMs),
      sendTimeoutMs: ms(timers['sendMs'], defaults.sendTimeoutMs),
      receiveTimeoutMs: ms(timers['receiveMs'], defaults.receiveTimeoutMs),
      wsInactivityTimeoutMs: ms(
        timers['wsInactivityMs'],
        defaults.wsInactivityTimeoutMs,
      ),
      wsHeartbeatMs: ms(timers['heartbeatMs'], defaults.wsHeartbeatMs),
      typingStopMs: ms(timers['typingStopMs'], defaults.typingStopMs),
      typingThrottleMs: ms(
        timers['typingThrottleMs'],
        defaults.typingThrottleMs,
      ),
      notificationAutoDismissMs: ms(
        timers['notificationDismissMs'],
        defaults.notificationAutoDismissMs,
      ),
      reconnectBackoffMs: ms(
        timers['reconnectBackoffMs'],
        defaults.reconnectBackoffMs,
      ),
      allowedFileExtensions: strList(
        limits['allowedFileExtensions'],
        defaults.allowedFileExtensions,
      ),
      maxUploadBytes: ms(limits['maxUploadBytes'], defaults.maxUploadBytes),
      messageMaxLength: ms(
        limits['messageMaxLength'],
        defaults.messageMaxLength,
      ),
      minSdkVersion: str(sdk['minVersion'], defaults.minSdkVersion),
      recommendedSdkVersion: str(
        sdk['recommendedVersion'],
        defaults.recommendedSdkVersion,
      ),
      deprecationMessage: str(
        sdk['deprecationMessage'],
        defaults.deprecationMessage,
      ),
      ttlSeconds: ms(json['ttlSeconds'], defaults.ttlSeconds),
    );
  }

  Map<String, dynamic> toJson() => {
    'timers': {
      'connectMs': connectTimeoutMs,
      'sendMs': sendTimeoutMs,
      'receiveMs': receiveTimeoutMs,
      'wsInactivityMs': wsInactivityTimeoutMs,
      'heartbeatMs': wsHeartbeatMs,
      'typingStopMs': typingStopMs,
      'typingThrottleMs': typingThrottleMs,
      'notificationDismissMs': notificationAutoDismissMs,
      'reconnectBackoffMs': reconnectBackoffMs,
    },
    'limits': {
      'allowedFileExtensions': allowedFileExtensions,
      'maxUploadBytes': maxUploadBytes,
      'messageMaxLength': messageMaxLength,
    },
    'sdkPolicy': {
      'minVersion': minSdkVersion,
      'recommendedVersion': recommendedSdkVersion,
      'deprecationMessage': deprecationMessage,
    },
    'ttlSeconds': ttlSeconds,
  };
}
