import 'dart:convert';

import 'package:flutter/foundation.dart';

enum SenderType {
  visitor,
  agent,
  system,
  bot;

  static SenderType fromString(String? type) {
    switch (type) {
      case 'AGENT':
        return SenderType.agent;
      case 'SYSTEM':
        return SenderType.system;
      case 'BOT':
        return SenderType.bot;
      default:
        return SenderType.visitor;
    }
  }

  String toJson() => name.toUpperCase();
}

enum ContentType {
  text,
  image,
  pdf;

  static ContentType fromString(String? type) {
    switch (type) {
      case 'IMAGE':
        return ContentType.image;
      case 'PDF':
        return ContentType.pdf;
      default:
        return ContentType.text;
    }
  }

  String toJson() => name.toUpperCase();
}

enum RoomStatus {
  open,
  assigned,
  resolved,
  closed;

  static RoomStatus fromString(String? status) {
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

  String toJson() => name.toUpperCase();
}

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
  final bool isDelivered;
  final LivechatMessage? replyTo;
  final Map<String, dynamic> reactions;

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
    this.isDelivered = false,
    this.replyTo,
    this.reactions = const {},
  });

  factory LivechatMessage.fromJson(Map<String, dynamic> json) {
    try {
      return LivechatMessage(
        id: json['id'] ?? 'unknown',
        roomId: json['room'] != null ? json['room']['id'] : null,
        content: json['content'] ?? '',
        senderType: SenderType.fromString(json['senderType']),
        senderName: json['senderName'],
        senderAvatarUrl: json['senderAvatarUrl'],
        contentType: ContentType.fromString(json['contentType']),
        fileUrl: json['fileUrl'],
        fileName: json['fileName'],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : DateTime.now(),
        isRead: json['read'] ?? false,
        isDelivered: json['delivered'] ?? false,
        replyTo: json['replyTo'] != null
            ? LivechatMessage.fromJson(json['replyTo'])
            : null,
        reactions: json['reactions'] != null
            ? Map<String, dynamic>.from(
                json['reactions'] is String
                    ? _safeJsonDecode(json['reactions'])
                    : json['reactions'],
              )
            : {},
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing LivechatMessage: $e. Data: $json');
      }
      return LivechatMessage(
        id: 'err-${json['id'] ?? DateTime.now().millisecondsSinceEpoch}',
        content: 'Message parsing error',
        senderType: SenderType.system,
        createdAt: DateTime.now(),
      );
    }
  }

  bool get isMe => senderType == SenderType.visitor;
  bool get isSystem => senderType == SenderType.system;
  bool get isBot => senderType == SenderType.bot;

  String get displaySenderName {
    if (isMe) return 'You';
    return senderName ?? (isBot ? 'Bot' : 'Support');
  }

  String get previewText {
    if (contentType == ContentType.image) return 'Photo';
    if (contentType == ContentType.pdf) return 'Document';
    return content;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'senderType': senderType.toJson(),
      'senderName': senderName,
      'senderAvatarUrl': senderAvatarUrl,
      'contentType': contentType.toJson(),
      'fileUrl': fileUrl,
      'fileName': fileName,
      'createdAt': createdAt.toIso8601String(),
      'read': isRead,
      'delivered': isDelivered,
    };
  }

  static dynamic _safeJsonDecode(String str) {
    try {
      return json.decode(str);
    } catch (_) {
      return {};
    }
  }
}

class LivechatVisitor {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? currentPage;

  LivechatVisitor({
    required this.id,
    this.firstName,
    this.lastName,
    this.email,
    this.currentPage,
  });

