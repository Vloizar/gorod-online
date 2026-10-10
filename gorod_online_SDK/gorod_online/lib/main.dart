import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'password_reset_page.dart';
import 'profile_page.dart';
import 'registration_page.dart';

void main() {
  runApp(const GorodOnlineApp());
}

class GorodOnlineApp extends StatelessWidget {
  const GorodOnlineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Город онлайн',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.authService});
  final AuthService? authService;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  late final AuthService auth = widget.authService ?? AuthService();
  bool loading = false;

  Future<void> login() async {
    if (loading) return;
    if (phoneController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      showMessage('Введите номер телефона и пароль');
      return;
    }
    setState(() => loading = true);
    try {
      await auth.login(phoneController.text, passwordController.text);
      if (!mounted) return;
      passwordController.clear();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ProfilePage(authService: auth)),
      );
    } on LoginException catch (error) {
      if (mounted) showMessage(error.message);
    } catch (_) {
      if (mounted) showMessage('Не удалось выполнить вход. Попробуйте ещё раз');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    if (widget.authService == null) auth.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.location_city, size: 72, color: Colors.blue),
                  const SizedBox(height: 16),
                  const Text(
                    'Город онлайн',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Войдите в приложение',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: phoneController,
                    enabled: !loading,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Номер телефона',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    enabled: !loading,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Пароль',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: loading ? null : login,
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Войти'),
                    ),
                  ),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () async {
                            final changed = await Navigator.of(context)
                                .push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        PasswordResetPage(authService: auth),
                                  ),
                                );
                            if (mounted && changed == true) {
                              showMessage(
                                'Пароль изменён. Войдите с новым паролем',
                              );
                            }
                          },
                    child: const Text('Забыли пароль?'),
                  ),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  RegistrationPage(authService: auth),
                            ),
                          ),
                    child: const Text('Создать аккаунт'),
                  ),
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Обратиться к администратору'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
