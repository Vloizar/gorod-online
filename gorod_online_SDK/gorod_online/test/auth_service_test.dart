import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gorod_online/auth_service.dart';

http.Response utf8Response(String body, int statusCode) => http.Response.bytes(
  utf8.encode(body),
  statusCode,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

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

  @override
  Future<void> delete() async => token = null;
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
  test(
    'loads authenticated profile and deletes account and local token',
    () async {
      final tokens = MemoryTokens()..token = 'session-token';
      var profileLoaded = false;
      var accountDeleted = false;
      final auth = AuthService(
        baseUrl: 'https://example.test',
        tokens: tokens,
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer session-token');
          if (request.method == 'GET') {
            expect(request.url.path, '/api/user');
            profileLoaded = true;
            return utf8Response('{"id":1,"name":"Андрей"}', 200);
          }
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/user');
          accountDeleted = true;
          return http.Response('{"message":"deleted"}', 200);
        }),
      );

      expect((await auth.profile())['name'], 'Андрей');
      await auth.deleteAccount();
      expect(profileLoaded, isTrue);
      expect(accountDeleted, isTrue);
      expect(tokens.token, isNull);
    },
  );
  test(
    'loads company memberships and joins a company with the member token',
    () async {
      final tokens = MemoryTokens()..token = 'member-token';
      final auth = AuthService(
        baseUrl: 'https://example.test',
        tokens: tokens,
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer member-token');
          if (request.method == 'GET') {
            expect(request.url.path, '/api/companies/memberships');
            return utf8Response(
              '{"data":[{"company":{"name":"Тёплый угол"},"bonus_balance":5}]}',
              200,
            );
          }
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {'code': '123456'});
          if (request.url.path == '/api/companies/invitation-preview') {
            return utf8Response(
              '{"company":{"name":"Тёплый угол"},"stores":[],"accepting_members":true}',
              200,
            );
          }
          expect(request.url.path, '/api/companies/join');
          return utf8Response(
            '{"already_member":false,"welcome_bonus":25,"membership":{"company":{"name":"Тёплый угол"}}}',
            201,
          );
        }),
      );

      expect((await auth.companyMemberships()).single['bonus_balance'], 5);
      expect(
        (await auth.companyInvitationPreview('123456'))['accepting_members'],
        isTrue,
      );
      expect((await auth.joinCompany(' 123456 '))['welcome_bonus'], 25);
    },
  );
  test('identifies a changed consent so registration can refresh it', () async {
    final auth = AuthService(
      baseUrl: 'https://example.test',
      client: MockClient((_) async => http.Response('{}', 409)),
    );

    await expectLater(
      auth.register(
        name: 'Андрей',
        phone: '+79900000001',
        cityId: 7,
        password: 'secure-password',
        recoveryCode: '1234',
        consent: const ConsentDocument(
          version: '1.0',
          content: 'Old consent',
          sha256: 'old-hash',
        ),
      ),
      throwsA(isA<ConsentChangedException>()),
    );
  });
  test(
    'sends phone, recovery code and new password to the reset endpoint',
    () async {
      final auth = AuthService(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/password/reset');
          expect(jsonDecode(request.body), {
            'phone': '+79900000001',
            'recovery_code': '1234',
            'password': 'new-password',
            'password_confirmation': 'new-password',
          });
          return http.Response('{"message":"ok"}', 200);
        }),
      );

      await auth.resetPassword(
        phone: '+79900000001',
        recoveryCode: '1234',
        password: 'new-password',
      );
    },
  );
  test('loads open registration cities and the current consent document', () async {
    final auth = AuthService(
      baseUrl: 'https://example.test/',
      client: MockClient((request) async {
        if (request.url.path == '/api/cities') {
          return utf8Response(
            '{"data":[{"id":7,"display_name":"Мостовской, Мостовской район"}]}',
            200,
          );
        }
        return http.Response(
          '{"version":"1.0","content":"Consent text","sha256":"abc"}',
          200,
        );
      }),
    );
    expect(
      (await auth.registrationCities()).single.displayName,
      'Мостовской, Мостовской район',
    );
    expect((await auth.personalDataConsent()).content, 'Consent text');
  });
  test(
    'registers using explicit consent details and persists the token',
    () async {
      final tokens = MemoryTokens();
      final auth = AuthService(
        baseUrl: 'https://example.test',
        tokens: tokens,
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/register');
          expect(jsonDecode(request.body), {
            'name': 'Андрей',
            'phone': '+79900000001',
            'city_id': 7,
            'password': 'secure-password',
            'password_confirmation': 'secure-password',
            'recovery_code': '1234',
            'accepts_personal_data_consent': true,
            'consent_version': '1.0',
            'consent_sha256': 'abc',
          });
          return http.Response(
            '{"token":"new-token","token_type":"Bearer"}',
            201,
          );
        }),
      );
      await auth.register(
        name: 'Андрей',
        phone: '+79900000001',
        cityId: 7,
        password: 'secure-password',
        recoveryCode: '1234',
        consent: const ConsentDocument(
          version: '1.0',
          content: 'Consent',
          sha256: 'abc',
        ),
      );
      expect(tokens.token, 'new-token');
    },
  );
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
