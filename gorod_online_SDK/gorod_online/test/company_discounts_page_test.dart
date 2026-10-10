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
          expect(jsonDecode(request.body), {'code': '123456'});
          if (request.url.path == '/api/companies/invitation-preview') {
            return _json(
              '{"company":{"name":"Тёплый угол","short_description":"Кофейни"},"invited_by":"Мария Соколова","invitation_city":{"name":"Мостовской район"},"has_stores_in_user_city":false,"accepting_members":true,"stores":[{"address":"ул. Центральная, 1","city":{"name":"Мостовской район"},"invitation_city":true}]}',
              200,
            );
          }
          expect(request.url.path, '/api/companies/join');
          joined = true;
          return _json(
            '{"already_member":false,"welcome_bonus":40,"membership":{"company":{"name":"Тёплый угол"},"bonus_balance":40}}',
            201,
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CompanyDiscountsPage(authService: auth, initialCode: '123456'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Вы пока не подключили дисконты компаний.'),
        findsOneWidget,
      );
      expect(find.text('Вас приглашает: Мария Соколова'), findsOneWidget);
      expect(find.text('В вашем городе нет этой компании'), findsOneWidget);
      expect(find.text('ул. Центральная, 1'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      final connectButton = find.byType(FilledButton).last;
      expect(tester.widget<FilledButton>(connectButton).onPressed, isNotNull);
      await tester.tap(connectButton);
      await tester.pumpAndSettle();
      expect(find.text('Дисконт подключён'), findsOneWidget);
      expect(
        find.textContaining('Вам начислено 40 приветственных бонусов.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Понятно'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 900));
      await tester.pumpAndSettle();
      expect(find.text('Тёплый угол'), findsOneWidget);
      expect(find.text('Бонусный баланс: 40'), findsOneWidget);
      expect(find.text('Пригласил(а): Мария'), findsOneWidget);
    },
  );
}
