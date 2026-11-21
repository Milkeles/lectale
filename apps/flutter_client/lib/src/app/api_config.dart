import 'package:flutter/foundation.dart';

/// The `--dart-define` that gives native builds the API's root address.
const String apiBaseUrlDefine = 'LECTALE_API_BASE_URL';

const String _definedApiBaseUrl = String.fromEnvironment(apiBaseUrlDefine);

/// Raised when a native build was started without an API address.
class MissingApiBaseUrl implements Exception {
  /// Creates the error.
  const MissingApiBaseUrl();

  @override
  String toString() =>
      'The API address is not set. Native builds need '
      '--dart-define=$apiBaseUrlDefine=<address of the API, including /api>, '
      'for example --dart-define=$apiBaseUrlDefine=https://lectale.example/api.';
}

/// Where the API lives.
///
/// The web build is served by the same Worker as the API, so it uses the
/// same-origin `/api` and no address is configured. Native builds have no
/// origin of their own and must be given one. The parameters exist so tests
/// can check both branches.
///
/// Throws [MissingApiBaseUrl] on native when no address is defined.
String resolveApiBaseUrl({bool? isWeb, String? defined}) {
  if (isWeb ?? kIsWeb) {
    return '/api';
  }
  final address = (defined ?? _definedApiBaseUrl).trim();
  if (address.isEmpty) {
    throw const MissingApiBaseUrl();
  }
  return address.endsWith('/')
      ? address.substring(0, address.length - 1)
      : address;
}