  factory LivechatVisitor.fromJson(Map<String, dynamic> json) {
    return LivechatVisitor(
      id: json['id'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      email: json['email'],
      currentPage: json['currentPage'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'currentPage': currentPage,
  };

  LivechatVisitor copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? currentPage,
  }) {
    return LivechatVisitor(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class LivechatRoom {
  final String id;
  final RoomStatus status;
  final int unreadCount;
  final int visitorUnreadCount;
  final DateTime? lastMessageAt;
  final LivechatMessage? lastMessage;
  final DateTime createdAt;
  final int? rating;
  final String? ratingComment;
  final String? assigneeName;
  final String? assigneeAvatarUrl;

  LivechatRoom({
    required this.id,
    required this.status,
    this.unreadCount = 0,
    this.visitorUnreadCount = 0,
    this.lastMessageAt,
    this.lastMessage,
    required this.createdAt,
    this.rating,
    this.ratingComment,
    this.assigneeName,
    this.assigneeAvatarUrl,
  });

  factory LivechatRoom.fromJson(Map<String, dynamic> json) {
    return LivechatRoom(
      id: json['id'] ?? '',
      status: RoomStatus.fromString(json['status']?.toString()),
      unreadCount: json['unreadCount'] ?? 0,
      visitorUnreadCount: json['visitorUnreadCount'] ?? 0,
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'].toString())
          : null,
      lastMessage: json['lastMessage'] != null
          ? LivechatMessage.fromJson(json['lastMessage'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      rating: json['rating'],
      ratingComment: json['ratingComment'],
      assigneeName: json['assignee'] != null
          ? '${json['assignee']['firstName'] ?? ''} ${json['assignee']['lastName'] ?? ''}'
          : null,
      assigneeAvatarUrl: json['assignee'] != null
          ? json['assignee']['avatarUrl']
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status.toJson(),
    'unreadCount': unreadCount,
    'visitorUnreadCount': visitorUnreadCount,
    'lastMessageAt': lastMessageAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };
}

class LivechatWorkspace {
  final String id;
  final String name;
  final String? responseTime;
  final bool showResponseTime;
  final String? autoReplyMessage;
  final bool autoReplyEnabled;
  final List<String> agentAvatars;
  final String? logoUrl;
  final String? livechatLogoUrl;
  final String welcomeMessage;
  final String primaryColor;

  LivechatWorkspace({
    required this.id,
    required this.name,
    this.responseTime,
    this.showResponseTime = true,
    this.autoReplyMessage,
    this.autoReplyEnabled = false,
    this.agentAvatars = const [],
    this.logoUrl,
    this.livechatLogoUrl,
    this.welcomeMessage = 'Hello there! How can we help you today?',
    this.primaryColor = '#151515',
  });

  factory LivechatWorkspace.fromJson(Map<String, dynamic> json) {
    String? rt;
    if (json['showResponseTime'] == true) {
      // use customResponseTime if available (for both AGENT and CUSTOM types)
      // the backend populates this field dynamically for AGENT type
      if (json['customResponseTime'] != null &&
          json['customResponseTime'].toString().isNotEmpty) {
        rt = json['customResponseTime'];
      } else {
        // fallback to a reasonable default
        rt = 'A few minutes';
      }
    }

    return LivechatWorkspace(
      id: json['id'],
      name: json['name'],
      responseTime: rt,
      showResponseTime: json['showResponseTime'] ?? true,
      autoReplyMessage: json['autoReplyMessage'],
      autoReplyEnabled: json['autoReplyEnabled'] ?? false,
      // agentAvatars is typically populated from the parent payload, not the workspace object itself
      // but if the backend ever adds it to workspace, we can parse it here.
      // For now, default to empty.
      logoUrl: json['logoUrl'],
      livechatLogoUrl: json['livechatLogoUrl'],
      welcomeMessage:
          json['welcomeMessage'] ?? 'Hello there! How can we help you today?',
      primaryColor: json['primaryColor'] ?? '#151515',
    );
  }

  LivechatWorkspace copyWith({
    String? id,
    String? name,
    String? responseTime,
    bool? showResponseTime,
    String? autoReplyMessage,
    bool? autoReplyEnabled,
    List<String>? agentAvatars,
    String? logoUrl,
    String? livechatLogoUrl,
    String? welcomeMessage,
    String? primaryColor,
  }) {
    return LivechatWorkspace(
      id: id ?? this.id,
      name: name ?? this.name,
      responseTime: responseTime ?? this.responseTime,
      showResponseTime: showResponseTime ?? this.showResponseTime,
      autoReplyMessage: autoReplyMessage ?? this.autoReplyMessage,
      autoReplyEnabled: autoReplyEnabled ?? this.autoReplyEnabled,
      agentAvatars: agentAvatars ?? this.agentAvatars,
      logoUrl: logoUrl ?? this.logoUrl,
      livechatLogoUrl: livechatLogoUrl ?? this.livechatLogoUrl,
      welcomeMessage: welcomeMessage ?? this.welcomeMessage,
      primaryColor: primaryColor ?? this.primaryColor,
    );
  }
}

class LivechatFAQ {
  final String id;
  final String question;
  final String answer;
  final int sortOrder;

  LivechatFAQ({
    required this.id,
    required this.question,
    required this.answer,
    required this.sortOrder,
  });

  factory LivechatFAQ.fromJson(Map<String, dynamic> json) {
    return LivechatFAQ(
      id: json['id'],
      question: json['question'],
      answer: json['answer'],
      sortOrder: json['sortOrder'] ?? 0,
    );
  }
}

class FAQConnection {
  final List<LivechatFAQ> faqs;
  final bool hasNextPage;
  final String? endCursor;
  final int totalCount;

  FAQConnection({
    required this.faqs,
    required this.hasNextPage,
    this.endCursor,
    required this.totalCount,
  });

  factory FAQConnection.fromJson(Map<String, dynamic> json) {
    final edges = json['edges'] as List? ?? [];
    final pageInfo = json['pageInfo'] ?? {};

    return FAQConnection(
      faqs: edges.map((e) => LivechatFAQ.fromJson(e['node'])).toList(),
      hasNextPage: pageInfo['hasNextPage'] ?? false,
      endCursor: pageInfo['endCursor'],
      totalCount: json['totalCount'] ?? 0,
    );
  }
}
