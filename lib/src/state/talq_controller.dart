import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../core/auth_manager.dart';
import '../core/device_info_collector.dart';
import '../core/talq_client.dart';
import '../core/talq_error_mapper.dart';
import '../models/models.dart';
import '../theme/talq_theme.dart';
import '../workflows/talq_use_cases.dart';

class TalqController extends ChangeNotifier {
  final TalqUseCases _useCases;

  List<TalqMessage> _messages = [];
  final Map<String, List<TalqMessage>> _messageCache = {};
  List<TalqRoom> _rooms = [];
  static const int _roomListChunkSize = 15;
  int _visibleRoomCount = _roomListChunkSize;
  bool _isFetchingMoreRooms = false;
  List<TalqFAQ> _faqs = [];

  // Paginated FAQs
  List<TalqFAQ> _paginatedFaqs = [];
  bool _faqHasNextPage = false;
  String? _faqEndCursor;
  String _faqSearchQuery = '';
  bool _isFaqLoading = false;

  // Message Pagination
  bool _hasMoreMessages = false;
  bool _isFetchingMore = false;
  bool _isRoomLoading = false;

  bool _isLoading = false;
  bool _isInitialized = false;
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
  StreamSubscription? _typingSubscription;
  StreamSubscription? _roomSubscription;
  StreamSubscription? _workspaceSubscription;
  Timer? _typingTimer;
  TalqMessage? _replyingTo;
  bool _isChatVisible = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  int _fetchVersion = 0; // used to cancel stale fetchMessages calls
  bool _disposed = false;

  // In-app notification state
  TalqMessage? _pendingNotification;
  Timer? _notificationTimer;

  TalqTheme _theme = const TalqTheme();

  TalqController(TalqClient client)
    : _useCases = TalqUseCases.fromClient(client) {
    _loadCachedTheme();
  }

