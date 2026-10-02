# Город онлайн — Flutter

## Вход через API

Укажите адрес корня backend (без `/api/login`):

```sh
flutter pub get
flutter run --dart-define=API_BASE_URL=https://your-server.example
```

Без `API_BASE_URL` экран сообщает об отсутствии настройки. Для production используйте HTTPS. Для Android-эмулятора локальный хост доступен как `10.0.2.2`; HTTP требует отдельной debug network security configuration. Web требует CORS на backend и HTTPS либо localhost для secure storage.

Экран отправляет JSON `phone` и `password` в `POST /api/login`. Пароль передаётся без изменения и не сохраняется. Успешный ответ должен содержать непустой `token` и `token_type: Bearer`. Токен хранится через flutter_secure_storage; `AuthService.authorizationHeaders()` читает его для следующих запросов, в том числе после перезапуска приложения.

Обрабатываются 401, 422, 429, ошибки сервера, сети, таймаут, некорректный ответ и ошибка сохранения. Во время запроса поля и кнопка входа отключены. После сохранения появляется подтверждение входа; переход на следующий экран можно добавить, когда он появится в приложении.

Зависимости: [http](https://pub.dev/packages/http), [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage). Android требует API 23+ (текущий Flutter default — 24). В Windows для сборки приложения с плагинами включите Developer Mode (symlink support).

## Проверки

```sh
flutter test --no-pub
flutter analyze --no-pub
```

Unit-тесты используют HTTP mock и память вместо platform storage. Проверку реального HTTPS backend и secure storage на устройстве выполняйте отдельно с тестовой учётной записью.
