import 'package:graphql_flutter/graphql_flutter.dart';

class LivechatErrorMapper {
  static const String _defaultFallback =
      'Something went wrong. Please try again.';

  static String toUserMessage(
    Object? error, {
    String fallbackMessage = _defaultFallback,
  }) {
    final raw = _extractMessage(error);
    return _map(raw, fallbackMessage);
  }

  static String sanitizeText(
    String text, {
    String fallbackMessage = _defaultFallback,
  }) {
    return _map(text, fallbackMessage);
  }

  static bool isUnauthorized(Object? error) {
    final lower = _normalize(_extractMessage(error)).toLowerCase();
    return _containsAny(lower, const [
      'unauthorized',
      'unauthenticated',
      'not authenticated',
      'invalid token',
      'token expired',
      'jwt',
      '401',
    ]);
  }

  static String _extractMessage(Object? error) {
    if (error == null) return '';
    if (error is OperationException) {
      if (error.graphqlErrors.isNotEmpty) {
        final gql = error.graphqlErrors.first.message.trim();
        if (gql.isNotEmpty) return gql;
      }
      return error.linkException?.originalException?.toString() ??
          error.linkException?.toString() ??
          error.toString();
    }
    return error.toString();
  }

  static String _map(String raw, String fallbackMessage) {
    final normalized = _normalize(raw);
    if (normalized.isEmpty) return fallbackMessage;
    final lower = normalized.toLowerCase();

    if (_containsAny(lower, const ['cancelled', 'canceled'])) {
      return 'Action was cancelled.';
    }

    if (_containsAny(lower, const [
      'unable to load asset',
      'asset does not exist',
    ])) {
      return 'A required app asset is missing. Please update the app.';
    }

    if (_containsAny(lower, const [
      'payload too large',
      '413',
      'file too large',
      'exceeds',
    ])) {
      return 'This file is too large. Please choose a smaller file.';
    }

    if (_containsAny(lower, const [
      'unsupported file',
      'unsupported media type',
      'invalid file type',
      '415',
    ])) {
      return 'This file type is not supported.';
    }

    if (_containsAny(lower, const ['upload']) &&
        _containsAny(lower, const ['forbidden', 'unauthorized', '403'])) {
      return 'You do not have permission to upload files here.';
    }

    if (_containsAny(lower, const [
      'forbidden',
      'permission denied',
      'not allowed',
      '403',
    ])) {
      return 'You do not have permission to perform this action.';
    }

    if (isUnauthorized(raw)) {
      return 'Your session expired. Please reopen chat and try again.';
    }

    if (_containsAny(lower, const ['timed out', 'timeout', 'deadline exceeded'])) {
      return 'Request timed out. Please try again.';
    }

    if (_containsAny(lower, const [
      'connection refused',
      'failed host lookup',
      'socketexception',
      'network is unreachable',
      'network request failed',
      'connection reset',
      'no internet',
    ])) {
      return 'Unable to connect. Check your internet and try again.';
    }

    if (_containsAny(lower, const [
      'internal server error',
      'server error',
      'service unavailable',
      'bad gateway',
      'gateway timeout',
      '500',
      '502',
      '503',
      '504',
    ])) {
      return 'Server is temporarily unavailable. Please try again shortly.';
    }

    if (_containsAny(lower, const ['too many requests', 'rate limit', '429'])) {
      return 'Too many requests. Please wait a moment and try again.';
    }

    if (_containsAny(lower, const ['not found', '404'])) {
      return 'Requested information was not found.';
    }

    if (_containsAny(lower, const ['upload'])) {
      return 'Unable to upload file right now. Please try again.';
    }

    if (_looksUserFriendly(normalized)) {
      return normalized;
    }

    return fallbackMessage;
  }

  static String _normalize(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return '';

    text = text.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    text = text.replaceFirst(RegExp(r'^error:\s*', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }

  static bool _looksUserFriendly(String text) {
    if (text.isEmpty || text.length > 180) return false;
    final lower = text.toLowerCase();

    if (_containsAny(lower, const [
      'operationexception',
      'linkexception',
      'unknownexception',
      'graphqlerrors',
      'stack:',
      'failed assertion',
      'rendering',
      'input.isfinite',
      'parentdatadirty',
      'typeerror',
    ])) {
      return false;
    }

    if (text.contains('{') || text.contains('[') || text.contains(']')) {
      return false;
    }

    return true;
  }

  static bool _containsAny(String source, List<String> needles) {
    for (final needle in needles) {
      if (source.contains(needle)) return true;
    }
    return false;
  }
}
