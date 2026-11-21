import 'package:flutter_test/flutter_test.dart';
import 'package:lectale/src/app/api_config.dart';

void main() {
  test('the web build uses the same-origin /api, whatever is defined', () {
    expect(resolveApiBaseUrl(isWeb: true, defined: ''), '/api');
    expect(
      resolveApiBaseUrl(isWeb: true, defined: 'https://x.test/api'),
      '/api',
    );
  });

  test('a native build uses the defined address', () {
    expect(
      resolveApiBaseUrl(isWeb: false, defined: 'https://lectale.test/api'),
      'https://lectale.test/api',
    );
  });

  test('a trailing slash is dropped, so request paths join cleanly', () {
    expect(
      resolveApiBaseUrl(isWeb: false, defined: ' https://lectale.test/api/ '),
      'https://lectale.test/api',
    );
  });

  test('a native build without an address fails with the fix', () {
    expect(
      () => resolveApiBaseUrl(isWeb: false, defined: ''),
      throwsA(
        isA<MissingApiBaseUrl>().having(
          (error) => error.toString(),
          'message',
          allOf(
            contains('--dart-define=LECTALE_API_BASE_URL='),
            contains('/api'),
          ),
        ),
      ),
    );
  });
}
