import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../core/auth_manager.dart';
import '../core/device_info_collector.dart';
import '../core/talq_cache.dart';
import '../core/talq_client.dart';
import '../core/talq_error_mapper.dart';
import '../models/models.dart';
import '../theme/talq_theme.dart';
import '../workflows/talq_use_cases.dart';

class TalqController extends ChangeNotifier {
  final TalqUseCases _useCases;

  List<TalqMessage> _messages = [];
  // The room `_messages` currently belongs to. Tracked separately from
  // `_roomId` because initialize()/fetchRooms reassign `_roomId` to the
  // active room without touching the thread on screen.
  String? _messagesRoomId;
  final Map<String, List<TalqMessage>> _messageCache = {};
  List<TalqRoom> _rooms = [];
  static const int _roomListChunkSize = 15;
  int _visibleRoomCount = _roomListChunkSize;
  bool _isFetchingMoreRooms = false;
  // visitorRooms is not paginated server-side: once a load-more fetch comes
  // back with nothing new there is nothing more to get until the next
  // refresh. Without this, every scroll near the bottom re-fetched and the
  // spinner never went away.
  bool _roomsExhausted = false;
  List<TalqFAQ> _faqs = [];

  List<TalqFAQ> _paginatedFaqs = [];
  bool _faqHasNextPage = false;
  String? _faqEndCursor;
  String _faqSearchQuery = '';
  bool _isFaqLoading = false;

  bool _hasMoreMessages = false;
  bool _isFetchingMore = false;
  bool _isRoomLoading = false;

  bool _isLoading = false;
  bool _isInitialized = false;

  /// Email this session was last successfully identified with, so a later
  /// identify call carrying a NEW email is not swallowed by the guard below.
  String? _identifiedEmail;
  String? _errorMessage;
  TalqVisitor? _visitor;
  TalqWorkspace? _workspace;
  String? _roomId;
  RoomStatus _roomStatus = RoomStatus.open;
  bool _isRatingSubmitted = false;
  int? _rating;
  String? _ratingComment;
  bool _showRatingPrompt = false;
  bool _isAgentTyping = false;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _messageUpdatedSubscription;
  StreamSubscription? _typingSubscription;
  StreamSubscription? _roomSubscription;
  StreamSubscription? _workspaceSubscription;
  Timer? _typingTimer;
  TalqMessage? _replyingTo;
  bool _isChatVisible = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  int _fetchVersion = 0;
  bool _disposed = false;

  TalqMessage? _pendingNotification;
  Timer? _notificationTimer;

  TalqTheme _theme = const TalqTheme();
  TalqWidgetConfig _widgetConfig = TalqWidgetConfig.defaults;

  TalqController(TalqClient client)
    : _useCases = TalqUseCases.fromClient(client) {
    _loadCachedTheme();
    _hydrateFromCache();
  }

  /// Pick a contrasting text color (white on dark, near-black on light) for
  /// the user bubble so visitor messages stay readable regardless of brand
  /// color.
  Color _onPrimary(Color c) {
    return c.computeLuminance() > 0.55 ? const Color(0xDD000000) : Colors.white;
  }

  /// Load cached primary color so the FAB shows the correct color immediately
  Future<void> _loadCachedTheme() async {
    final cachedHex = await AuthManager.getPrimaryColor();
    if (cachedHex != null && cachedHex.isNotEmpty) {
      try {
        final c = TalqTheme.fromHex(cachedHex);
        _theme = _theme.copyWith(
          primaryColor: c,
          userBubbleColor: c,
          userTextColor: _onPrimary(c),
          resolvedTextColor: TalqTheme.resolvedAccentFor(c),
          resolvedBackgroundColor: TalqTheme.resolvedSurfaceFor(c),
        );
        notifyListeners();
      } catch (_) {}
    }
  }

  /// Restore last-good workspace / rooms / faqs / widgetConfig from disk so
  /// the home screen shows real content on cold open instead of flashing
  /// empty white cards while the network round-trip completes.
  Future<void> _hydrateFromCache() async {
    try {
      final cachedWidgetConfig = await TalqCache.getWidgetConfig();
      if (cachedWidgetConfig != null) {
        _widgetConfig = TalqWidgetConfig.fromJson(cachedWidgetConfig);
      }

      final cachedWorkspace = await TalqCache.getWorkspace();
      if (cachedWorkspace != null) {
        try {
          final ws = TalqWorkspace.fromJson(cachedWorkspace);
          final avatars = await TalqCache.getAgentAvatars();
          _workspace = ws.copyWith(agentAvatars: avatars);
          if (_workspace!.primaryColor.isNotEmpty) {
            try {
              final c = TalqTheme.fromHex(_workspace!.primaryColor);
              _theme = _theme.copyWith(
                primaryColor: c,
                userBubbleColor: c,
                userTextColor: _onPrimary(c),
                resolvedTextColor: TalqTheme.resolvedAccentFor(c),
                resolvedBackgroundColor: TalqTheme.resolvedSurfaceFor(c),
              );
            } catch (_) {}
          }
        } catch (_) {}
      }

      final cachedFaqs = await TalqCache.getFaqs();
      if (cachedFaqs.isNotEmpty) {
        try {
          _faqs = cachedFaqs.map((f) => TalqFAQ.fromJson(f)).toList();
        } catch (_) {}
      }

      final cachedRooms = await TalqCache.getRooms();
      if (cachedRooms.isNotEmpty) {
        try {
          _rooms = cachedRooms.map((r) => TalqRoom.fromJson(r)).toList();
          _sortRooms();
          _syncVisibleRoomCount(reset: true);
        } catch (_) {}
      }

      // We're "initialized" from the user's perspective if we have a cached
      // workspace — the next live fetch will refresh in the background.
      if (_workspace != null) {
        _isInitialized = true;
      }
      if (_disposed) return;
      notifyListeners();
    } catch (_) {
      // best-effort cache hydration; never block startup on errors.
    }
  }

  List<TalqMessage> get messages => _messages;
  List<TalqRoom> get rooms => _rooms;
  List<TalqRoom> get visibleRooms => _rooms
      .take(math.min(_visibleRoomCount, _rooms.length))
      .toList(growable: false);
  bool get hasMoreRoomsToDisplay => _visibleRoomCount < _rooms.length;
  bool get isFetchingMoreRooms => _isFetchingMoreRooms;
  List<TalqFAQ> get faqs => _faqs;
  List<TalqFAQ> get paginatedFaqs => _paginatedFaqs;
  bool get faqHasNextPage => _faqHasNextPage;
  String get faqSearchQuery => _faqSearchQuery;
  bool get isFaqLoading => _isFaqLoading;
  bool get hasMoreMessages => _hasMoreMessages;
  bool get isFetchingMore => _isFetchingMore;
  bool get isRoomLoading => _isRoomLoading;

  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  TalqVisitor? get visitor => _visitor;
  TalqWorkspace? get workspace => _workspace;
  String? get roomId => _roomId;
  RoomStatus get roomStatus => _roomStatus;
  TalqTheme get theme => _theme;
  TalqWidgetConfig get widgetConfig => _widgetConfig;

  /// Whether the SDK has a workspace object available (cached or fresh).
  /// Use this — not [isInitialized] — to gate per-card UI on the home screen,
  /// so cached workspaces render real content instantly on cold open.
  bool get hasWorkspace => _workspace != null;

