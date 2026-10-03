import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gorod_online/auth_service.dart';
import 'package:gorod_online/main.dart';

import 'auth_service_test.dart' show MemoryTokens;

void main() {
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
      client: MockClient((_) {
        calls++;
        return response.future;
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
    expect(calls, 1);
    expect(tokens.token, 'x');
    expect(find.text('Вход выполнен'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      isEmpty,
    );
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
