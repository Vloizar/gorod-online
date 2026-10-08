import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gorod_online/auth_service.dart';

class MemoryTokens implements TokenStore {
  String? token;
  bool fail = false;
  @override
  Future<void> save(String value) async {
    if (fail) throw StateError('storage failed');
    token = value;
  }

  @override
  Future<String?> read() async => token;
}

void main() {
  test('posts credentials and persists token for Bearer requests', () async {
    final tokens = MemoryTokens();
    final auth = AuthService(
      baseUrl: 'https://example.test/',
      tokens: tokens,
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'https://example.test/api/login');
        expect(request.headers['Accept'], 'application/json');
        expect(jsonDecode(request.body), {
          'phone': '+79991234567',
          'password': ' secret ',
        });
        return http.Response(
          '{"token":"test-token","token_type":"Bearer"}',
          200,
        );
      }),
    );
    await auth.login(' +79991234567 ', ' secret ');
    expect(tokens.token, 'test-token');
    expect(await auth.authorizationHeaders(), {
      'Authorization': 'Bearer test-token',
    });
  });
  for (final status in [401, 422, 429, 500]) {
    test('handles HTTP $status without saving token', () async {
      final tokens = MemoryTokens();
      final auth = AuthService(
        baseUrl: 'https://example.test',
        tokens: tokens,
        client: MockClient(
          (_) async => http.Response('<html>Error</html>', status),
        ),
      );
      await expectLater(
        auth.login('1234567', 'password'),
        throwsA(isA<LoginException>()),
      );
      expect(tokens.token, isNull);
    });
  }
  for (final body in [
    'invalid',
    '[]',
    '{}',
    '{"token":"","token_type":"Bearer"}',
    '{"token":"x","token_type":"Basic"}',
  ]) {
    test('rejects malformed success $body', () async {
      final tokens = MemoryTokens();
      final auth = AuthService(
        baseUrl: 'https://example.test',
        tokens: tokens,
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        auth.login('1234567', 'password'),
        throwsA(isA<LoginException>()),
      );
      expect(tokens.token, isNull);
    });
  }
  test('handles connection failure', () async {
    final auth = AuthService(
      baseUrl: 'https://example.test',
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(
      auth.login('1234567', 'password'),
      throwsA(isA<LoginException>()),
    );
  });
  test('handles timeout', () async {
    final auth = AuthService(
      baseUrl: 'https://example.test',
      timeout: Duration.zero,
      client: MockClient((_) => Completer<http.Response>().future),
    );
    await expectLater(
      auth.login('1234567', 'password'),
      throwsA(isA<LoginException>()),
    );
  });
  test('reports storage failure', () async {
    final tokens = MemoryTokens()..fail = true;
    final auth = AuthService(
      baseUrl: 'https://example.test',
      tokens: tokens,
      client: MockClient(
        (_) async => http.Response('{"token":"x","token_type":"Bearer"}', 200),
      ),
    );
    await expectLater(
      auth.login('1234567', 'password'),
      throwsA(isA<LoginException>()),
    );
  });
  test('missing URL makes no request', () async {
    final auth = AuthService(
      baseUrl: '',
      client: MockClient((_) async => throw StateError('unexpected request')),
    );
    await expectLater(
      auth.login('1234567', 'password'),
      throwsA(isA<LoginException>()),
    );
  });
}
