import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';

class ApiUnavailableException implements Exception {
  final String message;
  final int? statusCode;
  ApiUnavailableException(this.message, {this.statusCode});
  @override
  String toString() => 'ApiUnavailableException: $message (code: $statusCode)';
}

class ApiOfflineException implements Exception {
  final String message;
  ApiOfflineException([this.message = 'Network connection unavailable']);
  @override
  String toString() => 'ApiOfflineException: $message';
}

class ApiTimeoutException implements Exception {
  final String message;
  ApiTimeoutException([this.message = 'Request timed out waiting for backend (cold start)']);
  @override
  String toString() => 'ApiTimeoutException: $message';
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic error;

  ApiException(this.message, {this.statusCode, this.error});

  @override
  String toString() => 'ApiException: $message (code: $statusCode)';
}

typedef Offline = ApiOfflineException;
typedef Unavailable503 = ApiUnavailableException;
typedef Timeout = ApiTimeoutException;


class ApiClient {
  final Dio _dio;
  final String baseUrl;

  ApiClient({String? customBaseUrl, Dio? dio})
      : baseUrl = customBaseUrl ?? const String.fromEnvironment('API_BASE', defaultValue: ''),
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 45),
              headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
            )) {
    if (baseUrl.isNotEmpty) {
      _dio.options.baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    }
  }

  bool get hasBaseUrl => baseUrl.isNotEmpty;

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters, int maxRetries = 2}) async {
    if (!hasBaseUrl) {
      throw ApiOfflineException('No backend API_BASE configured');
    }

    int attempts = 0;
    while (true) {
      attempts++;
      try {
        final res = await _dio.get(path, queryParameters: queryParameters);
        return res.data;
      } on DioException catch (e) {
        if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
          if (attempts <= maxRetries) {
            await Future.delayed(Duration(seconds: attempts == 1 ? 1 : 3));
            continue;
          }
          throw ApiTimeoutException();
        } else if (e.response?.statusCode == 503) {
          if (attempts <= maxRetries) {
            await Future.delayed(Duration(seconds: attempts == 1 ? 1 : 3));
            continue;
          }
          throw ApiUnavailableException('Backend warming up (503)', statusCode: 503);
        } else if (e.error is SocketException || e.type == DioExceptionType.connectionError) {
          throw ApiOfflineException();
        }
        throw ApiException(
          e.response?.statusMessage ?? e.message ?? 'API error',
          statusCode: e.response?.statusCode,
          error: e.error,
        );
      }
    }
  }

  Future<dynamic> post(String path, {dynamic data}) async {
    if (!hasBaseUrl) {
      throw ApiOfflineException('No backend API_BASE configured');
    }
    try {
      final res = await _dio.post(path, data: data);
      return res.data;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        throw ApiTimeoutException();
      } else if (e.response?.statusCode == 503) {
        throw ApiUnavailableException('Backend warming up (503)', statusCode: 503);
      } else if (e.error is SocketException || e.type == DioExceptionType.connectionError) {
        throw ApiOfflineException();
      }
      throw ApiException(
        e.response?.statusMessage ?? e.message ?? 'API error',
        statusCode: e.response?.statusCode,
        error: e.error,
      );
    }
  }
}
