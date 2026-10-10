import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gorod_online/auth_service.dart';
import 'package:gorod_online/registration_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'auth_service_test.dart' show MemoryTokens;

http.Response _json(String body, int statusCode) => http.Response.bytes(
  utf8.encode(body),
  statusCode,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  testWidgets(
    'continues registration automatically when consent changes mid-flow',
    (tester) async {
      var consentRequests = 0;
      var registrationRequests = 0;
      final tokens = MemoryTokens();
      final auth = AuthService(
        baseUrl: 'https://example.test',
        tokens: tokens,
        client: MockClient((request) async {
          if (request.url.path == '/api/cities') {
            return _json(
              '{"data":[{"id":1,"display_name":"Мостовской"}]}',
              200,
            );
          }
          if (request.url.path == '/api/legal/personal-data-consent') {
            consentRequests++;
            final version = consentRequests == 1 ? '1.0' : '1.1';
            final content = 'Текст $version';
            return _json(
              jsonEncode({
                'version': version,
                'content': content,
                'sha256': List.filled(64, version == '1.0' ? 'a' : 'b').join(),
              }),
              200,
            );
          }
          if (request.url.path == '/api/register') {
            registrationRequests++;
            if (registrationRequests == 1) return _json('{}', 409);
            expect(jsonDecode(request.body)['consent_version'], '1.1');
            return _json(
              '{"token":"session-token","token_type":"Bearer"}',
              201,
            );
          }
          fail('Unexpected request: ${request.method} ${request.url}');
        }),
      );

      await tester.pumpWidget(
        MaterialApp(home: RegistrationPage(authService: auth)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(5));

      await tester.enterText(find.byType(TextField).at(0), 'Андрей');
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Мостовской').last);
      await tester.enterText(find.byType(TextField).at(1), '9000000001');
      await tester.enterText(find.byType(TextField).at(2), 'password123');
      await tester.enterText(find.byType(TextField).at(3), 'password123');
      await tester.enterText(find.byType(TextField).at(4), '1234');
      await tester.tap(find.byType(Checkbox));
      await tester.drag(find.byType(ListView).first, const Offset(0, -900));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Зарегистрироваться'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(registrationRequests, 2);
      expect(consentRequests, 2);
      expect(tokens.token, 'session-token');
      expect(find.text('Согласие обновлено'), findsOneWidget);
      expect(find.text('Понятно'), findsOneWidget);
    },
  );
}
