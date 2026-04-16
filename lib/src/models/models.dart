import 'dart:convert';

import 'package:flutter/foundation.dart';

enum SenderType {
  visitor,
  agent,
  system,
  bot;

  static SenderType fromString(String? type) {
    final t = type?.toUpperCase();
    switch (t) {
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

class TalqMessage {
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
  final TalqMessage? replyTo;
  final Map<String, dynamic> reactions;
  final String? localFilePath;
  final bool isUploading;

  TalqMessage({
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
    this.localFilePath,
    this.isUploading = false,
  });

  factory TalqMessage.fromJson(Map<String, dynamic> json) {
    try {
      return TalqMessage(
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
            ? TalqMessage.fromJson(json['replyTo'])
            : null,
        reactions: json['reactions'] != null
            ? Map<String, dynamic>.from(
                json['reactions'] is String
                    ? _safeJsonDecode(json['reactions'])
                    : json['reactions'],
              )
            : {},
        localFilePath: json['localFilePath'],
        isUploading: json['isUploading'] ?? false,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error parsing TalqMessage: $e');
      }
      return TalqMessage(
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

  TalqMessage copyWith({
    String? id,
    String? content,
    String? fileUrl,
    String? fileName,
    bool? isRead,
    bool? isDelivered,
    String? localFilePath,
    bool? isUploading,
    Map<String, dynamic>? reactions,
  }) {
    return TalqMessage(
      id: id ?? this.id,
      roomId: roomId,
      content: content ?? this.content,
      senderType: senderType,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
      contentType: contentType,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      isDelivered: isDelivered ?? this.isDelivered,
      replyTo: replyTo,
      reactions: reactions ?? this.reactions,
      localFilePath: localFilePath ?? this.localFilePath,
      isUploading: isUploading ?? this.isUploading,
    );
  }
}

class TalqVisitor {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? currentPage;

  TalqVisitor({
    required this.id,
    this.firstName,
    this.lastName,
    this.email,
    this.currentPage,
  });

  factory TalqVisitor.fromJson(Map<String, dynamic> json) {
    return TalqVisitor(
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

  TalqVisitor copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? currentPage,
  }) {
    return TalqVisitor(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class TalqRoom {
  final String id;
  final RoomStatus status;
  final int unreadCount;
  final int visitorUnreadCount;
  final DateTime? lastMessageAt;
  final TalqMessage? lastMessage;
  final DateTime createdAt;
  final int? rating;
  final String? ratingComment;
  final String? assigneeName;
  final String? assigneeAvatarUrl;

  TalqRoom({
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

  factory TalqRoom.fromJson(Map<String, dynamic> json) {
    return TalqRoom(
      id: json['id'] ?? '',
      status: RoomStatus.fromString(json['status']?.toString()),
      unreadCount: json['unreadCount'] ?? 0,
      visitorUnreadCount: json['visitorUnreadCount'] ?? 0,
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'].toString())
          : null,
      lastMessage: json['lastMessage'] != null
          ? TalqMessage.fromJson(json['lastMessage'])
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

  TalqRoom copyWith({
    String? id,
    RoomStatus? status,
    int? unreadCount,
    int? visitorUnreadCount,
    DateTime? lastMessageAt,
    TalqMessage? lastMessage,
    DateTime? createdAt,
    int? rating,
    String? ratingComment,
    String? assigneeName,
    String? assigneeAvatarUrl,
  }) {
    return TalqRoom(
      id: id ?? this.id,
      status: status ?? this.status,
      unreadCount: unreadCount ?? this.unreadCount,
      visitorUnreadCount: visitorUnreadCount ?? this.visitorUnreadCount,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessage: lastMessage ?? this.lastMessage,
      createdAt: createdAt ?? this.createdAt,
      rating: rating ?? this.rating,
      ratingComment: ratingComment ?? this.ratingComment,
      assigneeName: assigneeName ?? this.assigneeName,
      assigneeAvatarUrl: assigneeAvatarUrl ?? this.assigneeAvatarUrl,
    );
  }
}

class TalqWorkspace {
  final String id;
  final String name;
  final String? responseTime;
  final bool showResponseTime;
  final String? autoReplyMessage;
  final bool autoReplyEnabled;
  final List<String> agentAvatars;
  final String? logoUrl;
  final String? talqLogoUrl;
  final String welcomeMessage;
  final String primaryColor;

  TalqWorkspace({
    required this.id,
    required this.name,
    this.responseTime,
    this.showResponseTime = true,
    this.autoReplyMessage,
    this.autoReplyEnabled = false,
    this.agentAvatars = const [],
    this.logoUrl,
    this.talqLogoUrl,
    this.welcomeMessage = 'Hello there! How can we help you today?',
    this.primaryColor = '#151515',
  });

  factory TalqWorkspace.fromJson(Map<String, dynamic> json) {
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

    return TalqWorkspace(
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
      talqLogoUrl: json['talqLogoUrl'],
      welcomeMessage:
          json['welcomeMessage'] ?? 'Hello there! How can we help you today?',
      primaryColor: json['primaryColor'] ?? '#151515',
    );
  }

  TalqWorkspace copyWith({
    String? id,
    String? name,
    String? responseTime,
    bool? showResponseTime,
    String? autoReplyMessage,
    bool? autoReplyEnabled,
    List<String>? agentAvatars,
    String? logoUrl,
    String? talqLogoUrl,
    String? welcomeMessage,
    String? primaryColor,
  }) {
    return TalqWorkspace(
      id: id ?? this.id,
      name: name ?? this.name,
      responseTime: responseTime ?? this.responseTime,
      showResponseTime: showResponseTime ?? this.showResponseTime,
      autoReplyMessage: autoReplyMessage ?? this.autoReplyMessage,
      autoReplyEnabled: autoReplyEnabled ?? this.autoReplyEnabled,
      agentAvatars: agentAvatars ?? this.agentAvatars,
      logoUrl: logoUrl ?? this.logoUrl,
      talqLogoUrl: talqLogoUrl ?? this.talqLogoUrl,
      welcomeMessage: welcomeMessage ?? this.welcomeMessage,
      primaryColor: primaryColor ?? this.primaryColor,
    );
  }
}

class TalqFAQ {
  final String id;
  final String question;
  final String answer;
  final int sortOrder;

  TalqFAQ({
    required this.id,
    required this.question,
    required this.answer,
    required this.sortOrder,
  });

  factory TalqFAQ.fromJson(Map<String, dynamic> json) {
    return TalqFAQ(
      id: json['id'],
      question: json['question'],
      answer: json['answer'],
      sortOrder: json['sortOrder'] ?? 0,
    );
  }
}

class FAQConnection {
  final List<TalqFAQ> faqs;
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
      faqs: edges.map((e) => TalqFAQ.fromJson(e['node'])).toList(),
      hasNextPage: pageInfo['hasNextPage'] ?? false,
      endCursor: pageInfo['endCursor'],
      totalCount: json['totalCount'] ?? 0,
    );
  }
}