  /// Whether rooms have been hydrated (cache or fresh fetch).
  bool get hasRooms => _rooms.isNotEmpty;

  /// Whether FAQs have been hydrated (cache or fresh fetch).
  bool get hasFaqs => _faqs.isNotEmpty;

  TalqRoom? get currentRoom {
    if (_roomId == null) return null;
    try {
      return _rooms.firstWhere((r) => r.id == _roomId);
    } catch (_) {
      return null;
    }
  }

  void _cacheMessagesForRoom(String roomId, List<TalqMessage> messages) {
    _messageCache[roomId] = List<TalqMessage>.from(messages);
  }

  void _cacheCurrentRoomMessages() {
    // Key on the thread's own room, never `_roomId`: caching room B's
    // messages under room A's id is how one chat's history leaked into
    // another.
    final owner = _messagesRoomId;
    if (owner == null) return;
    _cacheMessagesForRoom(owner, _messages);
  }

  void _syncVisibleRoomCount({bool reset = false}) {
    if (_rooms.isEmpty) {
      _visibleRoomCount = 0;
      return;
    }

    if (reset || _visibleRoomCount == 0) {
      _visibleRoomCount = math.min(_roomListChunkSize, _rooms.length);
      return;
    }

    _visibleRoomCount = math.max(
      _visibleRoomCount,
      math.min(_roomListChunkSize, _rooms.length),
    );
  }

  List<TalqMessage> _mergeMessagesNewestFirst({
    required List<TalqMessage> localMessages,
    required List<TalqMessage> serverMessages,
    String? roomId,
  }) {
    final mergedById = <String, TalqMessage>{
      for (final message in localMessages)
        if (roomId == null ||
            message.roomId == null ||
            message.roomId == roomId)
          message.id: message,
    };

    for (final serverMessage in serverMessages) {
      final existingMessage = mergedById[serverMessage.id];
      if (existingMessage == null) {
        mergedById[serverMessage.id] = serverMessage;
        continue;
      }

      mergedById[serverMessage.id] = TalqMessage(
        id: serverMessage.id,
        roomId: serverMessage.roomId ?? existingMessage.roomId,
        content: serverMessage.content,
        senderType: serverMessage.senderType,
        senderName: serverMessage.senderName ?? existingMessage.senderName,
        senderAvatarUrl:
            serverMessage.senderAvatarUrl ?? existingMessage.senderAvatarUrl,
        contentType: serverMessage.contentType,
        fileUrl: serverMessage.fileUrl ?? existingMessage.fileUrl,
        fileName: serverMessage.fileName ?? existingMessage.fileName,
        createdAt: serverMessage.createdAt,
        isRead: serverMessage.isRead || existingMessage.isRead,
        isDelivered: serverMessage.isDelivered || existingMessage.isDelivered,
        replyTo: serverMessage.replyTo ?? existingMessage.replyTo,
        reactions: serverMessage.reactions.isNotEmpty
            ? serverMessage.reactions
            : existingMessage.reactions,
        localFilePath: existingMessage.localFilePath,
        isUploading: false,
        deletedAt: serverMessage.deletedAt ?? existingMessage.deletedAt,
        deletedBy: serverMessage.deletedBy ?? existingMessage.deletedBy,
        editedAt: serverMessage.editedAt ?? existingMessage.editedAt,
      );
    }

    final mergedMessages = mergedById.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return mergedMessages;
  }

  bool get isRatingSubmitted => _isRatingSubmitted;
  int? get rating => _rating;
  String? get ratingComment => _ratingComment;
  bool get showRatingPrompt => _showRatingPrompt;
  bool get isAgentTyping => _isAgentTyping;
  TalqMessage? get replyingTo => _replyingTo;
  bool get isChatVisible => _isChatVisible;
  AppLifecycleState get lifecycleState => _lifecycleState;

  TalqMessage? get pendingNotification => _pendingNotification;

  /// Total unread message count across all rooms (for badge display)
  int get totalUnreadCount =>
      _rooms.fold(0, (sum, room) => sum + room.visitorUnreadCount);

  void _showInAppNotification(TalqMessage message) {
    _notificationTimer?.cancel();
    _pendingNotification = message;
    notifyListeners();
    _notificationTimer = Timer(const Duration(seconds: 5), () {
      dismissNotification();
    });
  }