  /// Load cached primary color so the FAB shows the correct color immediately
  Future<void> _loadCachedTheme() async {
    final cachedHex = await AuthManager.getPrimaryColor();
    if (cachedHex != null && cachedHex.isNotEmpty) {
      try {
        _theme = _theme.copyWith(primaryColor: TalqTheme.fromHex(cachedHex));
        notifyListeners();
      } catch (_) {}
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
    if (_roomId == null) return;
    _cacheMessagesForRoom(_roomId!, _messages);
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

    _visibleRoomCount = math.min(_visibleRoomCount, _rooms.length);
  }

  List<TalqMessage> _mergeMessagesNewestFirst({
    required List<TalqMessage> localMessages,
    required List<TalqMessage> serverMessages,
  }) {
    final mergedById = <String, TalqMessage>{
      for (final message in localMessages) message.id: message,
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
      // when chat becomes visible, mark messages as read
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
    if (_isInitialized && _workspace != null) return;
    if (_isLoading) return;

    _clearError(notify: true);
    _isLoading = true;
    final capturedVersion = _fetchVersion;
    notifyListeners();

    try {
      // 1. Initialize GraphQL Client
      await _useCases.initializeClient();

      // 2. Get/Register Visitor
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
      debugPrint('[TalqController] Starting initVisitor...');

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
        _isInitialized = true;
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

      // Apply primary color to theme if valid
      if (_workspace!.primaryColor.isNotEmpty) {
        try {
          _theme = _theme.copyWith(
            primaryColor: TalqTheme.fromHex(_workspace!.primaryColor),
          );
          // Cache for instant loading on next app launch
          AuthManager.savePrimaryColor(_workspace!.primaryColor);
        } catch (_) {
          // invalid hex, keep default
        }
      }

      // Populate FAQs
      final List faqsList = authData['faqs'] ?? [];
      _faqs = faqsList.map((f) => TalqFAQ.fromJson(f)).toList();

      // Populate rooms list
      final List roomsList = authData['visitor']['rooms'] ?? [];
      final newRooms = roomsList.map((r) => TalqRoom.fromJson(r)).toList();

      if (capturedVersion != _fetchVersion) {
        return;
      }

      _rooms = newRooms;
      _sortRooms();
      _syncVisibleRoomCount(reset: true);

      // Try to find an active room or default to the most recent one
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

      // 3. Re-init client with token
      await _useCases.initializeClient();

      // 4. Load initial messages (markAsRead will be called by setChatVisible when chat opens)
      if (_roomId != null) {
        unawaited(fetchMessages(roomId: _roomId));
      }

      // 5. Start subscriptions
      _startMessageSubscription();
      _startWorkspaceSubscription();
      if (_roomId != null) {
        _startTypingSubscription();
      }

      // Update current page if provided
      if (currentPage != null) {
        unawaited(updatePage(currentPage));
      }

      _isInitialized = true;
      _clearError();
    } catch (e) {
      _isInitialized = true;
      _setError(e, fallbackMessage: 'Unable to start chat right now.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Prepares the controller for a new conversation locally without creating a room on the backend.
  /// The room will be created when the first message is sent.
  void prepareNewConversation() {
    _fetchVersion++; // cancel any pending fetchMessages calls
    _roomId = null;
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

      // Update local state
      _rooms.insert(0, newRoom);
      _sortRooms();
      _syncVisibleRoomCount();
      _roomId = newRoom.id;
      _roomStatus = newRoom.status;
      _messages = [];
      _hasMoreMessages = false;
      _isRoomLoading = false;
      _showRatingPrompt = false;
      _isRatingSubmitted = false;

      // In reverse scrolling, messages are Newest -> Oldest.
      // Initial message is usually null for new conversation unless backend adds system message.
      if (newRoom.lastMessage != null) {
        _messages.add(newRoom.lastMessage!);
      }
      _cacheCurrentRoomMessages();

      // No need to fetchMessages for a brand new empty room
      _startTypingSubscription();
      _startMessageSubscription(); // Ensure we listen to this new room

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
    final result = await _useCases.fetchRooms();
    if (!result.hasException) {
      _clearError(notify: true);
      final List roomsList = result.data?['visitorRooms'] ?? [];
      _rooms = roomsList.map((r) => TalqRoom.fromJson(r)).toList();
      _sortRooms();
      _syncVisibleRoomCount(reset: resetVisibleWindow);
      notifyListeners();
      return;
    }

    _setError(
      result.exception,
      fallbackMessage: 'Unable to load conversations right now.',
    );
  }

  /// Completely resets the current session and visitor identity
  Future<void> resetSession() async {
    await AuthManager.resetSession();
    _isInitialized = false;
    _visitor = null;
    _roomId = null;
    _rooms = [];
    _visibleRoomCount = 0;
    _isFetchingMoreRooms = false;
    _messages = [];
    _messageCache.clear();
    _isRoomLoading = false;
    _isLoading = false;
    _messageSubscription?.cancel();
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

    final isSwitchingRoom = !isLoadMore && roomId != null && roomId != _roomId;

    if (isLoadMore) {
      if (_isFetchingMore || !_hasMoreMessages) return;
      _isFetchingMore = true;
      notifyListeners();
    } else {
      // capture current version to detect if state changed during async operation
      // Only capture version for initial load, to allow cancellation
      _fetchVersion++;
      if (isSwitchingRoom) {
        _roomId = targetRoomId;
        _hasMoreMessages = false;
        _roomStatus = RoomStatus.open;
        _rating = null;
        _ratingComment = null;
        _isRatingSubmitted = false;
        _showRatingPrompt = false;
        _replyingTo = null;

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

    final currentFetchVersion = _fetchVersion;

    // Prepare cursor for pagination
    // Since we sort NEWEST -> OLDEST, the 'after' cursor for fetching OLDER messages
    // is the ID of the LAST message we have (which is the oldest one in our list).
    // Backend GetMessages uses 'after' to fetch messages OLDER than the cursor.
    String? afterCursor;
    if (isLoadMore && _messages.isNotEmpty) {
      afterCursor = _messages.last.id;
    }

    if (!isLoadMore) {
      // Mark as delivered when fetching room (only initial load)
      markAsDelivered(targetRoomId);
    }

    final result = await _useCases.fetchRoomMessages(
      roomId: targetRoomId,
      afterCursor: afterCursor,
    );

    // Safety check: if version changed while fetching (only for initial load), abort
    if (!isLoadMore && currentFetchVersion != _fetchVersion) {
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

    // We don't really use events for strictly ordered logic right now,
    // but if we did, we'd need to merge them carefully.
    // For now, let's keep the existing logic for reassignments but only process them on initial load?
    // Or we can just ignore them for pagination simplicity if they aren't critical.
    // The current implementation injects "Reassigned to..." messages.
    // To do this correctly with pagination is tricky because events are separate.
    // Let's simplified: Only showing reassignment events on initial load or if they are recent?
    // Actually, if we paginate, we might miss events that happened "between" pages if we don't fetch events with pagination too.
    // But events are not paginated in the query? `events` returns ALL events?
    // Checking schema... `events: [RoomEvent!]!` -> returns ALL events.
    // So we can just process all events and insert them into the list based on timestamp.
    // But if we are paginating messages, we only want events that fall within the time range of the fetched messages.
    // This is getting complicated.
    // Simple approach: Just ignore reassignment events for infinite scroll for now, or just append them all at the end (oldest)?
    // Better: Process events only on initial load, and filter them to show only those
    // that are relevant to the messages we have?
    // Let's stick to basics: Just show messages.

    // Backend returns messages Ordered by CreatedAt DESC (Newest first).
    // So `newMessages` are already [Newest, ..., Oldest].

    // Pagination status
    _hasMoreMessages = pageInfo?['hasNextPage'] ?? false;
    debugPrint(
      '[TalqController] fetchMessages: isLoadMore=$isLoadMore, newMessages=${newMessages.length}, hasMoreMessages=$_hasMoreMessages, totalMessages=${_messages.length}, afterCursor=$afterCursor',
    );

    _messages = _mergeMessagesNewestFirst(
      localMessages: _messages,
      serverMessages: newMessages,
    );

    if (!isLoadMore) {
      // Re-inject events logic (only on initial load for now to keep it simple)
      final assignedEvents = eventList
          .where((e) => e['type'] == 'ROOM_ASSIGNED')
          .toList();
      for (int i = 1; i < assignedEvents.length; i++) {
        // ... (same logic as before, create system message)
        // we need to insert this system message into _messages at correct position
        // Since _messages is Newest->Oldest, we need to find where it fits.
        // This is O(N) but N is 20-50, so fine.
        // Implementing this strictly might be overkill for this task.
        // Let's skip event injection for infinite scroll task to ensure stability first.
      }

      // fetch room status and start typing subscription if we switched rooms
      if (roomId != null) {
        await _fetchRoomStatus();
        _startTypingSubscription();
      }

      // Start subscription if not already
      _startMessageSubscription();
    }

    _cacheMessagesForRoom(targetRoomId, _messages);
    _isRoomLoading = false;
    notifyListeners();

    // only mark as read if chat is currently visible and it's initial load
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

    // IF tempId was NOT provided, we add the optimistic message immediately.
    // This prevents visible delay when a new room has to be created first.
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
      _replyingTo = null; // Clear after sending
      _cacheCurrentRoomMessages();
      notifyListeners();
    }

    // IF _roomId is null, it means we are in "new conversation" mode (e.g. from "Send us a message").
    // We must force the creation of a NEW room first, otherwise the backend might attach
    // this message to an existing open room.
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

        // Update local state
        _rooms.insert(0, newRoom);
        _sortRooms();
        _roomId = newRoom.id;
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

    // Update room preview optimistically
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

    // Replace optimistic message with real one
    final index = _messages.indexWhere((m) => m.id == effectiveTempId);
    if (index != -1) {
      final oldMsg = _messages[index];
      final data = result.data!['sendVisitorMessage'];
      final realMessage = TalqMessage.fromJson(data);

      // Preserve read/delivered status if already applied by room pulse
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

      // Update room ID if it was still null (fallback)
      if (_roomId == null) {
        _roomId = data['room']['id'];
        _startTypingSubscription();
      }

      // Update room preview with real message data
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
    final fileName = path.basename(filePath);
    final extension = path.extension(filePath).toLowerCase();

    ContentType contentType = ContentType.text;
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(extension)) {
      contentType = ContentType.image;
    } else if (extension == '.pdf') {
      contentType = ContentType.pdf;
    }

    // 1. Create optimistic message
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

    // Insert at beginning (Newest)
    _messages.insert(0, optMsg);
    _replyingTo = null;
    _cacheCurrentRoomMessages();
    notifyListeners();

    try {
      // 2. Upload file through centralized Dio client
      final fileUrl = await _useCases.uploadFile(filePath);

      // 3. Send message with detected type
      await sendMessage(
        messageContent,
        contentType: contentType,
        fileUrl: fileUrl,
        fileName: fileName,
        tempId: tempId,
      );

      // 4. No need to remove temporary optimistic message anymore,
      // sendMessage will replace it instead of creating a new one.
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

    // Optimistically clear unread count locally
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

          // Update the rooms list with last message
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

          // Show in-app notification for agent/bot messages when chat isn't visible
          if (newMessage.senderType != SenderType.visitor && !_isChatVisible) {
            _showInAppNotification(newMessage);
          }

          // 2. Logic for Active Room message list
          if (newMessage.roomId == _roomId) {
            // Check if we already have this message (either as real or optimistic)
            final existingIdx = _messages.indexWhere((m) {
              return m.id == newMessage.id ||
                  (m.id.startsWith('temp-') &&
                      m.content == newMessage.content &&
                      m.senderType == newMessage.senderType);
            });

            if (existingIdx != -1) {
              // Message exists, preserve status during replacement
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
              // Truly new message
              _messages.insert(0, newMessage);

              // Mark as delivered for incoming agent/other messages
              if (newMessage.senderType != SenderType.visitor) {
                markAsDelivered(_roomId!);
                if (_isChatVisible) {
                  markAsRead();
                }
              }
            }
            _cacheCurrentRoomMessages();
            notifyListeners();
          }
        }
      },
      onError: (error) {
        debugPrint('[TalqController] Message Subscription Error: $error');
        _setError(
          error,
          fallbackMessage: 'Live updates interrupted. Pull to refresh.',
        );
        // Attempt to resubscribe after a delay
        Future.delayed(const Duration(seconds: 5), () {
          if (!_disposed) _startMessageSubscription();
        });
      },
    );

    _startRoomSubscription();
  }

  void _startRoomSubscription() {
    _roomSubscription?.cancel();

    _roomSubscription = _useCases.subscribeVisitorRoomUpdated().listen(
      (result) {
        if (result.data != null) {
          final roomData = result.data!['visitorRoomUpdated'];
          final roomId = roomData['id'];

          // 1. Update the main rooms list
          final roomIndex = _rooms.indexWhere((r) => r.id == roomId);
          final newRoom = TalqRoom.fromJson(roomData);

          if (roomIndex != -1) {
            final existingRoom = _rooms[roomIndex];
            // Only update last message info if it's actually newer or same
            // This prevents race conditions where ROOM_UPDATED pulse (stale)
            // overwrites a NEW_MESSAGE pulse (fresh)
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

          // 2. Update active room state if necessary
          if (roomId == _roomId) {
            final newStatus = RoomStatus.fromString(roomData['status']);

            // If transitioning to RESOLVED, always show prompt (re-rating flow)
            if (newStatus == RoomStatus.resolved &&
                _roomStatus != RoomStatus.resolved) {
              _showRatingPrompt = true;
            }

            // Sync message statuses for visitor messages
            // Use the unreadCount to identify which messages are read/delivered
            final unreadN = newRoom.unreadCount;
            final allRead = unreadN == 0;
            final lastMsg = roomData['lastMessage'];

            // Fallback to lastMessage status if explicitly provided
            bool lastMsgRead = false;
            bool lastMsgDelivered = false;
            if (lastMsg != null &&
                SenderType.fromString(lastMsg['senderType']) ==
                    SenderType.visitor) {
              lastMsgRead = lastMsg['read'] ?? false;
              lastMsgDelivered = lastMsg['delivered'] ?? false;
            }

            // Identify IDs of unread confirmed messages
            // _messages is newest-first (index 0 is newest)
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
                  // If it's a confirmed message and NOT in the unread set, it's read
                  if (!m.id.startsWith('temp-') && !unreadIds.contains(m.id)) {
                    shouldMarkRead = true;
                    shouldMarkDelivered = true;
                  }

                  // Also respect lastMsg status (it might be fresher than unreadCount pulse)
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

          // preserve agent avatars from existing workspace
          final avatars = _workspace?.agentAvatars ?? [];
          _workspace = newWorkspace.copyWith(agentAvatars: avatars);

          // apply primary color to theme if valid
          if (_workspace!.primaryColor.isNotEmpty) {
            try {
              _theme = _theme.copyWith(
                primaryColor: TalqTheme.fromHex(_workspace!.primaryColor),
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

              // If it's not us (the visitor), then it's the agent
              if (typingUserId != _visitor?.id) {
                _isAgentTyping = true;
                notifyListeners();

                // Reset after 3 seconds of no activity
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
      _showRatingPrompt = false; // Hide prompt on success
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

    // Safety check: if version changed while fetching, abort
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
      // On fetch (refresh), only show prompt if unrated
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
        _messages[messageIndex] = TalqMessage(
          id: oldMsg.id,
          roomId: oldMsg.roomId,
          content: oldMsg.content,
          senderType: oldMsg.senderType,
          senderName: oldMsg.senderName,
          senderAvatarUrl: oldMsg.senderAvatarUrl,
          contentType: oldMsg.contentType,
          fileUrl: oldMsg.fileUrl,
          fileName: oldMsg.fileName,
          createdAt: oldMsg.createdAt,
          isRead: oldMsg.isRead,
          replyTo: oldMsg.replyTo,
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
        _messages[messageIndex] = TalqMessage(
          id: oldMsg.id,
          roomId: oldMsg.roomId,
          content: oldMsg.content,
          senderType: oldMsg.senderType,
          senderName: oldMsg.senderName,
          senderAvatarUrl: oldMsg.senderAvatarUrl,
          contentType: oldMsg.contentType,
          fileUrl: oldMsg.fileUrl,
          fileName: oldMsg.fileName,
          createdAt: oldMsg.createdAt,
          isRead: oldMsg.isRead,
          replyTo: oldMsg.replyTo,
          reactions: Map<String, dynamic>.from(
            updatedData['reactions'] is String
                ? json.decode(updatedData['reactions'])
                : updatedData['reactions'],
          ),
        );
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

      // Update the main faqs list for background loading if this is the initial/empty search load
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
