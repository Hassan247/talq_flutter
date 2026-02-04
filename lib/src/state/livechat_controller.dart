import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import '../core/auth_manager.dart';
import '../core/livechat_client.dart';
import '../models/models.dart';

class LivechatController extends ChangeNotifier {
  final LivechatClient _api;

  List<LivechatMessage> _messages = [];
  List<LivechatRoom> _rooms = [];
  List<LivechatFAQ> _faqs = [];

  // Paginated FAQs
  List<LivechatFAQ> _paginatedFaqs = [];
  bool _faqHasNextPage = false;
  String? _faqEndCursor;
  String _faqSearchQuery = '';
  bool _isFaqLoading = false;

  bool _isLoading = false;
  bool _isInitialized = false;
  LivechatVisitor? _visitor;
  LivechatWorkspace? _workspace;
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
  Timer? _typingTimer;
  LivechatMessage? _replyingTo;
  bool _isChatVisible = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  LivechatController(this._api);

  List<LivechatMessage> get messages => _messages;
  List<LivechatRoom> get rooms => _rooms;
  List<LivechatFAQ> get faqs => _faqs;
  List<LivechatFAQ> get paginatedFaqs => _paginatedFaqs;
  bool get faqHasNextPage => _faqHasNextPage;
  String get faqSearchQuery => _faqSearchQuery;
  bool get isFaqLoading => _isFaqLoading;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  LivechatVisitor? get visitor => _visitor;
  LivechatWorkspace? get workspace => _workspace;
  String? get roomId => _roomId;
  RoomStatus get roomStatus => _roomStatus;
  bool get isRatingSubmitted => _isRatingSubmitted;
  int? get rating => _rating;
  String? get ratingComment => _ratingComment;
  bool get showRatingPrompt => _showRatingPrompt;
  bool get isAgentTyping => _isAgentTyping;
  LivechatMessage? get replyingTo => _replyingTo;
  bool get isChatVisible => _isChatVisible;
  AppLifecycleState get lifecycleState => _lifecycleState;

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

  void setReplyingTo(LivechatMessage? message) {
    _replyingTo = message;
    notifyListeners();
  }

  /// Initializes the livechat session
  Future<void> initialize({
    String? firstName,
    String? lastName,
    String? email,
    String? currentPage,
  }) async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Initialize GraphQL Client
      await _api.init();

      // 2. Get/Register Visitor
      final deviceId = await AuthManager.getDeviceId();
      final platform = AuthManager.getPlatform();

      const String initMutation = r'''
        mutation InitVisitor($input: InitVisitorInput!) {
          initVisitor(input: $input) {
            token
            visitor {
              id
              firstName
              lastName
              email
              rooms { 
                id 
                status 
                unreadCount 
                visitorUnreadCount
                lastMessageAt 
                lastMessage {
                  id
                  content
                  senderType
                  senderName
                  senderAvatarUrl
                  createdAt
                  delivered
                  read
                }
                createdAt
                rating 
                ratingComment
                assignee {
                  firstName
                  lastName
                  avatarUrl
                } 
              }
            }
            workspace {
              id
              name
              logoUrl
              showResponseTime
              responseTimeType
              customResponseTime
              autoReplyEnabled
              autoReplyMessage
            }
            agentAvatars
            faqs {
              id
              question
              answer
              sortOrder
            }
          }
        }
      ''';

      final result = await _api.mutate(
        initMutation,
        variables: {
          'input': {
            'deviceId': deviceId,
            'platform': platform,
            'firstName': firstName,
            'lastName': lastName,
            'email': email,
          },
        },
      );

      if (result.hasException) throw result.exception!;

      final authData = result.data!['initVisitor'];
      await AuthManager.saveToken(authData['token']);
      _visitor = LivechatVisitor.fromJson(authData['visitor']);

