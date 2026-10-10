import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gorod_online/auth_service.dart';
import 'package:gorod_online/main.dart';
import 'package:gorod_online/profile_page.dart';

import 'auth_service_test.dart' show MemoryTokens;

http.Response utf8Response(String body, int statusCode) => http.Response.bytes(
  utf8.encode(body),
  statusCode,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  testWidgets('shows an invitation reminder on the login screen', (
    tester,
  ) async {
    final auth = AuthService(
      baseUrl: 'https://example.test',
      client: MockClient((_) async => http.Response('{}', 500)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(authService: auth, initialInvitationCode: '123456'),
      ),
    );
    expect(
      find.textContaining('Вам отправили приглашение в компанию'),
      findsOneWidget,
    );
  });

  testWidgets('opens the pending company invitation after login', (
    tester,
  ) async {
    final auth = AuthService(
      baseUrl: 'https://example.test',
      tokens: MemoryTokens(),
      client: MockClient((request) async {
        if (request.url.path == '/api/login') {
          return utf8Response(
            '{"token":"session-token","token_type":"Bearer"}',
            200,
          );
        }
        if (request.url.path == '/api/user') {
          return utf8Response('{"name":"Андрей","phone":"+79991234567"}', 200);
        }
        if (request.url.path == '/api/companies/memberships') {
          return utf8Response('{"data":[]}', 200);
        }
        if (request.url.path == '/api/companies/invitation-preview') {
          expect(jsonDecode(request.body)['code'], '123456');
          return utf8Response(
            '{"company":{"name":"Тёплый угол"},"accepting_members":true,"stores":[]}',
            200,
          );
        }
        fail('Unexpected request: ${request.method} ${request.url}');
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(authService: auth, initialInvitationCode: '123456'),
      ),
    );
    await tester.enterText(find.byType(TextField).at(0), '+79991234567');
    await tester.enterText(find.byType(TextField).at(1), 'password');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();

    expect(find.text('Тёплый угол'), findsOneWidget);
  });

  testWidgets('empty fields do not send a request', (tester) async {
    var calls = 0;
    final auth = AuthService(
      baseUrl: 'https://example.test',
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    await tester.pumpWidget(MaterialApp(home: LoginPage(authService: auth)));
    await tester.tap(find.text('Войти'));
    await tester.pump();
    expect(find.text('Введите номер телефона и пароль'), findsOneWidget);
    expect(calls, 0);
  });
  testWidgets('blocks duplicate submit and saves token before success', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    final tokens = MemoryTokens();
    var calls = 0;
    final auth = AuthService(
      baseUrl: 'https://example.test',
      tokens: tokens,
      client: MockClient((request) {
        calls++;
        if (request.method == 'POST') return response.future;
        return Future.value(
          utf8Response('{"id":1,"name":"Андрей","phone":"+79991234567"}', 200),
        );
      }),
    );
    await tester.pumpWidget(MaterialApp(home: LoginPage(authService: auth)));
    await tester.enterText(find.byType(TextField).at(0), '+79991234567');
    await tester.enterText(find.byType(TextField).at(1), 'password');
    await tester.tap(find.text('Войти'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    response.complete(
      http.Response('{"token":"x","token_type":"Bearer"}', 200),
    );
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tokens.token, 'x');
    expect(find.text('Профиль'), findsOneWidget);
    expect(find.text('Андрей'), findsOneWidget);
    expect(find.text('Удалить учетную запись'), findsOneWidget);
  });
  testWidgets('account deletion requires an explicit confirmation', (
    tester,
  ) async {
    final tokens = MemoryTokens()..token = 'session-token';
    var deleteCalls = 0;
    final auth = AuthService(
      baseUrl: 'https://example.test',
      tokens: tokens,
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return utf8Response('{"id":1,"name":"Андрей"}', 200);
        }
        deleteCalls++;
        return http.Response('{"message":"deleted"}', 200);
      }),
    );
    await tester.pumpWidget(MaterialApp(home: ProfilePage(authService: auth)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить учетную запись'));
    await tester.pumpAndSettle();
    expect(find.text('Удалить учетную запись?'), findsOneWidget);
    expect(deleteCalls, 0);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(deleteCalls, 0);
    await tester.tap(find.text('Удалить учетную запись'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить').last);
    await tester.pumpAndSettle();
    expect(deleteCalls, 1);
    expect(tokens.token, isNull);
  });
  testWidgets('forgot password opens and submits the recovery form', (
    tester,
  ) async {
    var resetCalled = false;
    final auth = AuthService(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        expect(request.url.path, '/api/password/reset');
        expect(request.method, 'POST');
        resetCalled = true;
        return http.Response('{"message":"ok"}', 200);
      }),
    );
    await tester.pumpWidget(MaterialApp(home: LoginPage(authService: auth)));
    await tester.tap(find.text('Забыли пароль?'));
    await tester.pumpAndSettle();
    expect(find.text('Восстановление пароля'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), '9000000001');
    await tester.enterText(find.byType(TextField).at(1), '1234');
    await tester.enterText(find.byType(TextField).at(2), 'new-password');
    await tester.enterText(find.byType(TextField).at(3), 'new-password');
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Изменить пароль'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(resetCalled, isTrue);
    expect(find.text('Пароль изменён'), findsOneWidget);
    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();
    expect(find.text('Войти'), findsOneWidget);
  });
  testWidgets('shows auth error and enables retry', (tester) async {
    final auth = AuthService(
      baseUrl: 'https://example.test',
      client: MockClient((_) async => http.Response('{}', 401)),
    );
    await tester.pumpWidget(MaterialApp(home: LoginPage(authService: auth)));
    await tester.enterText(find.byType(TextField).at(0), '+79991234567');
    await tester.enterText(find.byType(TextField).at(1), 'wrong');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    expect(find.text('Неверный номер телефона или пароль'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
}
