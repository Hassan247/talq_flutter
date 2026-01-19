import 'package:graphql_flutter/graphql_flutter.dart';

import 'auth_manager.dart';

class LivechatClient {
  late GraphQLClient client;
  final String httpUrl;
  final String wsUrl;
  final String apiKey;

  LivechatClient({
    required this.httpUrl,
    required this.wsUrl,
    required this.apiKey,
  });

  /// Initializes the GraphQL client with proper links and authentication
  Future<void> init() async {
    final HttpLink httpLink = HttpLink(
      httpUrl,
      defaultHeaders: {'X-Api-Key': apiKey},
    );

    final AuthLink authLink = AuthLink(
      getToken: () async {
        final token = await AuthManager.getToken();
        return token != null ? 'Bearer $token' : null;
      },
    );

    final WebSocketLink wsLink = WebSocketLink(
      wsUrl,
      config: SocketClientConfig(
        autoReconnect: true,
        inactivityTimeout: const Duration(seconds: 30),
        initialPayload: () async {
          final token = await AuthManager.getToken();
          return token != null ? {'Authorization': 'Bearer $token'} : null;
        },
      ),
    );

    // Link split: Subscriptions go over WS, everything else over HTTP
    final Link link = Link.split(
      (request) => request.isSubscription,
      wsLink,
      authLink.concat(httpLink),
    );

    client = GraphQLClient(
      link: link,
      cache: GraphQLCache(store: InMemoryStore()),
    );
  }

  /// Helper to perform mutations
  Future<QueryResult> mutate(
    String document, {
    Map<String, dynamic>? variables,
  }) async {
    return await client.mutate(
      MutationOptions(document: gql(document), variables: variables ?? {}),
    );
  }

  /// Helper to perform queries
  Future<QueryResult> query(
    String document, {
    Map<String, dynamic>? variables,
  }) async {
    return await client.query(
      QueryOptions(
        document: gql(document),
        variables: variables ?? {},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );
  }

  /// Helper for subscriptions
  Stream<QueryResult> subscribe(
    String document, {
    Map<String, dynamic>? variables,
  }) {
    return client.subscribe(
      SubscriptionOptions(document: gql(document), variables: variables ?? {}),
    );
  }
}
