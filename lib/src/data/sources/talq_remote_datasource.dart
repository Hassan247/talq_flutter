import 'package:graphql_flutter/graphql_flutter.dart';

import '../../core/talq_client.dart';

class TalqRemoteDataSource {
  final TalqClient _client;

  TalqRemoteDataSource(this._client);

  Future<void> initializeClient() => _client.init();

  Future<QueryResult> query(
    String document, {
    Map<String, dynamic>? variables,
  }) {
    return _client.query(document, variables: variables);
  }

  Future<QueryResult> mutate(
    String document, {
    Map<String, dynamic>? variables,
  }) {
    return _client.mutate(document, variables: variables);
  }

  Stream<QueryResult> subscribe(
    String document, {
    Map<String, dynamic>? variables,
  }) {
    return _client.subscribe(document, variables: variables);
  }

  Future<String> uploadFile(String filePath) => _client.uploadFile(filePath);
}
