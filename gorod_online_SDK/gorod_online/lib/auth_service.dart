import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

abstract class TokenStore {
  Future<void> save(String token);
  Future<String?> read();
  Future<void> delete();
}

class SecureTokenStore implements TokenStore {
  final FlutterSecureStorage storage;
  const SecureTokenStore([this.storage = const FlutterSecureStorage()]);
  @override
  Future<void> save(String token) =>
      storage.write(key: 'access_token', value: token);
  @override
  Future<String?> read() => storage.read(key: 'access_token');

  @override
  Future<void> delete() => storage.delete(key: 'access_token');
}

class LoginException implements Exception {
  final String message;
  const LoginException(this.message);
}

class ConsentChangedException extends LoginException {
  const ConsentChangedException()
    : super('Текст согласия обновился. Загрузили актуальную редакцию.');
}

class RegistrationCity {
  final int id;
  final String displayName;

  const RegistrationCity({required this.id, required this.displayName});
}

class ConsentDocument {
  final String version;
  final String content;
  final String sha256;

  const ConsentDocument({
    required this.version,
    required this.content,
    required this.sha256,
  });
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

  Future<List<RegistrationCity>> registrationCities() async {
    final response = await _get('/api/cities');
    if (response.statusCode != 200) {
      throw LoginException(_messageFor(response.statusCode));
    }
    final data = _decodeMap(response.body);
    final items = data['data'];
    if (items is! List)
      throw const LoginException('Некорректный ответ сервера');
    return items
        .map((item) {
          if (item is! Map<String, dynamic> ||
              item['id'] is! int ||
              item['display_name'] is! String) {
            throw const LoginException('Некорректный ответ сервера');
          }
          return RegistrationCity(
            id: item['id'] as int,
            displayName: item['display_name'] as String,
          );
        })
        .toList(growable: false);
  }

  Future<ConsentDocument> personalDataConsent() async {
    final response = await _get('/api/legal/personal-data-consent');
    if (response.statusCode != 200) {
      throw LoginException(_messageFor(response.statusCode));
    }
    final data = _decodeMap(response.body);
    if (data['version'] is! String ||
        data['content'] is! String ||
        data['sha256'] is! String) {
      throw const LoginException('Некорректный ответ сервера');
    }
    return ConsentDocument(
      version: data['version'] as String,
      content: data['content'] as String,
      sha256: data['sha256'] as String,
    );
  }

  Future<void> register({
    required String name,
    required String phone,
    required int cityId,
    required String password,
    required String recoveryCode,
    required ConsentDocument consent,
  }) async {
    final endpoint = _endpoint('/api/register');
    late http.Response response;
    try {
      response = await client
          .post(
            endpoint,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'name': name.trim(),
              'phone': phone.trim(),
              'city_id': cityId,
              'password': password,
              'password_confirmation': password,
              'recovery_code': recoveryCode,
              'accepts_personal_data_consent': true,
              'consent_version': consent.version,
              'consent_sha256': consent.sha256,
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const LoginException('Сервер не ответил. Попробуйте ещё раз');
    } on http.ClientException {
      throw const LoginException('Не удалось подключиться к серверу');
    }
    if (response.statusCode == 409) {
      throw const ConsentChangedException();
    }
    if (response.statusCode != 201) {
      throw LoginException(_messageFor(response.statusCode));
    }
    final data = _decodeMap(response.body);
    if (data['token'] is! String || data['token_type'] != 'Bearer') {
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

  Future<http.Response> _get(String path, {bool authenticated = false}) async {
    final token = authenticated ? await tokens.read() : null;
    final response = await client
        .get(
          _endpoint(path),
          headers: {
            'Accept': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        )
        .timeout(timeout);
    return response;
  }

  Future<Map<String, dynamic>> profile() async {
    final response = await _get('/api/user', authenticated: true);
    if (response.statusCode == 401) {
      throw const LoginException('Сеанс завершён. Войдите снова');
    }
    if (response.statusCode != 200) {
      throw const LoginException('Не удалось загрузить профиль');
    }
    return _decodeMap(response.body);
  }

  Future<void> deleteAccount() async {
    final token = await tokens.read();
    if (token == null) {
      throw const LoginException('Сеанс завершён. Войдите снова');
    }
    late http.Response response;
    try {
      response = await client
          .delete(
            _endpoint('/api/user'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const LoginException('Сервер не ответил. Проверьте статус позже');
    } on http.ClientException {
      throw const LoginException('Не удалось подключиться к серверу');
    }
    if (response.statusCode == 401) {
      throw const LoginException('Сеанс завершён. Войдите снова');
    }
    if (response.statusCode != 200) {
      throw const LoginException('Не удалось удалить учётную запись');
    }
    await tokens.delete();
  }

  Uri _endpoint(String path) {
    final base = Uri.tryParse(baseUrl);
    if (base == null ||
        !base.hasAuthority ||
        !['https', 'http'].contains(base.scheme) ||
        base.hasQuery ||
        base.hasFragment) {
      throw const LoginException('Не настроен адрес сервера');
    }
    return base.replace(
      path: '${base.path.replaceFirst(RegExp(r"/+$"), "")}$path',
    );
  }

  Map<String, dynamic> _decodeMap(String body) {
    dynamic data;
    try {
      data = jsonDecode(body);
    } on FormatException {
      throw const LoginException('Некорректный ответ сервера');
    }
    if (data is! Map<String, dynamic>) {
      throw const LoginException('Некорректный ответ сервера');
    }
    return data;
  }

  String _messageFor(int statusCode) => switch (statusCode) {
    503 => 'Регистрация временно недоступна. Попробуйте позже',
    422 => 'Проверьте заполненные данные',
    429 => 'Слишком много попыток. Попробуйте позже',
    _ => 'Ошибка сервера. Попробуйте позже',
  };

  Future<Map<String, String>> authorizationHeaders() async {
    final token = await tokens.read();
    return token == null ? {} : {'Authorization': 'Bearer $token'};
  }

  void close() => client.close();
}
