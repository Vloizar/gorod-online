import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gorod_online/auth_service.dart';
import 'package:gorod_online/company_discounts_page.dart';

import 'auth_service_test.dart' show MemoryTokens;

http.Response _json(String body, int status) => http.Response.bytes(
  utf8.encode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  testWidgets(
    'connects a company using an invite code and shows its bonus balance',
    (tester) async {
      final tokens = MemoryTokens()..token = 'session-token';
      var joined = false;
      final auth = AuthService(
        baseUrl: 'https://example.test',
        tokens: tokens,
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer session-token');
          if (request.method == 'GET') {
            return _json(
              joined
                  ? '{"data":[{"company":{"name":"Тёплый угол"},"bonus_balance":40,"invited_by":"Мария"}]}'
                  : '{"data":[]}',
              200,
            );
          }
          expect(request.url.path, '/api/companies/join');
          expect(jsonDecode(request.body), {'code': '123456'});
          joined = true;
          return _json(
            '{"already_member":false,"welcome_bonus":40,"membership":{"company":{"name":"Тёплый угол"},"bonus_balance":40}}',
            201,
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(home: CompanyDiscountsPage(authService: auth)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Вы пока не подключили дисконты компаний.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Подключить дисконт'));
      await tester.pumpAndSettle();

      expect(find.text('Дисконт подключён'), findsOneWidget);
      expect(
        find.textContaining('Вам начислено 40 приветственных бонусов.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Понятно'));
      await tester.pumpAndSettle();
      expect(find.text('Тёплый угол'), findsOneWidget);
      expect(find.text('Бонусный баланс: 40'), findsOneWidget);
      expect(find.text('Пригласил(а): Мария'), findsOneWidget);
    },
  );
}
