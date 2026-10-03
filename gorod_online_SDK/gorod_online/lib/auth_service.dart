import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

abstract class TokenStore {
  Future<void> save(String token);
  Future<String?> read();
}

class SecureTokenStore implements TokenStore {
  final FlutterSecureStorage storage;
  const SecureTokenStore([this.storage = const FlutterSecureStorage()]);
  @override
  Future<void> save(String token) =>
      storage.write(key: 'access_token', value: token);
  @override
  Future<String?> read() => storage.read(key: 'access_token');
}

class LoginException implements Exception {
  final String message;
  const LoginException(this.message);
}

class AuthService {
  final http.Client client;
  final TokenStore tokens;
  final String baseUrl;
  final Duration timeout;

  AuthService({
    http.Client? client,
    TokenStore? tokens,
    this.baseUrl = const String.fromEnvironment('API_BASE_URL'),
    this.timeout = const Duration(seconds: 15),
  }) : client = client ?? http.Client(),
       tokens = tokens ?? const SecureTokenStore();

  Future<void> login(String phone, String password) async {
    final base = Uri.tryParse(baseUrl);
    if (base == null ||
        !base.hasAuthority ||
        !['https', 'http'].contains(base.scheme) ||
        base.hasQuery ||
        base.hasFragment) {
      throw const LoginException('Не настроен адрес сервера');
    }
    final endpoint = base.replace(
      path: '${base.path.replaceFirst(RegExp(r"/+$"), "")}/api/login',
    );
    late http.Response response;
    try {
      response = await client
          .post(
            endpoint,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'phone': phone.trim(), 'password': password}),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const LoginException('Сервер не ответил. Попробуйте ещё раз');
    } on http.ClientException {
      throw const LoginException('Не удалось подключиться к серверу');
    }
    switch (response.statusCode) {
      case 401:
        throw const LoginException('Неверный номер телефона или пароль');
      case 422:
        throw const LoginException('Проверьте номер телефона и пароль');
      case 429:
        throw const LoginException('Слишком много попыток. Попробуйте позже');
    }
    if (response.statusCode != 200) {
      throw const LoginException('Ошибка сервера. Попробуйте позже');
    }
    dynamic data;
    try {
      data = jsonDecode(response.body);
    } on FormatException {
      throw const LoginException('Некорректный ответ сервера');
    }
    if (data is! Map<String, dynamic> ||
        data['token'] is! String ||
        (data['token'] as String).trim().isEmpty ||
        data['token_type'] != 'Bearer') {
      throw const LoginException('Некорректный ответ сервера');
    }
    try {
      await tokens.save(data['token'] as String);
    } catch (_) {
      throw const LoginException(
        'Не удалось сохранить вход. Попробуйте ещё раз',
      );
    }
  }

  Future<Map<String, String>> authorizationHeaders() async {
    final token = await tokens.read();
    return token == null ? {} : {'Authorization': 'Bearer $token'};
  }

  void close() => client.close();
}