      final ws = LivechatWorkspace.fromJson(authData['workspace']);
      final avatars = (authData['agentAvatars'] as List?)?.cast<String>() ?? [];
      _workspace = ws.copyWith(agentAvatars: avatars);

      // Populate FAQs
      final List faqsList = authData['faqs'] ?? [];
      _faqs = faqsList.map((f) => LivechatFAQ.fromJson(f)).toList();

      // Populate rooms list
      final List roomsList = authData['visitor']['rooms'] ?? [];
      _rooms = roomsList.map((r) => LivechatRoom.fromJson(r)).toList();
      _sortRooms();

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
      await _api.init();

      // 4. Load initial messages (markAsRead will be called by setChatVisible when chat opens)
      if (_roomId != null) {
        await fetchMessages(roomId: _roomId);
      }

      // 5. Start subscriptions
      _startMessageSubscription();
      if (_roomId != null) {
        _startTypingSubscription();
      }

      // Update current page if provided
      if (currentPage != null) {
        await updatePage(currentPage);
      }

      _isInitialized = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Prepares the controller for a new conversation locally without creating a room on the backend.
  /// The room will be created when the first message is sent.
  void prepareNewConversation() {
    _roomId = null;
    _messages = [];
    _roomStatus = RoomStatus.open;
    _rating = null;
    _ratingComment = null;
    _isRatingSubmitted = false;
    _showRatingPrompt = false;
    _isAgentTyping = false;
    _replyingTo = null;
    notifyListeners();
  }

