enum SenderType { visitor, agent, system }

enum ContentType { text, image, pdf }

enum RoomStatus { open, assigned, resolved, closed }

class LivechatMessage {
  final String id;
  final String? roomId;
  final String content;
  final SenderType senderType;
  final String? senderName;
  final String? senderAvatarUrl;
  final ContentType contentType;
  final String? fileUrl;
  final String? fileName;
  final DateTime createdAt;
  final bool isRead;

  LivechatMessage({
    required this.id,
    this.roomId,
    required this.content,
    required this.senderType,
    this.senderName,
    this.senderAvatarUrl,
    this.contentType = ContentType.text,
    this.fileUrl,
    this.fileName,
    required this.createdAt,
    this.isRead = false,
  });

  factory LivechatMessage.fromJson(Map<String, dynamic> json) {
    return LivechatMessage(
      id: json['id'],
      roomId: json['room'] != null ? json['room']['id'] : null,
      content: json['content'],
      senderType: _parseSenderType(json['senderType']),
      senderName: json['senderName'],
      senderAvatarUrl: json['senderAvatarUrl'],
      contentType: _parseContentType(json['contentType']),
      fileUrl: json['fileUrl'],
      fileName: json['fileName'],
      createdAt: DateTime.parse(json['createdAt']),
      isRead: json['read'] ?? false,
    );
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

  static ContentType _parseContentType(String? type) {
    switch (type) {
      case 'IMAGE':
        return ContentType.image;
      case 'PDF':
        return ContentType.pdf;
      default:
        return ContentType.text;
    }
  }
}

class LivechatVisitor {
  final String id;
  final String? name;
  final String? email;
  final String? currentPage;

  LivechatVisitor({required this.id, this.name, this.email, this.currentPage});

  factory LivechatVisitor.fromJson(Map<String, dynamic> json) {
    return LivechatVisitor(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      currentPage: json['currentPage'],
    );
  }

  LivechatVisitor copyWith({
    String? id,
    String? name,
    String? email,
    String? currentPage,
  }) {
    return LivechatVisitor(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class LivechatRoom {
  final String id;
  final RoomStatus status;
  final int unreadCount;
  final DateTime? lastMessageAt;
  final LivechatMessage? lastMessage;
  final int? rating;
  final String? ratingComment;

  LivechatRoom({
    required this.id,
    required this.status,
    this.unreadCount = 0,
    this.lastMessageAt,
    this.lastMessage,
    this.rating,
    this.ratingComment,
  });

  factory LivechatRoom.fromJson(Map<String, dynamic> json) {
    return LivechatRoom(
      id: json['id'],
      status: _parseRoomStatus(json['status']),
      unreadCount: json['unreadCount'] ?? 0,
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'])
          : null,
      lastMessage: json['lastMessage'] != null
          ? LivechatMessage.fromJson(json['lastMessage'])
          : null,
      rating: json['rating'],
      ratingComment: json['ratingComment'],
    );
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
}

class LivechatWorkspace {
  final String id;
  final String name;
  final String? responseTime;
  final String? autoReplyMessage;
  final bool autoReplyEnabled;

  LivechatWorkspace({
    required this.id,
    required this.name,
    this.responseTime,
    this.autoReplyMessage,
    this.autoReplyEnabled = false,
  });

  factory LivechatWorkspace.fromJson(Map<String, dynamic> json) {
    String? rt;
    if (json['showResponseTime'] == true) {
      if (json['responseTimeType'] == 'CUSTOM') {
        rt = json['customResponseTime'];
      } else {
        rt = 'minutes'; // Default or calculate from stats
      }
    }

    return LivechatWorkspace(
      id: json['id'],
      name: json['name'],
      responseTime: rt,
      autoReplyMessage: json['autoReplyMessage'],
      autoReplyEnabled: json['autoReplyEnabled'] ?? false,
    );
  }
}
