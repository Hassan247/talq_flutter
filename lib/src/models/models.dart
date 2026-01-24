enum SenderType { visitor, agent, system }

enum ContentType { text, image, pdf }

class LivechatMessage {
  final String id;
  final String content;
  final SenderType senderType;
  final ContentType contentType;
  final String? fileUrl;
  final String? fileName;
  final DateTime createdAt;
  final bool isRead;

  LivechatMessage({
    required this.id,
    required this.content,
    required this.senderType,
    this.contentType = ContentType.text,
    this.fileUrl,
    this.fileName,
    required this.createdAt,
    this.isRead = false,
  });

  factory LivechatMessage.fromJson(Map<String, dynamic> json) {
    return LivechatMessage(
      id: json['id'],
      content: json['content'],
      senderType: _parseSenderType(json['senderType']),
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