  /// Forces creation of a brand new conversation on the backend
  Future<void> startNewConversation() async {
    // If we're not initialized (e.g. after resetSession), we must initialize first
    // to get a valid token before we can start a conversation.
    if (!_isInitialized) {
      await initialize();
    }

    _isLoading = true;
    notifyListeners();

    try {
      const String mutation = r'''
        mutation {
          startNewConversation {
            id
            status
            createdAt
            lastMessageAt
            lastMessage {
              id
              content
              senderType
              senderName
              senderAvatarUrl
              createdAt
              delivered
              read
            }
          }
        }
      ''';

      final result = await _api.mutate(mutation);
      if (result.hasException) throw result.exception!;

      final roomData = result.data!['startNewConversation'];
      final newRoom = LivechatRoom.fromJson(roomData);

      // Update local state
      _rooms.insert(0, newRoom);
      _sortRooms();
      _roomId = newRoom.id;
      _roomStatus = newRoom.status;
      _messages = [];
      _showRatingPrompt = false;
      _isRatingSubmitted = false;

      await fetchMessages(roomId: _roomId);
      _startTypingSubscription();

      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refreshes the list of visitor rooms
  Future<void> fetchRooms() async {
    const String query = r'''
      query {
        visitorRooms {
          id
          status
          unreadCount
          visitorUnreadCount
          lastMessageAt
          lastMessage {
            id
            content
            senderType
            senderName
            senderAvatarUrl
            createdAt
            delivered
            read
          }
          createdAt
          rating
          ratingComment
          assignee {
            id
            firstName
            lastName
            avatarUrl
          }
        }
      }
    ''';

    final result = await _api.query(query);
    if (!result.hasException) {
      final List roomsList = result.data?['visitorRooms'] ?? [];
      _rooms = roomsList.map((r) => LivechatRoom.fromJson(r)).toList();
      _sortRooms();
      notifyListeners();
    }
  }

  /// Completely resets the current session and visitor identity
  Future<void> resetSession() async {
    await AuthManager.resetSession();
    _isInitialized = false;
    _visitor = null;
    _roomId = null;
    _rooms = [];
    _messages = [];
    _isLoading = false;
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _roomSubscription?.cancel();
    notifyListeners();
  }

  /// Fetches conversation history for a specific room or the active one
  Future<void> fetchMessages({String? roomId}) async {
    final targetRoomId = roomId ?? _roomId;
    if (targetRoomId == null) return;

    const String query = r'''
      query GetRoom($roomId: ID!) {
        room(id: $roomId) {
          id
          status
          unreadCount
          visitorUnreadCount
          messages(first: 50) {
            edges {
              node { 
                id content senderType senderName senderAvatarUrl contentType fileUrl createdAt read delivered reactions
                replyTo { id content senderType senderName contentType createdAt }
              }
            }
          }
          events {
            id type metadata createdAt
          }
        }
      }
    ''';

    // Mark as delivered when fetching room
    markAsDelivered(targetRoomId);

    final result = await _api.query(query, variables: {'roomId': targetRoomId});
    if (result.hasException) {
      // Handle production logging if needed
    }

    if (!result.hasException) {
      final roomData = result.data?['room'];
      if (roomData == null) {
        return;
      }

      final List edges = roomData['messages']?['edges'] ?? [];
      final List eventList = roomData['events'] ?? [];

      try {
        _messages = edges
            .map((e) => LivechatMessage.fromJson(e['node']))
            .toList();
      } catch (e) {
        // Handle production logging if needed
      }

      // Interleave reassignment events as system messages (skip first one - initial assignment)
      final assignedEvents = eventList
          .where((e) => e['type'] == 'ROOM_ASSIGNED')
          .toList();

      // Skip the first assignment, only show reassignments
      for (int i = 1; i < assignedEvents.length; i++) {
        final event = assignedEvents[i];
        final metadata = event['metadata'] ?? {};
        final agentName = metadata['agent_name'] ?? 'another agent';
        _messages.add(
          LivechatMessage(
            id: event['id'],
            content: 'Reassigned to $agentName',
            senderType: SenderType.system,
            createdAt: DateTime.parse(event['createdAt']),
          ),
        );
      }

      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Update room state if we just switched
      if (roomId != null && roomId != _roomId) {
        _roomId = roomId;
        await _fetchRoomStatus();
        _startTypingSubscription();
      }

      notifyListeners();
      // only mark as read if chat is currently visible
      if (_isChatVisible) {
        markAsRead();
      }
    }
  }

  /// Sends a new message
  Future<void> sendMessage(
    String content, {
    ContentType contentType = ContentType.text,
    String? fileUrl,
    String? fileName,
  }) async {
    if (content.trim().isEmpty && fileUrl == null) return;

    // IF _roomId is null, it means we are in "new conversation" mode (e.g. from "Send us a message").
    // We must force the creation of a NEW room first, otherwise the backend might attach
    // this message to an existing open room.
    if (_roomId == null) {
      try {
        const String createMutation = r'''
          mutation {
            startNewConversation {
              id
              status
              lastMessageAt
              lastMessage {
                id
                content
                senderType
                senderName
                senderAvatarUrl
                createdAt
              }
            }
          }
        ''';

        final createResult = await _api.mutate(createMutation);
        if (!createResult.hasException) {
          final roomData = createResult.data!['startNewConversation'];
          final newRoom = LivechatRoom.fromJson(roomData);

          // Update local state
          _rooms.insert(0, newRoom);
          _sortRooms();
          _roomId = newRoom.id;
          _roomStatus = newRoom.status;
          // _messages is already empty or has optimistic message, don't clear it
          _showRatingPrompt = false;
          _isRatingSubmitted = false;
          _startTypingSubscription();
        }
      } catch (e) {
        // If creation fails, we will fall through and try to send with null roomId
        // which might attach to old room or fail.
        debugPrint('Failed to force create new conversation: $e');
      }
    }

    final tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
    final replyToId = _replyingTo?.id;

    final optMsg = LivechatMessage(
      id: tempId,
      content: content,
      senderType: SenderType.visitor,
      contentType: contentType,
      fileUrl: fileUrl,
      fileName: fileName,
      createdAt: DateTime.now(),
      replyTo: _replyingTo,
    );
    _messages.add(optMsg);
    _replyingTo = null; // Clear after sending

    // Update room preview optimistically
    if (_roomId != null) {
      final roomIdx = _rooms.indexWhere((r) => r.id == _roomId);
      if (roomIdx != -1) {
        final room = _rooms[roomIdx];
        _rooms[roomIdx] = LivechatRoom(
          id: room.id,
          status: room.status,
          unreadCount: room.unreadCount,
          visitorUnreadCount: room.visitorUnreadCount,
          lastMessageAt: optMsg.createdAt,
          lastMessage: optMsg,
          createdAt: room.createdAt,
          rating: room.rating,
          ratingComment: room.ratingComment,
          assigneeName: room.assigneeName,
          assigneeAvatarUrl: room.assigneeAvatarUrl,
        );
        _sortRooms();
      }
    }
    notifyListeners();

    const String mutation = r'''
      mutation SendVisitorMessage($input: SendMessageInput!) {
        sendVisitorMessage(input: $input) {
          id content senderType senderName senderAvatarUrl contentType fileUrl createdAt read reactions
          replyTo { id content senderType senderName contentType createdAt }
          room { id }
        }
      }
    ''';

    final result = await _api.mutate(
      mutation,
      variables: {
        'input': {
          'roomId': _roomId,
          'content': content,
          'contentType': contentType == ContentType.image
              ? 'IMAGE'
              : contentType == ContentType.pdf
              ? 'PDF'
              : 'TEXT',
          'fileUrl': fileUrl,
          'fileName': fileName,
          'replyToId': replyToId,
        },
      },
    );

    if (result.hasException) {
      _messages.removeWhere((m) => m.id == tempId);
      notifyListeners();
      return;
    }

    // Replace optimistic message with real one
    final index = _messages.indexWhere((m) => m.id == tempId);
    if (index != -1) {
      final data = result.data!['sendVisitorMessage'];
      _messages[index] = LivechatMessage.fromJson(data);

      // Update room ID if it was still null (fallback)
      if (_roomId == null) {
        _roomId = data['room']['id'];
        _startTypingSubscription();
      }

      // Update room preview with real message data
      final roomIdx = _rooms.indexWhere((r) => r.id == _roomId);
      if (roomIdx != -1) {
        final room = _rooms[roomIdx];
        final newMessage = _messages[index];
        _rooms[roomIdx] = LivechatRoom(
          id: room.id,
          status: room.status,
          unreadCount: room.unreadCount,
          visitorUnreadCount: room.visitorUnreadCount,
          lastMessageAt: newMessage.createdAt,
          lastMessage: newMessage,
          createdAt: room.createdAt,
          rating: room.rating,
          ratingComment: room.ratingComment,
          assigneeName: room.assigneeName,
          assigneeAvatarUrl: room.assigneeAvatarUrl,
        );
        _sortRooms();
      }

      notifyListeners();
    }
  }

  /// Picks and sends a file (image or PDF)
  Future<void> sendFile(String filePath) async {
    // 1. Upload file to backend
    final token = await AuthManager.getToken();
    final uri = Uri.parse(_api.httpUrl).replace(path: '/upload');

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('file', filePath));

    final response = await request.send();
    if (response.statusCode != 200) {
      return;
    }

    final responseBody = await response.stream.bytesToString();
    final decoded = json.decode(responseBody);
    final fileUrl = decoded['url'];
    final fileName = path.basename(filePath);
    final extension = path.extension(filePath).toLowerCase();

    ContentType contentType = ContentType.text;
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(extension)) {
      contentType = ContentType.image;
    } else if (extension == '.pdf') {
      contentType = ContentType.pdf;
    }

    // 2. Send message with detected type
    await sendMessage(
      'Sent a ${contentType == ContentType.image ? 'image' : 'file'}: $fileName',
      contentType: contentType,
      fileUrl: fileUrl,
      fileName: fileName,
    );
  }

