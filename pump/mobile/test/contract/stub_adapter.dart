import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

/// Records every request and answers with canned JSON, so repository tests exercise the
/// real ApiClient + parsing code with real captured payloads and no network.
class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.handler);

  /// Return (statusCode, jsonBody) for a request.
  final (int, Object?) Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = handler(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
