import 'dart:convert';

import 'package:dio/dio.dart';

extension DioExceptionX on DioException {
  String get userMessage {
    switch (type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet.';
      case DioExceptionType.badResponse:
        final statusCode = response?.statusCode;
        if (statusCode == 401) return 'Unauthorized. Please log in again.';
        if (statusCode == 404) return 'Resource not found.';
        if (statusCode != null && statusCode >= 500) {
          return 'Server error (Status $statusCode).';
        }
        return 'Request failed with status $statusCode.';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      case DioExceptionType.unknown:
        return 'An unexpected error occurred.';
      default:
        return 'Request failed.';
    }
  }

  String toDebugString() {
    final buffer = StringBuffer();
    buffer.writeln('🚨 [DioException] ${type.name}');
    buffer.writeln('📤 Request: ${requestOptions.method} ${requestOptions.uri}');
    if (response != null) {
      buffer.writeln('📥 Response: ${response!.statusCode}');
      if (response!.data != null) {
        buffer.writeln('   Body: ${_formatData(response!.data)}');
      }
    } else if (error != null) {
      buffer.writeln('⚠️ Error: ${error.toString()}');
    }
    return buffer.toString().trim();
  }

  String _formatData(dynamic data) {
    if (data == null) return 'null';
    if (data is Map || data is List) {
      try {
        const encoder = JsonEncoder.withIndent('   ');
        return encoder.convert(data);
      } catch (_) {
        return data.toString();
      }
    }
    return data.toString();
  }
}

extension DiscordDioException on DioException {
  /// Generates a Markdown formatted error report suitable for Discord messages.
  String toDiscordMarkdown() {
    final emoji = _getEmoji();
    final title = _getFriendlyTitle();
    final message = userMessage;

    final buffer = StringBuffer();
    buffer.writeln('$emoji **$title**');
    buffer.writeln();
    buffer.writeln(message);
    buffer.writeln();
    buffer.writeln('`${requestOptions.method} ${requestOptions.uri}`');
    buffer.writeln();

    // Technical details
    buffer.writeln('```yaml');
    buffer.writeln('Type: ${type.name}');
    if (response != null) {
      buffer.writeln('Status: ${response!.statusCode}');
    }
    if (error != null) {
      final errorStr = error.toString();
      buffer.writeln('Error: ${errorStr.length > 200 ? '${errorStr.substring(0, 200)}...' : errorStr}');
    }
    buffer.writeln('```');

    // Ensure whole message fits in Discord's 2000‑char limit
    var result = buffer.toString().trim();
    const maxLength = 2000;
    if (result.length > maxLength) {
      result = '${result.substring(0, maxLength - 3)}...';
    }
    return result;
  }

  /// Human‑readable message, enhanced with the server’s own error message if available.
  String get userMessage {
    print("Server message: ${response?.data}");
    final base = _baseUserMessage();
    final server = _getServerMessage();
    if (server == null || server.isEmpty) return base;
    if (base.contains(server)) return base; // avoid duplication
    return '$base — $server';
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  String _baseUserMessage() {
    switch (type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The connection timed out.';

      case DioExceptionType.connectionError:
        final errorStr = error?.toString().toLowerCase() ?? '';
        if (errorStr.contains('semaphore timeout') || errorStr.contains('timed out')) {
          return 'Connection timed out. The server took too long to respond.';
        }
        if (errorStr.contains('connection refused')) {
          return 'Connection refused. The server is likely offline.';
        }
        if (errorStr.contains('failed host lookup')) {
          return 'DNS Lookup Failed. Could not reach the host.';
        }
        return 'A network connection error occurred.';

      case DioExceptionType.badResponse:
        final statusCode = response?.statusCode;
        // Common client errors
        if (statusCode == 400) return 'Bad Request (400).';
        if (statusCode == 401) return 'Unauthorized (401). Authentication failed.';
        if (statusCode == 403) return 'Forbidden (403). You lack permission.';
        if (statusCode == 404) return 'Not Found (404). The resource does not exist.';
        if (statusCode == 422) return 'Validation Error (422). Some fields are invalid.';
        if (statusCode == 429) return 'Too Many Requests (429). You are being rate‑limited.';
        // Server errors
        if (statusCode != null && statusCode >= 500) {
          if (statusCode == 503) return 'Service Unavailable (503).';
          return 'Server Error ($statusCode). Please try again later.';
        }
        return 'Request failed with status $statusCode.';

      case DioExceptionType.cancel:
        return 'The request was cancelled.';

      case DioExceptionType.unknown:
        final errorStr = error?.toString().toLowerCase() ?? '';
        if (errorStr.contains('socketexception')) {
          if (errorStr.contains('connection refused')) return 'Server connection refused.';
          if (errorStr.contains('failed host lookup')) return 'Could not find the server address.';
          if (errorStr.contains('semaphore timeout')) return 'Network timeout.';
          return 'Network connection unstable.';
        }
        return 'An unexpected error occurred.';

      default:
        return 'Request failed.';
    }
  }

  String? _getServerMessage() {
    final data = response?.data;
    if (data is Map) {
      // Try common top‑level keys
      for (final key in ['message', 'error', 'detail', 'description']) {
        final val = data[key];
        if (val is String && val.trim().isNotEmpty) return val.trim();
      }
      // Nested errors map (e.g. { "errors": { "email": ["is taken"] } })
      final errors = data['errors'];
      if (errors is Map) {
        for (final entry in errors.entries) {
          final v = entry.value;
          if (v is List && v.isNotEmpty) return '${entry.key}: ${v.first}';
          if (v is String && v.isNotEmpty) return '${entry.key}: $v';
        }
      }
    } else if (data is List && data.isNotEmpty) {
      if (data.first is Map) {
        return _getServerMessageFromMap(data.first as Map);
      }
    } else if (data is String && data.isNotEmpty) {
      // Plain text body – use it directly, but keep it short
      return data.length > 200 ? '${data.substring(0, 200)}...' : data;
    }
    return null;
  }

  // Helper for when the first element of a list is a map
  String? _getServerMessageFromMap(Map map) {
    print("Server has map: ${map}");
    for (final key in ['message', 'error', 'detail']) {
      final val = map[key];
      if (val is String && val.trim().isNotEmpty) {
        return val.trim();
      }
    }
    return null;
  }

  String _getFriendlyTitle() {
    if (type == DioExceptionType.badResponse) return 'API Error';
    return 'Network Error';
  }

  String _getEmoji() {
    if (type == DioExceptionType.badResponse) return '⚠️';
    return '⛔';
  }
}
