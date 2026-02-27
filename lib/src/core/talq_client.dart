import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import 'auth_manager.dart';

class TalqClient {
  static const Duration _connectTimeout = Duration(seconds: 15);
  static const Duration _sendTimeout = Duration(seconds: 30);
  static const Duration _receiveTimeout = Duration(seconds: 30);
  static const String _defaultHttpUrl = String.fromEnvironment(
    'TALQ_SDK_HTTP_URL',
    defaultValue: 'https://api.talq.app/graphql',
  );
  static const String _defaultWsUrl = String.fromEnvironment(
    'TALQ_SDK_WS_URL',
    defaultValue: 'wss://api.talq.app/graphql',
  );

  static final Dio _downloadDio = Dio(
    BaseOptions(
      connectTimeout: _connectTimeout,
      sendTimeout: _sendTimeout,
      receiveTimeout: _receiveTimeout,
    ),
  );

  late GraphQLClient client;
  final Dio _dio;
  final http.Client _graphqlHttpClient;
  final String httpUrl;
  final String wsUrl;
  final String apiKey;

  TalqClient({
    required String apiKey,
    String? httpUrl,
    String? wsUrl,
  }) : apiKey = _requireNonEmpty(apiKey, 'apiKey'),
       httpUrl = _resolveEndpoint(httpUrl, _defaultHttpUrl, 'httpUrl'),
       wsUrl = _resolveEndpoint(wsUrl, _defaultWsUrl, 'wsUrl'),
       _dio = Dio(
         BaseOptions(
           connectTimeout: _connectTimeout,
           sendTimeout: _sendTimeout,
           receiveTimeout: _receiveTimeout,
         ),
       ),
       _graphqlHttpClient = _TimeoutHttpClient(timeout: _receiveTimeout) {
    _configureDio();
  }

  static String _requireNonEmpty(String value, String label) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, label, 'must not be empty');
    }
    return normalized;
  }

  static String _resolveEndpoint(
    String? override,
    String fallback,
    String label,
  ) {
    final normalized = (override ?? fallback).trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(override, label, 'must not be empty');
    }
    return normalized;
  }

  void _configureDio() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.headers['X-Api-Key'] = apiKey;
          final token = await AuthManager.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          } else {
            options.headers.remove('Authorization');
          }
          handler.next(options);
        },
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: false,
          requestBody: false,
          responseHeader: false,
          responseBody: false,
          error: true,
        ),
      );
    }
  }

  /// Initializes the GraphQL client with proper links and authentication
  Future<void> init() async {
    final HttpLink httpLink = HttpLink(
      httpUrl,
      defaultHeaders: {'X-Api-Key': apiKey},
      httpClient: _graphqlHttpClient,
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

  Future<String> uploadFile(String filePath) async {
    final uploadUrl = Uri.parse(
      httpUrl,
    ).replace(path: '/upload', query: null).toString();

    final response = await _dio.post<Map<String, dynamic>>(
      uploadUrl,
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: path.basename(filePath),
        ),
      }),
      options: Options(
        contentType: 'multipart/form-data',
        responseType: ResponseType.json,
      ),
    );

    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      throw HttpException('Upload failed with status code $statusCode');
    }

    final fileUrl = response.data?['url']?.toString();
    if (fileUrl == null || fileUrl.isEmpty) {
      throw const FormatException('Upload response is missing a file URL.');
    }
    return fileUrl;
  }

  static Future<List<int>> downloadBytes(String url) async {
    final response = await _downloadDio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );

    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      throw HttpException('Download failed with status code $statusCode');
    }

    return response.data ?? const <int>[];
  }
}

class _TimeoutHttpClient extends http.BaseClient {
  final Duration timeout;
  final http.Client _innerClient;

  _TimeoutHttpClient({required this.timeout, http.Client? innerClient})
    : _innerClient = innerClient ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _innerClient.send(request).timeout(timeout);
  }

  @override
  void close() {
    _innerClient.close();
  }
}
