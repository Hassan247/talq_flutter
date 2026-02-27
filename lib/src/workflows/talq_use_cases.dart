import 'package:graphql_flutter/graphql_flutter.dart';

import '../core/talq_client.dart';
import '../data/repositories/talq_repository.dart';
import '../data/sources/talq_remote_datasource.dart';
import '../models/models.dart';

class TalqUseCases {
  final TalqRepository _repository;

  TalqUseCases(this._repository);

  factory TalqUseCases.fromClient(TalqClient client) {
    final remote = TalqRemoteDataSource(client);
    final repository = TalqRepository(remote);
    return TalqUseCases(repository);
  }

  Future<void> initializeClient() => _repository.initializeClient();

  Future<String> uploadFile(String filePath) =>
      _repository.uploadFile(filePath);

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
    return _repository.initVisitor(
      deviceId: deviceId,
      platform: platform,
      firstName: firstName,
      lastName: lastName,
      email: email,
      metadata: metadata,
      pushToken: pushToken,
      deviceInfo: deviceInfo,
    );
  }

  Future<QueryResult> startNewConversation() {
    return _repository.startNewConversation();
  }

  Future<QueryResult> fetchRooms() => _repository.fetchRooms();

  Future<QueryResult> fetchRoomMessages({
    required String roomId,
    String? afterCursor,
  }) {
    return _repository.fetchRoomMessages(
      roomId: roomId,
      afterCursor: afterCursor,
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
    return _repository.sendVisitorMessage(
      roomId: roomId,
      content: content,
      contentType: contentType,
      fileUrl: fileUrl,
      fileName: fileName,
      replyToId: replyToId,
    );
  }

  Future<QueryResult> sendTyping(String roomId) =>
      _repository.sendTyping(roomId);

  Future<QueryResult> updateVisitorPage({
    required String roomId,
    required String page,
  }) {
    return _repository.updateVisitorPage(roomId: roomId, page: page);
  }

  Future<QueryResult> markMessagesAsRead(String roomId) {
    return _repository.markMessagesAsRead(roomId);
  }

  Future<QueryResult> markMessagesAsDelivered(String roomId) {
    return _repository.markMessagesAsDelivered(roomId);
  }

  Stream<QueryResult> subscribeVisitorNewMessage() {
    return _repository.subscribeVisitorNewMessage();
  }

  Stream<QueryResult> subscribeVisitorRoomUpdated() {
    return _repository.subscribeVisitorRoomUpdated();
  }

  Stream<QueryResult> subscribeVisitorWorkspaceUpdated() {
    return _repository.subscribeVisitorWorkspaceUpdated();
  }

  Stream<QueryResult> subscribeTyping(String roomId) {
    return _repository.subscribeTyping(roomId);
  }

  Future<QueryResult> rateRoom({
    required String roomId,
    required int rating,
    String? comment,
  }) {
    return _repository.rateRoom(
      roomId: roomId,
      rating: rating,
      comment: comment,
    );
  }

  Future<QueryResult> voteFaq({required String faqId, required bool helpful}) {
    return _repository.voteFaq(faqId: faqId, helpful: helpful);
  }

  Future<QueryResult> fetchRoomStatus(String roomId) {
    return _repository.fetchRoomStatus(roomId);
  }

  Future<QueryResult> addReaction({
    required String messageId,
    required String emoji,
  }) {
    return _repository.addReaction(messageId: messageId, emoji: emoji);
  }

  Future<QueryResult> removeReaction({
    required String messageId,
    required String emoji,
  }) {
    return _repository.removeReaction(messageId: messageId, emoji: emoji);
  }

  Future<QueryResult> fetchVisitorFaqs({
    String? query,
    int first = 20,
    String? afterCursor,
  }) {
    return _repository.fetchVisitorFaqs(
      query: query,
      first: first,
      afterCursor: afterCursor,
    );
  }
}
