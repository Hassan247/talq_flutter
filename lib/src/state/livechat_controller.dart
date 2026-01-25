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
  bool _isLoading = false;
  bool _isInitialized = false;
  LivechatVisitor? _visitor;
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

  LivechatController(this._api);

  List<LivechatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  LivechatVisitor? get visitor => _visitor;
  String? get roomId => _roomId;
  RoomStatus get roomStatus => _roomStatus;
  bool get isRatingSubmitted => _isRatingSubmitted;
  int? get rating => _rating;
  String? get ratingComment => _ratingComment;
  bool get showRatingPrompt => _showRatingPrompt;
  bool get isAgentTyping => _isAgentTyping;

  /// Initializes the livechat session
  Future<void> initialize({
    String? name,
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
              name
              email
              rooms { id status rating ratingComment }
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
            'name': name,
            'email': email,
          },
        },
      );

      if (result.hasException) throw result.exception!;

      final authData = result.data!['initVisitor'];
      await AuthManager.saveToken(authData['token']);
      _visitor = LivechatVisitor.fromJson(authData['visitor']);

      // Try to find an active room
      final List rooms = authData['visitor']['rooms'] ?? [];
      for (var r in rooms) {
        if (r['status'] == 'OPEN' || r['status'] == 'ASSIGNED') {
          _roomId = r['id'];
          _roomStatus = _parseRoomStatus(r['status']);
          _isRatingSubmitted = r['rating'] != null;
          break;
        } else if (r['status'] == 'RESOLVED') {
          _roomId = r['id'];
          _roomStatus = RoomStatus.resolved;
          _rating = r['rating'];
          _ratingComment = r['ratingComment'];
          _isRatingSubmitted = r['rating'] != null;
          // Only show prompt if not rated yet (on initial load)
          _showRatingPrompt = _rating == null;
          break;
        }
      }

      // 3. Re-init client with token
      await _api.init();

      // 4. Load initial messages
      await fetchMessages();
      await markAsRead();

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

  /// Completely resets the current session and visitor identity
  Future<void> resetSession() async {
    await AuthManager.resetSession();
    _isInitialized = false;
    _visitor = null;
    _roomId = null;
    _messages = [];
    _isLoading = false;
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _roomSubscription?.cancel();
    notifyListeners();
  }

  /// Fetches conversation history
  Future<void> fetchMessages() async {
    const String query = r'''
      query {
        visitorMessages(first: 50) {
          edges {
            node { 
              id content senderType contentType fileUrl createdAt read 
              room { id }
            }
          }
        }
      }
    ''';

    final result = await _api.query(query);
    if (!result.hasException) {
      final List edges = result.data?['visitorMessages']['edges'] ?? [];
      _messages = edges
          .map((e) => LivechatMessage.fromJson(e['node']))
          .toList();

      if (_messages.isNotEmpty) {
        // Extract room ID from the first message
        _roomId =
            result.data?['visitorMessages']['edges'][0]['node']['room']['id'];

        // When fetching messages, we also need the room status
        await _fetchRoomStatus();
      }

      _messages = _messages.reversed.toList(); // Newest at bottom
      notifyListeners();
      markAsRead();
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

    const String mutation = r'''
      mutation SendVisitorMessage($input: SendMessageInput!) {
        sendVisitorMessage(input: $input) {
          id content senderType contentType fileUrl createdAt
          room { id }
        }
      }
    ''';

    // Optimistic update
    final tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
    final optMsg = LivechatMessage(
      id: tempId,
      content: content,
      senderType: SenderType.visitor,
      contentType: contentType,
      fileUrl: fileUrl,
      fileName: fileName,
      createdAt: DateTime.now(),
    );
    _messages.add(optMsg);
    notifyListeners();

    final result = await _api.mutate(
      mutation,
      variables: {
        'input': {
          'content': content,
          'contentType': contentType == ContentType.image
              ? 'IMAGE'
              : contentType == ContentType.pdf
              ? 'PDF'
              : 'TEXT',
          'fileUrl': fileUrl,
          'fileName': fileName,
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

      // Update room ID if it was null (first message)
      if (_roomId == null) {
        _roomId = data['room']['id'];
        _startTypingSubscription();
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

  /// Marks all messages in the current room as read
  Future<void> markAsRead() async {
    if (_roomId == null) return;

    const String mutation = r'''
      mutation MarkMessagesAsRead($roomId: ID!) {
        markMessagesAsRead(roomId: $roomId)
      }
    ''';

    await _api.mutate(mutation, variables: {'roomId': _roomId});
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

  void _startMessageSubscription() {
    _messageSubscription?.cancel();

    const String sub = r'''
      subscription {
        visitorNewMessage {
          id content senderType contentType fileUrl createdAt read
        }
      }
    ''';

    _messageSubscription = _api.subscribe(sub).listen((result) {
      if (result.data != null) {
        final newMessage = LivechatMessage.fromJson(
          result.data!['visitorNewMessage'],
        );

        // Avoid duplicates if we sent it ourselves
        if (!_messages.any((m) => m.id == newMessage.id)) {
          _messages.add(newMessage);
          if (newMessage.senderType != SenderType.visitor) {
            markAsRead();
          }
          notifyListeners();
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
          id status rating ratingComment
        }
      }
    ''';

    _roomSubscription = _api.subscribe(sub).listen((result) {
      if (result.data != null) {
        final roomData = result.data!['visitorRoomUpdated'];
        if (roomData['id'] == _roomId) {
          final newStatus = _parseRoomStatus(roomData['status']);

          // If transitioning to RESOLVED, always show prompt (re-rating flow)
          if (newStatus == RoomStatus.resolved &&
              _roomStatus != RoomStatus.resolved) {
            _showRatingPrompt = true;
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
}