  void dismissNotification() {
    if (_pendingNotification == null) return;
    _pendingNotification = null;
    _notificationTimer?.cancel();
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void reportError(
    Object? error, {
    String fallbackMessage = 'Something went wrong. Please try again.',
  }) {
    _setError(error, fallbackMessage: fallbackMessage);
  }

  void _clearError({bool notify = false}) {
    if (_errorMessage == null) return;
    _errorMessage = null;
    if (notify) {
      notifyListeners();
    }
  }

  void _setError(Object? error, {required String fallbackMessage}) {
    final mapped = TalqErrorMapper.toUserMessage(
      error,
      fallbackMessage: fallbackMessage,
    );
    if (mapped.isEmpty) return;
    if (_errorMessage == mapped) return;
    _errorMessage = mapped;
    notifyListeners();
  }

  /// Call this when the app lifecycle changes
  void setLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed &&
        _isChatVisible &&
        _roomId != null) {
      markAsRead();
    }
  }

  /// Call this when the chat view becomes visible (mounted/resumed)
  void setChatVisible(bool visible) {
    _isChatVisible = visible;
    if (visible &&
        _roomId != null &&
        _lifecycleState == AppLifecycleState.resumed) {
      markAsRead();
    }
  }

  void setReplyingTo(TalqMessage? message) {
    _replyingTo = message;
    notifyListeners();
  }

  /// Initializes the talq session
  Future<void> initialize({
    String? firstName,
    String? lastName,
    String? email,
    String? currentPage,
    Map<String, dynamic>? metadata,
    String? pushToken,
  }) async {
    // Re-initialise when a newly-supplied email differs from the one we last
    // identified with. The backend merges visitors by email, so skipping that
    // call strands the visitor's history on their old device-scoped id — which
    // is why past conversations vanished on a new device or app version.
    // (Cache hydration also flips _isInitialized, so without this check the
    // email never reached the backend after the very first run.)
    final normalizedEmail = email?.trim().toLowerCase();
    final needsIdentify =
        normalizedEmail != null && normalizedEmail != _identifiedEmail;
    if (_isInitialized && _workspace != null && !needsIdentify) return;
    if (_isLoading) return;

    _clearError(notify: true);
    _isLoading = true;
    final capturedVersion = _fetchVersion;
    notifyListeners();

    try {
      await _useCases.initializeClient();

      final deviceId = await AuthManager.getDeviceId();
      final platform = AuthManager.getPlatform();
      final deviceInfo = await DeviceInfoCollector.collect();
      final devicePayload = deviceInfo.isNotEmpty
          ? {
              'deviceModel': deviceInfo['deviceModel'],
              'osVersion': deviceInfo['osVersion'],
              'appVersion': deviceInfo['appVersion'],
              'browser': deviceInfo['browser'],
              'browserVersion': deviceInfo['browserVersion'],
              'browserLanguage': deviceInfo['browserLanguage'],
              'os': deviceInfo['os'],
            }
          : null;
      debugPrint(
        '[TalqController] Starting initVisitor (email: ${email ?? "<null>"}, deviceId: $deviceId)...',
      );

      final result = await _useCases.initVisitor(
        deviceId: deviceId,
        platform: platform,
        firstName: firstName,
        lastName: lastName,
        email: email,
        metadata: metadata,
        pushToken: pushToken,
        deviceInfo: devicePayload,
      );

      debugPrint(
        '[TalqController] initVisitor result hasException: ${result.hasException}',
      );

      if (result.hasException) {
        debugPrint(
          '[TalqController] initVisitor exception: ${result.exception}',
        );
        // Only mark as initialized when we already have *some* data to render
        // (cached workspace from a previous session). Otherwise leave the
        // skeleton up so the user doesn't see a row of empty white cards.
        if (_workspace != null) {
          _isInitialized = true;
          _identifiedEmail = normalizedEmail ?? _identifiedEmail;
        }
        _setError(
          result.exception,
          fallbackMessage: 'Unable to start chat right now.',
        );
        return;
      }

      final authData = result.data!['initVisitor'];
      await AuthManager.saveToken(authData['token']);
      _visitor = TalqVisitor.fromJson(authData['visitor']);

      final ws = TalqWorkspace.fromJson(authData['workspace']);
      final avatars = (authData['agentAvatars'] as List?)?.cast<String>() ?? [];
      _workspace = ws.copyWith(agentAvatars: avatars);

      // Persist last-good workspace + agentAvatars for next cold open.
      unawaited(
        TalqCache.saveWorkspace(
          Map<String, dynamic>.from(authData['workspace'] as Map),
          agentAvatars: avatars,
        ),
      );

      if (_workspace!.primaryColor.isNotEmpty) {
        try {
          final c = TalqTheme.fromHex(_workspace!.primaryColor);
          _theme = _theme.copyWith(
            primaryColor: c,
            userBubbleColor: c,
            userTextColor: _onPrimary(c),
            resolvedTextColor: TalqTheme.resolvedAccentFor(c),
            resolvedBackgroundColor: TalqTheme.resolvedSurfaceFor(c),
          );
          AuthManager.savePrimaryColor(_workspace!.primaryColor);
        } catch (_) {
          // invalid hex, keep default
        }
      }

      final List faqsList = authData['faqs'] ?? [];
      _faqs = faqsList.map((f) => TalqFAQ.fromJson(f)).toList();
      unawaited(
        TalqCache.saveFaqs(
          faqsList
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
        ),
      );

      final List roomsList = authData['visitor']['rooms'] ?? [];
      final newRooms = roomsList.map((r) => TalqRoom.fromJson(r)).toList();
      unawaited(
        TalqCache.saveRooms(
          roomsList
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
        ),
      );

      if (capturedVersion != _fetchVersion) {
        return;
      }

      _rooms = newRooms;
      _sortRooms();
      _syncVisibleRoomCount(reset: true);

      if (_rooms.isNotEmpty) {
        final activeRoom = _rooms.firstWhere(
          (r) => r.status == RoomStatus.open || r.status == RoomStatus.assigned,
          orElse: () => _rooms.first,
        );
        _roomId = activeRoom.id;
        _roomStatus = activeRoom.status;
        _rating = activeRoom.rating;
        _ratingComment = activeRoom.ratingComment;
        _isRatingSubmitted = activeRoom.rating != null;

        if (_roomStatus == RoomStatus.resolved) {
          _showRatingPrompt = _rating == null;
        }
      }

      await _useCases.initializeClient();

      if (_roomId != null) {
        unawaited(fetchMessages(roomId: _roomId));
      }

      _startMessageSubscription();
      _startWorkspaceSubscription();
      if (_roomId != null) {
        _startTypingSubscription();
      }

      if (currentPage != null) {
        unawaited(updatePage(currentPage));
      }

      _isInitialized = true;
      _clearError();
      // Refresh server-driven config in the background; non-blocking.
      unawaited(fetchWidgetConfig());
    } catch (e) {
      // Same rationale as the result.hasException branch above.
      if (_workspace != null) {
        _isInitialized = true;
      }
      _setError(e, fallbackMessage: 'Unable to start chat right now.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Prepares the controller for a new conversation locally without creating a room on the backend.
  /// The room will be created when the first message is sent.
  void prepareNewConversation() {
    _fetchVersion++;
    _roomId = null;
    _messagesRoomId = null;
    _messages = [];
    _hasMoreMessages = false;
    _isRoomLoading = false;
    _roomStatus = RoomStatus.open;
    _rating = null;
    _ratingComment = null;
    _isRatingSubmitted = false;
    _showRatingPrompt = false;
    _isAgentTyping = false;
    _replyingTo = null;
    _isChatVisible = false;
    notifyListeners();
  }

  /// Forces creation of a brand new conversation on the backend
  Future<void> startNewConversation() async {
    if (!_isInitialized) {
      await initialize();
    }

    _clearError();
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _useCases.startNewConversation();
      if (result.hasException) {
        _setError(
          result.exception,
          fallbackMessage: 'Unable to start a new conversation right now.',
        );
        return;
      }

      final roomData = result.data!['startNewConversation'];
      final newRoom = TalqRoom.fromJson(roomData);

      _rooms.insert(0, newRoom);
      _sortRooms();
      _syncVisibleRoomCount();
      _roomId = newRoom.id;
      _messagesRoomId = newRoom.id;
      _roomStatus = newRoom.status;
      _messages = [];
      _hasMoreMessages = false;
      _isRoomLoading = false;
      _showRatingPrompt = false;
      _isRatingSubmitted = false;

      if (newRoom.lastMessage != null) {
        _messages.add(newRoom.lastMessage!);
      }
      _cacheCurrentRoomMessages();

      _startTypingSubscription();
      _startMessageSubscription();

      _clearError();
      notifyListeners();
    } catch (e) {
      _setError(
        e,
        fallbackMessage: 'Unable to start a new conversation right now.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refreshes the list of visitor rooms
  Future<void> fetchRooms({bool resetVisibleWindow = false}) async {
    if (!_isFetchingMoreRooms) _roomsExhausted = false;
    final result = await _useCases.fetchRooms();
    if (!result.hasException) {
      _clearError(notify: true);
      final List roomsList = result.data?['visitorRooms'] ?? [];
      _rooms = roomsList.map((r) => TalqRoom.fromJson(r)).toList();
      _sortRooms();
      _syncVisibleRoomCount(reset: resetVisibleWindow);
      unawaited(
        TalqCache.saveRooms(
          roomsList
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
        ),
      );
      notifyListeners();
      return;
    }

    _setError(
      result.exception,
      fallbackMessage: 'Unable to load conversations right now.',
    );
  }

  /// Fetches the server-driven SDK config (timers, upload limits, feature
  /// flags, min SDK version, etc). Forward-compatible: if the backend
  /// hasn't shipped the `widgetConfig` resolver yet, this fails silently
  /// and the SDK keeps using [TalqWidgetConfig.defaults].
  Future<void> fetchWidgetConfig() async {
    try {
      final result = await _useCases.fetchWidgetConfig();
      if (result.hasException) return;
      final raw = result.data?['widgetConfig'];
      if (raw is! Map) return;
      final json = Map<String, dynamic>.from(raw);
      _widgetConfig = TalqWidgetConfig.fromJson(json);
      unawaited(TalqCache.saveWidgetConfig(json));
      if (_disposed) return;
      notifyListeners();
    } catch (e) {
      // Server hasn't implemented widgetConfig yet, network glitch, etc.
      // Defaults stay in effect; not an error worth surfacing.
      debugPrint('[TalqController] widgetConfig fetch skipped: $e');
    }
  }

  /// Completely resets the current session and visitor identity
  Future<void> resetSession() async {
    await AuthManager.resetSession();
    await TalqCache.clear();
    _isInitialized = false;
    _visitor = null;
    _roomId = null;
    _messagesRoomId = null;
    _rooms = [];
    _visibleRoomCount = 0;
    _isFetchingMoreRooms = false;
    _messages = [];
    _messageCache.clear();
    _isRoomLoading = false;
    _isLoading = false;
    _messageSubscription?.cancel();
    _messageUpdatedSubscription?.cancel();
    _typingSubscription?.cancel();
    _roomSubscription?.cancel();
    _workspaceSubscription?.cancel();
    notifyListeners();
  }

  Future<void> fetchMoreRooms() async {
    if (_isFetchingMoreRooms) return;

    if (hasMoreRoomsToDisplay) {
      _visibleRoomCount = math.min(
        _visibleRoomCount + _roomListChunkSize,
        _rooms.length,
      );
      notifyListeners();
      return;
    }

    if (_roomsExhausted) return;

    _isFetchingMoreRooms = true;
    notifyListeners();

    final previousRoomCount = _rooms.length;
    try {
      await fetchRooms();
      if (_rooms.length > previousRoomCount && hasMoreRoomsToDisplay) {
        _visibleRoomCount = math.min(
          _visibleRoomCount + _roomListChunkSize,
          _rooms.length,
        );
      } else {
        _roomsExhausted = true;
      }
    } finally {
      _isFetchingMoreRooms = false;
      notifyListeners();
    }
  }

  /// Fetches conversation history for a specific room or the active one
  Future<void> fetchMessages({String? roomId, bool isLoadMore = false}) async {
    final targetRoomId = roomId ?? _roomId;
    if (targetRoomId == null) return;

    // Switch whenever the thread on screen belongs to a different room than
    // the one requested. Compared against _messagesRoomId, not _roomId: the
    // latter is reassigned by initialize() without clearing _messages, so a
    // fetch for room A could merge into room B's list.
    final isSwitchingRoom = !isLoadMore && targetRoomId != _messagesRoomId;

    if (isLoadMore) {
      if (_isFetchingMore || !_hasMoreMessages) return;
      _isFetchingMore = true;
      notifyListeners();
    } else {
      _fetchVersion++;
      if (isSwitchingRoom) {
        _roomId = targetRoomId;
        _messagesRoomId = targetRoomId;
        _hasMoreMessages = false;
        // Seed status/rating from the room we already hold in the list, so the
        // closed + rating banner renders the moment the conversation opens.
        // Previously this blanked to `open` and only corrected once the
        // network round-trip landed, so the banner appeared late (or not at
        // all on a slow connection). _fetchRoomStatus() still confirms it.
        TalqRoom? known;
        for (final r in _rooms) {
          if (r.id == targetRoomId) {
            known = r;
            break;
          }
        }
        _roomStatus = known?.status ?? RoomStatus.open;
        _rating = known?.rating;
        _ratingComment = known?.ratingComment;
        _isRatingSubmitted = known?.rating != null;
        _showRatingPrompt = false;
        _replyingTo = null;

        _isAgentTyping = false;
        _typingTimer?.cancel();
        _startTypingSubscription();

        final cachedMessages = _messageCache[targetRoomId];
        if (cachedMessages != null) {
          _messages = List<TalqMessage>.from(cachedMessages);
          _isRoomLoading = false;
        } else {
          _messages = [];
          _isRoomLoading = true;
        }
        notifyListeners();
      } else if (_messages.isEmpty) {
        final cachedMessages = _messageCache[targetRoomId];
        if (cachedMessages != null) {
          _messages = List<TalqMessage>.from(cachedMessages);
          _isRoomLoading = false;
        } else {
          _isRoomLoading = true;
        }
        notifyListeners();
      } else {
        _isRoomLoading = false;
      }
    }

    String? afterCursor;
    if (isLoadMore && _messages.isNotEmpty) {
      afterCursor = _messages.last.id;
    }

    if (!isLoadMore) {
      markAsDelivered(targetRoomId);
    }

    final result = await _useCases.fetchRoomMessages(
      roomId: targetRoomId,
      afterCursor: afterCursor,
    );

    // Discard any response that is not for the room currently open. This must
    // be keyed on the room ALONE: several call sites reassign _roomId without
    // bumping _fetchVersion, so a version check (or an AND of the two) let a
    // late response for a previous room merge into the open thread — which is
    // how messages from one chat started appearing inside another.
    // Room-only is also what fixes the opposite bug: two racing fetches for the
    // SAME room may both apply, instead of both being thrown away and leaving
    // the thread empty.
    if (!isLoadMore && targetRoomId != _roomId) {
      return;
    }

    _isFetchingMore = false;

    if (result.hasException) {
      _isRoomLoading = false;
      _setError(
        result.exception,
        fallbackMessage: isLoadMore
            ? 'Unable to load older messages.'
            : 'Unable to load messages right now.',
      );
      notifyListeners();
      return;
    }

    final roomData = result.data?['room'];
    if (roomData == null) {
      _isRoomLoading = false;
      _setError(
        null,
        fallbackMessage: 'This conversation is unavailable right now.',
      );
      notifyListeners();
      return;
    }

    _clearError();
    final messagesData = roomData['messages'];
    final List edges = messagesData?['edges'] ?? [];
    final pageInfo = messagesData?['pageInfo'];
    final List eventList = roomData['events'] ?? [];

    List<TalqMessage> newMessages = [];

    try {
      newMessages = edges.map((e) => TalqMessage.fromJson(e['node'])).toList();
    } catch (e) {
      _setError(e, fallbackMessage: 'Unable to parse messages right now.');
    }

    _hasMoreMessages = pageInfo?['hasNextPage'] ?? false;
    debugPrint(
      '[TalqController] fetchMessages: isLoadMore=$isLoadMore, newMessages=${newMessages.length}, hasMoreMessages=$_hasMoreMessages, totalMessages=${_messages.length}, afterCursor=$afterCursor',
    );

    _messages = _mergeMessagesNewestFirst(
      localMessages: _messages,
      serverMessages: newMessages,
      roomId: targetRoomId,
    );

    if (!isLoadMore) {
      final assignedEvents = eventList
          .where((e) => e['type'] == 'ROOM_ASSIGNED')
          .toList();
      for (int i = 1; i < assignedEvents.length; i++) {
        // event injection skipped for pagination stability
      }

      if (roomId != null) {
        await _fetchRoomStatus();
        _startTypingSubscription();
      }

      _startMessageSubscription();
    }

    _cacheMessagesForRoom(targetRoomId, _messages);
    _isRoomLoading = false;
    notifyListeners();

    if (_isChatVisible && !isLoadMore) {
      markAsRead();
    }
  }

  /// Sends a new message
  Future<void> sendMessage(
    String content, {
    ContentType contentType = ContentType.text,
    String? fileUrl,
    String? fileName,
    String? tempId,
  }) async {
    if (content.trim().isEmpty && fileUrl == null) return;

    final effectiveTempId =
        tempId ?? 'temp-${DateTime.now().millisecondsSinceEpoch}';
    final replyToId = _replyingTo?.id;
    final optimisticCreatedAt = DateTime.now();

    if (tempId == null) {
      final optMsg = TalqMessage(
        id: effectiveTempId,
        content: content,
        senderType: SenderType.visitor,
        contentType: contentType,
        fileUrl: fileUrl,
        fileName: fileName,
        createdAt: optimisticCreatedAt,
        replyTo: _replyingTo,
      );

      _messages.insert(0, optMsg);
      _replyingTo = null;
      _cacheCurrentRoomMessages();
      notifyListeners();
    }

    if (_roomId == null) {
      try {
        final createResult = await _useCases.startNewConversation();
        if (createResult.hasException) {
          _setError(
            createResult.exception,
            fallbackMessage: 'Unable to start a new conversation right now.',
          );
          if (tempId == null) {
            _messages.removeWhere((m) => m.id == effectiveTempId);
            notifyListeners();
          }
          return;
        }

        final roomData = createResult.data!['startNewConversation'];
        final newRoom = TalqRoom.fromJson(roomData);

        _rooms.insert(0, newRoom);
        _sortRooms();
        _roomId = newRoom.id;
        _messagesRoomId = newRoom.id;
        _roomStatus = newRoom.status;
        _showRatingPrompt = false;
        _isRatingSubmitted = false;
        _startTypingSubscription();
        _startMessageSubscription();
      } catch (e) {
        _setError(
          e,
          fallbackMessage: 'Unable to start a new conversation right now.',
        );
        if (tempId == null) {
          _messages.removeWhere((m) => m.id == effectiveTempId);
          notifyListeners();
        }
        return;
      }
    }

    if (_roomId != null) {
      final roomIdx = _rooms.indexWhere((r) => r.id == _roomId);
      if (roomIdx != -1) {
        final room = _rooms[roomIdx];
        final previewMsg = tempId != null
            ? _messages.firstWhere((m) => m.id == tempId)
            : TalqMessage(
                id: effectiveTempId,
                content: content,
                senderType: SenderType.visitor,
                contentType: contentType,
                fileUrl: fileUrl,
                fileName: fileName,
                createdAt: optimisticCreatedAt,
                replyTo: null,
              );

        _rooms[roomIdx] = TalqRoom(
          id: room.id,
          status: room.status,
          unreadCount: room.unreadCount,
          visitorUnreadCount: room.visitorUnreadCount,
          lastMessageAt: previewMsg.createdAt,
          lastMessage: previewMsg,
          createdAt: room.createdAt,
          rating: room.rating,
          ratingComment: room.ratingComment,
          assigneeName: room.assigneeName,
          assigneeAvatarUrl: room.assigneeAvatarUrl,
        );
        _sortRooms();
      }
    }
    _cacheCurrentRoomMessages();
    notifyListeners();

    final result = await _useCases.sendVisitorMessage(
      roomId: _roomId,
      content: content,
      contentType: contentType,
      fileUrl: fileUrl,
      fileName: fileName,
      replyToId: replyToId,
    );

    if (result.hasException) {
      debugPrint('[TalqController] sendMessage failed: ${result.exception}');
      _setError(
        result.exception,
        fallbackMessage: 'Unable to send message right now.',
      );

      if (tempId != null) {
        _markMessageUploadFailed(effectiveTempId);
      } else {
        _messages.removeWhere((m) => m.id == effectiveTempId);
      }
      _cacheCurrentRoomMessages();
      notifyListeners();
      return;
    }

    final index = _messages.indexWhere((m) => m.id == effectiveTempId);
    if (index != -1) {
      final oldMsg = _messages[index];
      final data = result.data!['sendVisitorMessage'];
      final realMessage = TalqMessage.fromJson(data);

      final persistedMessage = TalqMessage(
        id: realMessage.id,
        roomId: realMessage.roomId,
        content: realMessage.content,
        senderType: realMessage.senderType,
        senderName: realMessage.senderName,
        senderAvatarUrl: realMessage.senderAvatarUrl,
        contentType: realMessage.contentType,
        fileUrl: realMessage.fileUrl,
        fileName: realMessage.fileName,
        createdAt: realMessage.createdAt,
        isRead: realMessage.isRead || oldMsg.isRead,
        isDelivered: realMessage.isDelivered || oldMsg.isDelivered,
        replyTo: realMessage.replyTo,
        reactions: realMessage.reactions,
      );

      _messages[index] = persistedMessage;
      _messages = _mergeMessagesNewestFirst(
        localMessages: _messages,
        serverMessages: const [],
      );

      if (_roomId == null) {
        _roomId = data['room']['id'];
        _messagesRoomId = _roomId;
        _startTypingSubscription();
      }

      final roomIdx = _rooms.indexWhere((r) => r.id == _roomId);
      if (roomIdx != -1) {
        final room = _rooms[roomIdx];
        _rooms[roomIdx] = TalqRoom(
          id: room.id,
          status: room.status,
          unreadCount: room.unreadCount,
          visitorUnreadCount: room.visitorUnreadCount,
          lastMessageAt: realMessage.createdAt,
          lastMessage: realMessage,
          createdAt: room.createdAt,
          rating: room.rating,
          ratingComment: room.ratingComment,
          assigneeName: room.assigneeName,
          assigneeAvatarUrl: room.assigneeAvatarUrl,
        );
        _sortRooms();
      }

      _cacheCurrentRoomMessages();
      notifyListeners();
    }

    _clearError(notify: true);
  }

  /// Picks and sends a file (image or PDF)
  Future<void> sendFile(String filePath, {String? caption}) async {
    final rawFileName = path.basename(filePath);
    final extension = path.extension(filePath).toLowerCase();

    ContentType contentType = ContentType.text;
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(extension)) {
      contentType = ContentType.image;
    } else if (extension == '.pdf') {
      contentType = ContentType.pdf;
    }

    String fileName = rawFileName;
    final lower = rawFileName.toLowerCase();
    final isPickerJunk =
        lower.startsWith('image_picker_') ||
        lower.startsWith('scaled_') ||
        lower.startsWith('tmp_') ||
        lower.startsWith('temp_');
    if (contentType == ContentType.image && isPickerJunk) {
      final now = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      final stamp =
          '${now.year}${two(now.month)}${two(now.day)}_'
          '${two(now.hour)}${two(now.minute)}${two(now.second)}';
      final ext = extension.isEmpty ? '.jpg' : extension;
      fileName = 'IMG_$stamp$ext';
    }

    final tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
    final trimmedCaption = caption?.trim() ?? '';
    final messageContent = trimmedCaption.isNotEmpty
        ? trimmedCaption
        : (contentType == ContentType.image ? ' ' : fileName);
    final optMsg = TalqMessage(
      id: tempId,
      content: messageContent,
      senderType: SenderType.visitor,
      contentType: contentType,
      localFilePath: filePath,
      isUploading: true,
      fileName: fileName,
      createdAt: DateTime.now(),
      replyTo: _replyingTo,
    );

    _messages.insert(0, optMsg);
    _replyingTo = null;
    _cacheCurrentRoomMessages();
    notifyListeners();

    try {
      final fileUrl = await _useCases.uploadFile(
        filePath,
        overrideFileName: fileName,
      );

      await sendMessage(
        messageContent,
        contentType: contentType,
        fileUrl: fileUrl,
        fileName: fileName,
        tempId: tempId,
      );
    } catch (e) {
      debugPrint('[TalqController] sendFile failed: $e');
      _setError(e, fallbackMessage: 'Unable to upload file right now.');
      _markMessageUploadFailed(tempId);
      notifyListeners();
    }
  }

  void _markMessageUploadFailed(String tempId) {
    final index = _messages.indexWhere((m) => m.id == tempId);
    if (index == -1) return;

    final failedMessage = _messages[index];
    _messages[index] = failedMessage.copyWith(isUploading: false);
    _cacheCurrentRoomMessages();
  }

  /// Notifies the backend that the visitor is typing
  Future<void> sendTyping(String roomId) async {
    await _useCases.sendTyping(roomId);
  }

  /// Updates the visitor's current viewing page
  Future<void> updatePage(String page) async {
    if (_roomId == null) return;

    final result = await _useCases.updateVisitorPage(
      roomId: _roomId!,
      page: page,
    );
    if (result.hasException) {
      _setError(
        result.exception,
        fallbackMessage: 'Unable to update page status right now.',
      );
      return;
    }
    _clearError();

    if (_visitor != null) {
      _visitor = _visitor!.copyWith(currentPage: page);
      notifyListeners();
    }
  }

  Future<void> markAsRead() async {
    if (_roomId == null) return;
    if (!_isChatVisible || _lifecycleState != AppLifecycleState.resumed) return;

    final roomIndex = _rooms.indexWhere((r) => r.id == _roomId);
    if (roomIndex != -1) {
      final room = _rooms[roomIndex];
      if (room.visitorUnreadCount > 0) {
        _rooms[roomIndex] = TalqRoom(
          id: room.id,
          status: room.status,
          unreadCount: room.unreadCount,
          visitorUnreadCount: 0,
          lastMessageAt: room.lastMessageAt,
          lastMessage: room.lastMessage,
          createdAt: room.createdAt,
          rating: room.rating,
          ratingComment: room.ratingComment,
          assigneeName: room.assigneeName,
          assigneeAvatarUrl: room.assigneeAvatarUrl,
        );
        _sortRooms();
        notifyListeners();
      }
    }

    final result = await _useCases.markMessagesAsRead(_roomId!);
    if (result.hasException) {
      _setError(
        result.exception,
        fallbackMessage: 'Unable to mark messages as read right now.',
      );
    }
  }

  Future<void> markAsDelivered(String roomID) async {
    final result = await _useCases.markMessagesAsDelivered(roomID);
    if (result.hasException) {
      _setError(
        result.exception,
        fallbackMessage: 'Unable to update delivery status right now.',
      );
    }
  }

  void _startMessageSubscription() {
    _messageSubscription?.cancel();

    _messageSubscription = _useCases.subscribeVisitorNewMessage().listen(
      (result) async {
        if (result.data != null) {
          final newMessage = TalqMessage.fromJson(
            result.data!['visitorNewMessage'],
          );

          final roomIndex = _rooms.indexWhere((r) => r.id == newMessage.roomId);
          if (roomIndex != -1) {
            final room = _rooms[roomIndex];
            _rooms[roomIndex] = TalqRoom(
              id: room.id,
              status: room.status,
              unreadCount: room.unreadCount,
              visitorUnreadCount:
                  (newMessage.senderType != SenderType.visitor &&
                      newMessage.roomId != _roomId)
                  ? room.visitorUnreadCount + 1
                  : room.visitorUnreadCount,
              lastMessageAt: newMessage.createdAt,
              lastMessage: newMessage,
              createdAt: room.createdAt,
              rating: room.rating,
              ratingComment: room.ratingComment,
              assigneeName: room.assigneeName,
              assigneeAvatarUrl: room.assigneeAvatarUrl,
            );
            _sortRooms();
            notifyListeners();
          } else {
            await fetchRooms();
          }

          if (newMessage.senderType != SenderType.visitor && !_isChatVisible) {
            _showInAppNotification(newMessage);
          }

          if (newMessage.roomId == _roomId && _messagesRoomId == _roomId) {
            final existingIdx = _messages.indexWhere((m) {
              return m.id == newMessage.id ||
                  (m.id.startsWith('temp-') &&
                      m.content == newMessage.content &&
                      m.senderType == newMessage.senderType);
            });

            if (existingIdx != -1) {
              final oldMsg = _messages[existingIdx];
              final persistedMessage = TalqMessage(
                id: newMessage.id,
                roomId: newMessage.roomId,
                content: newMessage.content,
                senderType: newMessage.senderType,
                senderName: newMessage.senderName,
                senderAvatarUrl: newMessage.senderAvatarUrl,
                contentType: newMessage.contentType,
                fileUrl: newMessage.fileUrl,
                fileName: newMessage.fileName,
                createdAt: newMessage.createdAt,
                isRead: newMessage.isRead || oldMsg.isRead,
                isDelivered: newMessage.isDelivered || oldMsg.isDelivered,
                replyTo: newMessage.replyTo,
                reactions: newMessage.reactions,
              );
              _messages[existingIdx] = persistedMessage;
            } else {
              _messages.insert(0, newMessage);

              if (newMessage.senderType != SenderType.visitor) {
                markAsDelivered(_roomId!);
                if (_isChatVisible) {
                  markAsRead();
                }
              }
            }
            _cacheCurrentRoomMessages();
            notifyListeners();
          } else {
            // Keep cached history for inactive rooms in sync so reopening
            // the chat shows the latest message without waiting for a refetch.
            final cached = _messageCache[newMessage.roomId];
            if (cached != null) {
              final alreadyCached = cached.any((m) => m.id == newMessage.id);
              if (!alreadyCached) {
                cached.insert(0, newMessage);
              }
            }
          }
        }
      },
      onError: (error) {
        debugPrint('[TalqController] Message Subscription Error: $error');
        _setError(
          error,
          fallbackMessage: 'Live updates interrupted. Pull to refresh.',
        );
        Future.delayed(const Duration(seconds: 5), () {
          if (!_disposed) _startMessageSubscription();
        });
      },
    );

    _startRoomSubscription();
    _startMessageUpdatedSubscription();
  }

  void _startMessageUpdatedSubscription() {
    _messageUpdatedSubscription?.cancel();
    _messageUpdatedSubscription = _useCases
        .subscribeVisitorMessageUpdated()
        .listen(
          (result) {
            if (result.data == null) return;
            final raw = result.data!['visitorMessageUpdated'];
            if (raw == null) return;
            final updated = TalqMessage.fromJson(raw);

            if (updated.roomId == _roomId && _messagesRoomId == _roomId) {
              final idx = _messages.indexWhere((m) => m.id == updated.id);
              if (idx != -1) {
                final old = _messages[idx];
                _messages[idx] = TalqMessage(
                  id: updated.id,
                  roomId: updated.roomId ?? old.roomId,
                  content: updated.content,
                  senderType: updated.senderType,
                  senderName: updated.senderName ?? old.senderName,
                  senderAvatarUrl:
                      updated.senderAvatarUrl ?? old.senderAvatarUrl,
                  contentType: updated.contentType,
                  fileUrl: updated.fileUrl,
                  fileName: updated.fileName,
                  createdAt: old.createdAt,
                  isRead: updated.isRead || old.isRead,
                  isDelivered: updated.isDelivered || old.isDelivered,
                  replyTo: updated.replyTo ?? old.replyTo,
                  reactions: updated.reactions,
                  deletedAt: updated.deletedAt,
                  deletedBy: updated.deletedBy,
                  editedAt: updated.editedAt,
                );
                _cacheCurrentRoomMessages();
                notifyListeners();
              }
            }

            final roomIdx = _rooms.indexWhere((r) => r.id == updated.roomId);
            if (roomIdx != -1) {
              final room = _rooms[roomIdx];
              if (room.lastMessage?.id == updated.id) {
                _rooms[roomIdx] = TalqRoom(
                  id: room.id,
                  status: room.status,
                  unreadCount: room.unreadCount,
                  visitorUnreadCount: room.visitorUnreadCount,
                  lastMessageAt: room.lastMessageAt,
                  lastMessage: updated,
                  createdAt: room.createdAt,
                  rating: room.rating,
                  ratingComment: room.ratingComment,
                  assigneeName: room.assigneeName,
                  assigneeAvatarUrl: room.assigneeAvatarUrl,
                );
                notifyListeners();
              }
            }
          },
          onError: (error) {
            debugPrint(
              '[TalqController] Message Updated Subscription Error: $error',
            );
            Future.delayed(const Duration(seconds: 5), () {
              if (!_disposed) _startMessageUpdatedSubscription();
            });
          },
        );
  }

  void _startRoomSubscription() {
    _roomSubscription?.cancel();

    _roomSubscription = _useCases.subscribeVisitorRoomUpdated().listen(
      (result) {
        if (result.data != null) {
          final roomData = result.data!['visitorRoomUpdated'];
          final roomId = roomData['id'];

          final roomIndex = _rooms.indexWhere((r) => r.id == roomId);
          final newRoom = TalqRoom.fromJson(roomData);

          if (roomIndex != -1) {
            final existingRoom = _rooms[roomIndex];
            // Only update last-message info if it's actually newer; prevents stale ROOM_UPDATED pulses overwriting fresh NEW_MESSAGE pulses.
            bool shouldUpdateLastMsg = true;
            if (existingRoom.lastMessageAt != null &&
                newRoom.lastMessageAt != null) {
              shouldUpdateLastMsg = !newRoom.lastMessageAt!.isBefore(
                existingRoom.lastMessageAt!,
              );
            }

            _rooms[roomIndex] = newRoom.copyWith(
              lastMessageAt: shouldUpdateLastMsg
                  ? newRoom.lastMessageAt
                  : existingRoom.lastMessageAt,
              lastMessage: shouldUpdateLastMsg
                  ? newRoom.lastMessage
                  : existingRoom.lastMessage,
            );
          } else {
            _rooms.add(newRoom);
          }
          _sortRooms();
          notifyListeners();

          if (roomId == _roomId) {
            final newStatus = RoomStatus.fromString(roomData['status']);

            if (newStatus == RoomStatus.resolved &&
                _roomStatus != RoomStatus.resolved) {
              _showRatingPrompt = true;
            }

            final unreadN = newRoom.unreadCount;
            final allRead = unreadN == 0;
            final lastMsg = roomData['lastMessage'];

            bool lastMsgRead = false;
            bool lastMsgDelivered = false;
            if (lastMsg != null &&
                SenderType.fromString(lastMsg['senderType']) ==
                    SenderType.visitor) {
              lastMsgRead = lastMsg['read'] ?? false;
              lastMsgDelivered = lastMsg['delivered'] ?? false;
            }

            final confirmedVisitorMsgs = _messages
                .where(
                  (m) =>
                      m.senderType == SenderType.visitor &&
                      !m.id.startsWith('temp-'),
                )
                .toList();

            final unreadIds = confirmedVisitorMsgs.length >= unreadN
                ? confirmedVisitorMsgs.take(unreadN).map((m) => m.id).toSet()
                : confirmedVisitorMsgs.map((m) => m.id).toSet();

            bool changed = false;
            final updatedMessages = _messages.map((m) {
              if (m.senderType == SenderType.visitor) {
                bool shouldMarkRead = false;
                bool shouldMarkDelivered = false;

                if (allRead) {
                  shouldMarkRead = true;
                  shouldMarkDelivered = true;
                } else {
                  if (!m.id.startsWith('temp-') && !unreadIds.contains(m.id)) {
                    shouldMarkRead = true;
                    shouldMarkDelivered = true;
                  }

                  if (m.id == lastMsg?['id']) {
                    if (lastMsgRead) shouldMarkRead = true;
                    if (lastMsgDelivered) shouldMarkDelivered = true;
                  }
                }

                if ((shouldMarkRead && !m.isRead) ||
                    (shouldMarkDelivered && !m.isDelivered)) {
                  changed = true;
                  return TalqMessage(
                    id: m.id,
                    roomId: m.roomId,
                    content: m.content,
                    senderType: m.senderType,
                    senderName: m.senderName,
                    senderAvatarUrl: m.senderAvatarUrl,
                    contentType: m.contentType,
                    fileUrl: m.fileUrl,
                    fileName: m.fileName,
                    createdAt: m.createdAt,
                    isRead: m.isRead || shouldMarkRead,
                    isDelivered: m.isDelivered || shouldMarkDelivered,
                    replyTo: m.replyTo,
                    reactions: m.reactions,
                  );
                }
              }
              return m;
            }).toList();

            if (changed) {
              _messages = updatedMessages;
            }

            _roomStatus = newStatus;
            _rating = roomData['rating'];
            _ratingComment = roomData['ratingComment'];
            _isRatingSubmitted = roomData['rating'] != null;
            _cacheCurrentRoomMessages();
            notifyListeners();
          }
        }
      },
      onError: (error) {
        debugPrint('[TalqController] Room Subscription Error: $error');
        Future.delayed(const Duration(seconds: 5), () {
          if (!_disposed) _startRoomSubscription();
        });
      },
    );
  }

  void _startWorkspaceSubscription() {
    _workspaceSubscription?.cancel();

    _workspaceSubscription = _useCases.subscribeVisitorWorkspaceUpdated().listen(
      (result) {
        if (result.data != null) {
          final wsData = result.data!['visitorWorkspaceUpdated'];
          final newWorkspace = TalqWorkspace.fromJson(wsData);

          final avatars = _workspace?.agentAvatars ?? [];
          _workspace = newWorkspace.copyWith(agentAvatars: avatars);

          if (_workspace!.primaryColor.isNotEmpty) {
            try {
              final c = TalqTheme.fromHex(_workspace!.primaryColor);
              _theme = _theme.copyWith(
                primaryColor: c,
                userBubbleColor: c,
                userTextColor: _onPrimary(c),
                resolvedTextColor: TalqTheme.resolvedAccentFor(c),
                resolvedBackgroundColor: TalqTheme.resolvedSurfaceFor(c),
              );
              AuthManager.savePrimaryColor(_workspace!.primaryColor);
              debugPrint(
                '[TalqController] Theme updated: primaryColor=${_workspace!.primaryColor}',
              );
            } catch (_) {
              // invalid hex, keep current theme
            }
          }

          notifyListeners();
        }
      },
      onError: (error) {
        debugPrint('[TalqController] Workspace Subscription Error: $error');
        Future.delayed(const Duration(seconds: 5), () {
          if (!_disposed) _startWorkspaceSubscription();
        });
      },
    );
  }

  void _startTypingSubscription() {
    if (_roomId == null) return;
    _typingSubscription?.cancel();

    _typingSubscription = _useCases
        .subscribeTyping(_roomId!)
        .listen(
          (result) {
            if (result.data != null) {
              final typingUserId = result.data!['typing'];

              if (typingUserId != _visitor?.id) {
                _isAgentTyping = true;
                notifyListeners();

                _typingTimer?.cancel();
                _typingTimer = Timer(const Duration(seconds: 3), () {
                  _isAgentTyping = false;
                  notifyListeners();
                });
              }
            }
          },
          onError: (error) {
            debugPrint('[TalqController] Typing Subscription Error: $error');
            Future.delayed(const Duration(seconds: 5), () {
              if (!_disposed) _startTypingSubscription();
            });
          },
        );
  }

  /// Hides the rating prompt without submitting. The visitor can reopen
  /// it from the resolved banner — this is purely a UX convenience so the
  /// rating sheet doesn't block reading the conversation history.
  void dismissRatingPrompt() {
    if (!_showRatingPrompt) return;
    _showRatingPrompt = false;
    notifyListeners();
  }

  /// Re-opens the rating prompt (e.g. when the visitor taps "Rate" in the
  /// resolved banner after dismissing it earlier). No-op if the room is
  /// already rated.
  void requestRatingPrompt() {
    if (_isRatingSubmitted) return;
    if (_roomStatus != RoomStatus.resolved) return;
    if (_showRatingPrompt) return;
    _showRatingPrompt = true;
    notifyListeners();
  }

  /// Submits a rating for the current room
  Future<void> rateRoom(int rating, {String? comment}) async {
    if (_roomId == null) return;
    final result = await _useCases.rateRoom(
      roomId: _roomId!,
      rating: rating,
      comment: comment,
    );

    if (!result.hasException) {
      _clearError(notify: true);
      _showRatingPrompt = false;
      _isRatingSubmitted = true;
      _rating = rating;
      _ratingComment = comment;
      notifyListeners();
    } else {
      _setError(
        result.exception,
        fallbackMessage: 'Unable to submit rating right now.',
      );
    }
  }

  /// Submits feedback for an FAQ article
  Future<bool> voteFAQ(String faqId, bool helpful) async {
    final result = await _useCases.voteFaq(faqId: faqId, helpful: helpful);

    if (result.hasException) {
      _setError(
        result.exception,
        fallbackMessage: 'Unable to submit feedback right now.',
      );
      return false;
    }
    _clearError(notify: true);
    return !result.hasException;
  }

  Future<void> _fetchRoomStatus() async {
    if (_roomId == null) return;
    final capturedVersion = _fetchVersion;
    final result = await _useCases.fetchRoomStatus(_roomId!);

    if (capturedVersion != _fetchVersion) {
      return;
    }

    if (!result.hasException && result.data != null) {
      _clearError();
      final roomData = result.data!['room'];
      _roomStatus = RoomStatus.fromString(roomData['status']);
      _rating = roomData['rating'];
      _ratingComment = roomData['ratingComment'];
      _isRatingSubmitted = roomData['rating'] != null;
      if (_roomStatus == RoomStatus.resolved && _rating == null) {
        _showRatingPrompt = true;
      }
      notifyListeners();
      return;
    }

    _setError(
      result.exception,
      fallbackMessage: 'Unable to refresh room status right now.',
    );
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _messageSubscription?.cancel();
    _messageUpdatedSubscription?.cancel();
    _typingSubscription?.cancel();
    _roomSubscription?.cancel();
    _workspaceSubscription?.cancel();
    _typingTimer?.cancel();
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> addReaction(String messageId, String emoji) async {
    final result = await _useCases.addReaction(
      messageId: messageId,
      emoji: emoji,
    );

    if (!result.hasException) {
      _clearError();
      final updatedData = result.data!['addReaction'];
      final messageIndex = _messages.indexWhere((m) => m.id == messageId);
      if (messageIndex != -1) {
        final oldMsg = _messages[messageIndex];
        _messages[messageIndex] = oldMsg.copyWith(
          reactions: Map<String, dynamic>.from(
            updatedData['reactions'] is String
                ? json.decode(updatedData['reactions'])
                : updatedData['reactions'],
          ),
        );
        _cacheCurrentRoomMessages();
        notifyListeners();
      }
    } else {
      _setError(
        result.exception,
        fallbackMessage: 'Unable to add reaction right now.',
      );
    }
  }

  Future<void> removeReaction(String messageId, String emoji) async {
    final result = await _useCases.removeReaction(
      messageId: messageId,
      emoji: emoji,
    );

    if (!result.hasException) {
      _clearError();
      final updatedData = result.data!['removeReaction'];
      final messageIndex = _messages.indexWhere((m) => m.id == messageId);
      if (messageIndex != -1) {
        final oldMsg = _messages[messageIndex];
        _messages[messageIndex] = oldMsg.copyWith(
          reactions: Map<String, dynamic>.from(
            updatedData['reactions'] is String
                ? json.decode(updatedData['reactions'])
                : updatedData['reactions'],
          ),
        );
        _cacheCurrentRoomMessages();
        notifyListeners();
      }
    } else {
      _setError(
        result.exception,
        fallbackMessage: 'Unable to remove reaction right now.',
      );
    }
  }

  Future<void> fetchFaqs({bool reload = false, String? query}) async {
    if (_isFaqLoading) return;

    if (reload || (query != null && query != _faqSearchQuery)) {
      _paginatedFaqs = [];
      _faqEndCursor = null;
      _faqHasNextPage = false;
      _faqSearchQuery = query ?? _faqSearchQuery;
    }

    if (!reload && _paginatedFaqs.isNotEmpty && !_faqHasNextPage) return;

    _isFaqLoading = true;
    notifyListeners();

    try {
      final result = await _useCases.fetchVisitorFaqs(
        query: _faqSearchQuery.isEmpty ? null : _faqSearchQuery,
        first: 20,
        afterCursor: _faqEndCursor,
      );

      if (result.hasException) {
        _setError(
          result.exception,
          fallbackMessage: 'Unable to load help articles right now.',
        );
        return;
      }

      final connection = FAQConnection.fromJson(result.data!['visitorFaqs']);
      _paginatedFaqs.addAll(connection.faqs);
      _faqHasNextPage = connection.hasNextPage;
      _faqEndCursor = connection.endCursor;

      if (_faqSearchQuery.isEmpty && reload) {
        _faqs = List.from(connection.faqs);
      }
      _clearError();
    } catch (e) {
      _setError(e, fallbackMessage: 'Unable to load help articles right now.');
    } finally {
      _isFaqLoading = false;
      notifyListeners();
    }
  }

  void _sortRooms() {
    _rooms.sort((a, b) {
      final aTime = a.lastMessageAt ?? a.createdAt;
      final bTime = b.lastMessageAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
    _syncVisibleRoomCount();
  }
}
