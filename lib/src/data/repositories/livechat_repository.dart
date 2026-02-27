import 'package:graphql_flutter/graphql_flutter.dart';

import '../../models/models.dart';
import '../sources/livechat_remote_datasource.dart';
import 'livechat_graphql_documents.dart';

class LivechatRepository {
  final LivechatRemoteDataSource _remote;

  LivechatRepository(this._remote);

  Future<void> initializeClient() => _remote.initializeClient();

  Future<String> uploadFile(String filePath) => _remote.uploadFile(filePath);

  Future<QueryResult> initVisitor({
    required String deviceId,
    required String platform,
    String? firstName,
    String? lastName,
    String? email,
    Map<String, dynamic>? metadata,
    String? pushToken,
    Map<String, dynamic>? deviceInfo,
  }) {
    return _remote.mutate(
      LivechatGraphqlDocuments.initVisitorMutation,
      variables: {
        'input': {
          'deviceId': deviceId,
          'platform': platform,
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
          if (pushToken != null && pushToken.isNotEmpty) 'pushToken': pushToken,
          if (deviceInfo != null && deviceInfo.isNotEmpty)
            'deviceInfo': deviceInfo,
        },
      },
    );
  }

  Future<QueryResult> startNewConversation() {
    return _remote.mutate(
      LivechatGraphqlDocuments.startNewConversationMutation,
    );
  }

  Future<QueryResult> fetchRooms() {
    return _remote.query(LivechatGraphqlDocuments.visitorRoomsQuery);
  }

  Future<QueryResult> fetchRoomMessages({
    required String roomId,
    String? afterCursor,
  }) {
    return _remote.query(
      LivechatGraphqlDocuments.roomWithMessagesQuery,
      variables: {'roomId': roomId, 'after': afterCursor},
    );
  }

  Future<QueryResult> sendVisitorMessage({
    required String? roomId,
    required String content,
    required ContentType contentType,
    String? fileUrl,
    String? fileName,
    String? replyToId,
  }) {
    return _remote.mutate(
      LivechatGraphqlDocuments.sendVisitorMessageMutation,
      variables: {
        'input': {
          'roomId': roomId,
          'content': content,
          'contentType': _contentTypeToGql(contentType),
          'fileUrl': fileUrl,
          'fileName': fileName,
          'replyToId': replyToId,
        },
      },
    );
  }

  Future<QueryResult> sendTyping(String roomId) {
    return _remote.mutate(
      LivechatGraphqlDocuments.visitorTypingMutation,
      variables: {'roomId': roomId},
    );
  }

  Future<QueryResult> updateVisitorPage({
    required String roomId,
    required String page,
  }) {
    return _remote.mutate(
      LivechatGraphqlDocuments.updateVisitorPageMutation,
      variables: {'roomId': roomId, 'page': page},
    );
  }

  Future<QueryResult> markMessagesAsRead(String roomId) {
    return _remote.mutate(
      LivechatGraphqlDocuments.markMessagesAsReadMutation,
      variables: {'roomId': roomId},
    );
  }

  Future<QueryResult> markMessagesAsDelivered(String roomId) {
    return _remote.mutate(
      LivechatGraphqlDocuments.markMessagesAsDeliveredMutation,
      variables: {'roomId': roomId},
    );
  }

  Stream<QueryResult> subscribeVisitorNewMessage() {
    return _remote.subscribe(
      LivechatGraphqlDocuments.visitorNewMessageSubscription,
    );
  }

  Stream<QueryResult> subscribeVisitorRoomUpdated() {
    return _remote.subscribe(
      LivechatGraphqlDocuments.visitorRoomUpdatedSubscription,
    );
  }

  Stream<QueryResult> subscribeVisitorWorkspaceUpdated() {
    return _remote.subscribe(
      LivechatGraphqlDocuments.visitorWorkspaceUpdatedSubscription,
    );
  }

  Stream<QueryResult> subscribeTyping(String roomId) {
    return _remote.subscribe(
      LivechatGraphqlDocuments.typingSubscription,
      variables: {'roomId': roomId},
    );
  }

  Future<QueryResult> rateRoom({
    required String roomId,
    required int rating,
    String? comment,
  }) {
    return _remote.mutate(
      LivechatGraphqlDocuments.rateRoomMutation,
      variables: {'roomId': roomId, 'rating': rating, 'comment': comment},
    );
  }

  Future<QueryResult> voteFaq({required String faqId, required bool helpful}) {
    return _remote.mutate(
      LivechatGraphqlDocuments.voteFaqMutation,
      variables: {'id': faqId, 'helpful': helpful},
    );
  }

  Future<QueryResult> fetchRoomStatus(String roomId) {
    return _remote.query(
      LivechatGraphqlDocuments.roomStatusQuery,
      variables: {'id': roomId},
    );
  }

  Future<QueryResult> addReaction({
    required String messageId,
    required String emoji,
  }) {
    return _remote.mutate(
      LivechatGraphqlDocuments.addReactionMutation,
      variables: {'messageId': messageId, 'emoji': emoji},
    );
  }

  Future<QueryResult> removeReaction({
    required String messageId,
    required String emoji,
  }) {
    return _remote.mutate(
      LivechatGraphqlDocuments.removeReactionMutation,
      variables: {'messageId': messageId, 'emoji': emoji},
    );
  }

  Future<QueryResult> fetchVisitorFaqs({
    String? query,
    int first = 20,
    String? afterCursor,
  }) {
    return _remote.query(
      LivechatGraphqlDocuments.visitorFaqsQuery,
      variables: {'query': query, 'first': first, 'after': afterCursor},
    );
  }

  String _contentTypeToGql(ContentType contentType) {
    switch (contentType) {
      case ContentType.image:
        return 'IMAGE';
      case ContentType.pdf:
        return 'PDF';
      case ContentType.text:
        return 'TEXT';
    }
  }
}
