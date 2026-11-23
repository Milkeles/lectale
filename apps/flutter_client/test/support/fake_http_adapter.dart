import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// An answer of a [FakeHttpAdapter].
class FakeResponse {
  /// Creates a JSON response with [body].
  const FakeResponse(this.statusCode, [this.body])
    : delay = Duration.zero,
      hangs = false;

  /// A response that arrives after [delay].
  const FakeResponse.after(this.delay, this.statusCode, [this.body])
    : hangs = false;

  /// A response without a connection behind it: the request fails as if the
  /// server could not be reached.
  const FakeResponse.offline()
    : statusCode = 0,
      body = null,
      delay = Duration.zero,
      hangs = false;

  /// A request that never gets an answer, until it is cancelled.
  const FakeResponse.hangs()
    : statusCode = 0,
      body = null,
      delay = Duration.zero,
      hangs = true;

  /// The status code; 0 for [FakeResponse.offline] and [FakeResponse.hangs].
  final int statusCode;

  /// The body, encoded as JSON, or sent as is when it is a [String] or bytes;
  /// null for none.
  final Object? body;

  /// How long the answer takes.
  final Duration delay;

  /// Whether the request is left unanswered.
  final bool hangs;
}

/// Answers the requests of a `Dio` client in tests, without a server.
///
/// Each answer is registered for a method and path, such as
/// `server.on('POST', '/api/courses/import', FakeResponse(200, {...}))`, and
/// can be replaced to change what later requests get. A request without an
/// answer fails the test.
class FakeHttpAdapter implements HttpClientAdapter {
  final Map<String, FakeResponse Function(RequestOptions request)> _routes = {};

  /// The requests received, oldest first.
  final List<RequestOptions> requests = [];

  /// How many requests were cancelled before they were answered.
  int cancelled = 0;

  /// Answers requests to [method] [path] with [response].
  void on(String method, String path, FakeResponse response) =>
      _routes['${method.toUpperCase()} $path'] = (_) => response;

  /// Answers requests to [method] [path] with what [respond] returns for each
  /// request, for example to check its body.
  void onRequest(
    String method,
    String path,
    FakeResponse Function(RequestOptions request) respond,
  ) => _routes['${method.toUpperCase()} $path'] = respond;

  /// The decoded JSON bodies of the requests to [method] [path].
  List<Object?> bodiesOf(String method, String path) => [
    for (final request in requests)
      if (request.method == method.toUpperCase() && request.path == path)
        if (request.data case final String json)
          jsonDecode(json)
        else
          request.data,
  ];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final respond = _routes['${options.method} ${options.uri.path}'];
    if (respond == null) {
      throw StateError(
        'No fake response for ${options.method} ${options.uri.path}.',
      );
    }
    final response = respond(options);

    // A request waits for its answer unless it is cancelled first.
    final cancelSignal = Completer<void>();
    unawaited(cancelFuture?.then((_) => cancelSignal.complete()));
    final answered = response.hangs
        ? Completer<void>().future
        : response.delay == Duration.zero
        ? Future<void>.value()
        : Future<void>.delayed(response.delay);
    final wasCancelled = await Future.any([
      answered.then((_) => false),
      cancelSignal.future.then((_) => true),
    ]);
    if (wasCancelled) {
      cancelled++;
      throw DioException.requestCancelled(
        requestOptions: options,
        reason: 'cancelled',
      );
    }

    if (response.statusCode == 0) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'The fake server is offline.',
      );
    }
    final body = response.body;
    if (body is Uint8List) {
      return ResponseBody.fromBytes(
        body,
        response.statusCode,
        headers: {
          Headers.contentLengthHeader: ['${body.length}'],
          Headers.contentTypeHeader: ['application/octet-stream'],
        },
      );
    }
    final text = switch (body) {
      null => '',
      final String raw => raw,
      _ => jsonEncode(body),
    };
    return ResponseBody.fromString(
      text,
      response.statusCode,
      headers: {
        if (body != null && body is! String)
          Headers.contentTypeHeader: [Headers.jsonContentType]
        else if (body is String)
          Headers.contentTypeHeader: ['text/html'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