  /// Notifies the backend that the visitor is typing
  Future<void> sendTyping(String roomId) async {
    const String mutation = r'''
      mutation VisitorTyping($roomId: ID!) {
        visitorTyping(roomId: $roomId)
      }
    ''';
    await _api.mutate(mutation, variables: {'roomId': roomId});
  }

  /// Updates the visitor's current viewing page
  Future<void> updatePage(String page) async {
    if (_roomId == null) return;

    const String mutation = r'''
      mutation UpdateVisitorPage($roomId: ID!, $page: String!) {
        updateVisitorPage(roomId: $roomId, page: $page) {
          id
          currentPage
        }
      }
    ''';

    await _api.mutate(mutation, variables: {'roomId': _roomId, 'page': page});

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
        _rooms[roomIndex] = LivechatRoom(
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

    const String mutation = r'''
      mutation MarkMessagesAsRead($roomId: ID!) {
        markMessagesAsRead(roomId: $roomId)
      }
    ''';

    await _api.mutate(mutation, variables: {'roomId': _roomId});
  }

  Future<void> markAsDelivered(String roomID) async {
    const String mutation = r'''
      mutation VisitorMarkMessagesAsDelivered($roomId: ID!) {
        visitorMarkMessagesAsDelivered(roomId: $roomId)
      }
    ''';

    await _api.mutate(mutation, variables: {'roomId': roomID});
  }

  static RoomStatus _parseRoomStatus(String status) {
    switch (status) {
      case 'OPEN':
        return RoomStatus.open;
      case 'ASSIGNED':
        return RoomStatus.assigned;
      case 'RESOLVED':
        return RoomStatus.resolved;
      case 'CLOSED':
        return RoomStatus.closed;
      default:
        return RoomStatus.open;
    }
  }

  static SenderType _parseSenderType(String type) {
    switch (type) {
      case 'AGENT':
        return SenderType.agent;
      case 'SYSTEM':
        return SenderType.system;
      default:
        return SenderType.visitor;
    }
  }

  void _startMessageSubscription() {
    _messageSubscription?.cancel();

    const String sub = r'''
      subscription {
        visitorNewMessage {
          id content senderType senderName senderAvatarUrl contentType fileUrl createdAt read reactions
          replyTo { id content senderType senderName contentType createdAt }
          room { id }
        }
      }
    ''';

    _messageSubscription = _api.subscribe(sub).listen((result) {
      if (result.data != null) {
        final newMessage = LivechatMessage.fromJson(
          result.data!['visitorNewMessage'],
        );

        // Update the rooms list with last message
        final roomIndex = _rooms.indexWhere((r) => r.id == newMessage.roomId);
        if (roomIndex != -1) {
          final room = _rooms[roomIndex];
          _rooms[roomIndex] = LivechatRoom(
            id: room.id,
            status: room.status,
            unreadCount: room.unreadCount,
            visitorUnreadCount:
                (newMessage.senderType != SenderType.visitor && !_isChatVisible)
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
        } else {
          // If room doesn't exist, we might want to fetch it or just ignore if it's not ours
          // But for safety, let's at least not crash.
          // Actually, we should probably fetch rooms to be sure.
          fetchRooms();
        }
        _sortRooms();
        notifyListeners();

        // 2. Logic for Active Room message list
        if (newMessage.roomId == _roomId) {
          // Avoid duplicates if we sent it ourselves
          if (!_messages.any((m) => m.id == newMessage.id)) {
            _messages.add(newMessage);

            // Mark as delivered
            if (newMessage.senderType != SenderType.visitor) {
              markAsDelivered(_roomId!);
            }

            if (newMessage.senderType != SenderType.visitor && _isChatVisible) {
              markAsRead();
            }
            notifyListeners();
          }
        }
      }
    });

    _startRoomSubscription();
  }

  void _startRoomSubscription() {
    _roomSubscription?.cancel();

    const String sub = r'''
      subscription {
        visitorRoomUpdated {
          id status unreadCount visitorUnreadCount createdAt lastMessageAt rating ratingComment
          assignee { id firstName lastName avatarUrl }
          lastMessage {
            id content senderType senderName senderAvatarUrl createdAt delivered read
          }
        }
      }
    ''';

    _roomSubscription = _api.subscribe(sub).listen((result) {
      if (result.data != null) {
        final roomData = result.data!['visitorRoomUpdated'];
        final roomId = roomData['id'];

        // 1. Update the main rooms list
        final roomIndex = _rooms.indexWhere((r) => r.id == roomId);
        if (roomIndex != -1) {
          _rooms[roomIndex] = LivechatRoom.fromJson(roomData);
        } else {
          _rooms.add(LivechatRoom.fromJson(roomData));
        }
        _sortRooms();
        notifyListeners();

        // 2. Update active room state if necessary
        if (roomId == _roomId) {
          final newStatus = _parseRoomStatus(roomData['status']);

          // If transitioning to RESOLVED, always show prompt (re-rating flow)
          if (newStatus == RoomStatus.resolved &&
              _roomStatus != RoomStatus.resolved) {
            _showRatingPrompt = true;
          }

          // If assignee changed (reassignment), refetch messages to get new events
          if (roomData['assignee'] != null) {
            fetchMessages(roomId: _roomId);
          }

          // Sync message statuses for user messages
          final lastMsg = roomData['lastMessage'];
          if (lastMsg != null &&
              _parseSenderType(lastMsg['senderType']) == SenderType.visitor) {
            final isRead = lastMsg['read'] ?? false;
            final isDelivered = lastMsg['delivered'] ?? false;

            _messages = _messages.map((m) {
              if (m.senderType == SenderType.visitor &&
                  (!m.isRead || !m.isDelivered)) {
                return LivechatMessage(
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
                  isRead: m.isRead || isRead,
                  isDelivered: m.isDelivered || isDelivered,
                  replyTo: m.replyTo,
                  reactions: m.reactions,
                );
              }
              return m;
            }).toList();
          }

          _roomStatus = newStatus;
          _rating = roomData['rating'];
          _ratingComment = roomData['ratingComment'];
          _isRatingSubmitted = roomData['rating'] != null;
          notifyListeners();
        }
      }
    });
  }

  void _startTypingSubscription() {
    if (_roomId == null) return;
    _typingSubscription?.cancel();

    const String sub = r'''
      subscription OnTyping($roomId: ID!) {
        typing(roomId: $roomId)
      }
    ''';

    _typingSubscription = _api
        .subscribe(sub, variables: {'roomId': _roomId})
        .listen((result) {
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
        });
  }

  /// Submits a rating for the current room
  Future<void> rateRoom(int rating, {String? comment}) async {
    if (_roomId == null) return;

    const String mutation = r'''
      mutation RateRoom($roomId: ID!, $rating: Int!, $comment: String) {
        rateRoom(roomId: $roomId, rating: $rating, comment: $comment) {
          id
          rating
        }
      }
    ''';

    final result = await _api.mutate(
      mutation,
      variables: {'roomId': _roomId, 'rating': rating, 'comment': comment},
    );

    if (!result.hasException) {
      _showRatingPrompt = false; // Hide prompt on success
      _isRatingSubmitted = true;
      _rating = rating;
      _ratingComment = comment;
      notifyListeners();
    }
  }

  /// Submits feedback for an FAQ article
  Future<bool> voteFAQ(String faqId, bool helpful) async {
    const String mutation = r'''
      mutation VoteFAQ($id: ID!, $helpful: Boolean!) {
        voteFAQ(id: $id, helpful: $helpful)
      }
    ''';

    final result = await _api.mutate(
      mutation,
      variables: {'id': faqId, 'helpful': helpful},
    );

    return !result.hasException;
  }

  Future<void> _fetchRoomStatus() async {
    if (_roomId == null) return;

    const String query = r'''
      query GetRoom($id: ID!) {
        room(id: $id) {
          id
          status
          rating
          ratingComment
        }
      }
    ''';

    final result = await _api.query(query, variables: {'id': _roomId});
    if (!result.hasException && result.data != null) {
      final roomData = result.data!['room'];
      _roomStatus = _parseRoomStatus(roomData['status']);
      _rating = roomData['rating'];
      _ratingComment = roomData['ratingComment'];
      _isRatingSubmitted = roomData['rating'] != null;
      // On fetch (refresh), only show prompt if unrated
      if (_roomStatus == RoomStatus.resolved && _rating == null) {
        _showRatingPrompt = true;
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _roomSubscription?.cancel();
    _typingTimer?.cancel();
    super.dispose();
  }

  Future<void> addReaction(String messageId, String emoji) async {
    const String mutation = r'''
      mutation AddReaction($messageId: ID!, $emoji: String!) {
        addReaction(messageId: $messageId, emoji: $emoji) {
          id reactions
        }
      }
    ''';

    final result = await _api.mutate(
      mutation,
      variables: {'messageId': messageId, 'emoji': emoji},
    );

    if (!result.hasException) {
      final updatedData = result.data!['addReaction'];
      final messageIndex = _messages.indexWhere((m) => m.id == messageId);
      if (messageIndex != -1) {
        final oldMsg = _messages[messageIndex];
        _messages[messageIndex] = LivechatMessage(
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
        notifyListeners();
      }
    }
  }

  Future<void> removeReaction(String messageId, String emoji) async {
    const String mutation = r'''
      mutation RemoveReaction($messageId: ID!, $emoji: String!) {
        removeReaction(messageId: $messageId, emoji: $emoji) {
          id reactions
        }
      }
    ''';

    final result = await _api.mutate(
      mutation,
      variables: {'messageId': messageId, 'emoji': emoji},
    );

    if (!result.hasException) {
      final updatedData = result.data!['removeReaction'];
      final messageIndex = _messages.indexWhere((m) => m.id == messageId);
      if (messageIndex != -1) {
        final oldMsg = _messages[messageIndex];
        _messages[messageIndex] = LivechatMessage(
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
    }
  }

  Future<void> fetchFaqs({bool reload = false, String? query}) async {
    if (_isFaqLoading) return;

    if (reload || query != _faqSearchQuery) {
      _paginatedFaqs = [];
      _faqEndCursor = null;
      _faqHasNextPage = false;
      _faqSearchQuery = query ?? '';
    }

    if (!reload && _paginatedFaqs.isNotEmpty && !_faqHasNextPage) return;

    _isFaqLoading = true;
    notifyListeners();

    try {
      const String queryStr = r'''
        query VisitorFaqs($query: String, $first: Int, $after: String) {
          visitorFaqs(query: $query, first: $first, after: $after) {
            edges {
              node {
                id
                question
                answer
                sortOrder
              }
              cursor
            }
            pageInfo {
              hasNextPage
              endCursor
            }
            totalCount
          }
        }
      ''';

      final result = await _api.query(
        queryStr,
        variables: {
          'query': _faqSearchQuery.isEmpty ? null : _faqSearchQuery,
          'first': 20,
          'after': _faqEndCursor,
        },
      );

      if (result.hasException) throw result.exception!;

      final connection = FAQConnection.fromJson(result.data!['visitorFaqs']);
      _paginatedFaqs.addAll(connection.faqs);
      _faqHasNextPage = connection.hasNextPage;
      _faqEndCursor = connection.endCursor;

      // Update the main faqs list for background loading if this is the initial/empty search load
      if (_faqSearchQuery.isEmpty && reload) {
        _faqs = List.from(connection.faqs);
      }
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
  }
}
