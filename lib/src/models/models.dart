enum SenderType { visitor, agent, system }

class LivechatMessage {
  final String id;
  final String content;
  final SenderType senderType;
  final DateTime createdAt;
  final bool isRead;

  LivechatMessage({
    required this.id,
    required this.content,
    required this.senderType,
    required this.createdAt,
    this.isRead = false,
  });

  factory LivechatMessage.fromJson(Map<String, dynamic> json) {
    return LivechatMessage(
      id: json['id'],
      content: json['content'],
      senderType: _parseSenderType(json['senderType']),
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
}

class LivechatVisitor {
  final String id;
  final String? name;
  final String? email;

  LivechatVisitor({required this.id, this.name, this.email});

  factory LivechatVisitor.fromJson(Map<String, dynamic> json) {
    return LivechatVisitor(
      id: json['id'],
      name: json['name'],
      email: json['email'],
    );
  }
}
