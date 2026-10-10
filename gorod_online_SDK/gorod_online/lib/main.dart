import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'company_discounts_page.dart';
import 'invitation_link.dart';
import 'password_reset_page.dart';
import 'profile_page.dart';
import 'registration_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final links = AppLinks();
  String? initialCode;
  if (kIsWeb) {
    initialCode = invitationCodeFromUri(Uri.base);
  } else {
    try {
      final initialUri = await links.getInitialLink();
      if (initialUri != null) initialCode = invitationCodeFromUri(initialUri);
    } catch (_) {
      // A broken or unsupported launch URI should still open the app normally.
    }
  }
  runApp(GorodOnlineApp(appLinks: links, initialInvitationCode: initialCode));
}

class GorodOnlineApp extends StatefulWidget {
  const GorodOnlineApp({super.key, this.appLinks, this.initialInvitationCode});

  final AppLinks? appLinks;
  final String? initialInvitationCode;

  @override
  State<GorodOnlineApp> createState() => _GorodOnlineAppState();
}

class _GorodOnlineAppState extends State<GorodOnlineApp> {
  final navigatorKey = GlobalKey<NavigatorState>();
  late final AuthService auth = AuthService();
  late final AppLinks appLinks = widget.appLinks ?? AppLinks();
  StreamSubscription<Uri>? linkSubscription;
  String? pendingInvitationCode;
  String? lastHandledInvitationCode;
  DateTime? lastHandledAt;
  bool authenticated = false;

  @override
  void initState() {
    super.initState();
    pendingInvitationCode =
        widget.initialInvitationCode ??
        (kIsWeb ? invitationCodeFromUri(Uri.base) : null);
    lastHandledInvitationCode = pendingInvitationCode;
    if (lastHandledInvitationCode != null) lastHandledAt = DateTime.now();
    linkSubscription = appLinks.uriLinkStream.listen(_handleLink);
  }

  void _handleLink(Uri uri) {
    final code = invitationCodeFromUri(uri);
    if (code == null) return;
    final now = DateTime.now();
    if (lastHandledInvitationCode == code &&
        lastHandledAt != null &&
        now.difference(lastHandledAt!) < const Duration(seconds: 2)) {
      return;
    }
    lastHandledInvitationCode = code;
    lastHandledAt = now;
    if (authenticated) {
      navigatorKey.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              CompanyDiscountsPage(authService: auth, initialCode: code),
        ),
      );
      return;
    }
    setState(() => pendingInvitationCode = code);
  }

  void _setAuthenticated(bool value) {
    setState(() => authenticated = value);
  }

  @override
  void dispose() {
    linkSubscription?.cancel();
    auth.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Город онлайн',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: LoginPage(
        authService: auth,
        initialInvitationCode: pendingInvitationCode,
        onAuthenticated: _setAuthenticated,
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.authService,
    this.initialInvitationCode,
    this.onAuthenticated,
  });
  final AuthService? authService;
  final String? initialInvitationCode;
  final ValueChanged<bool>? onAuthenticated;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  late final AuthService auth = widget.authService ?? AuthService();
  bool loading = false;
  String? pendingInvitationCode;

  @override
  void initState() {
    super.initState();
    pendingInvitationCode = widget.initialInvitationCode;
  }

  @override
  void didUpdateWidget(covariant LoginPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialInvitationCode != widget.initialInvitationCode) {
      pendingInvitationCode = widget.initialInvitationCode;
    }
  }

  Future<void> openProfile() async {
    widget.onAuthenticated?.call(true);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfilePage(
          authService: auth,
          initialInvitationCode: pendingInvitationCode,
          onAccountDeleted: () => widget.onAuthenticated?.call(false),
        ),
      ),
    );
    widget.onAuthenticated?.call(false);
  }

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
      await openProfile();
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
                  if (pendingInvitationCode != null) ...[
                    Card(
                      color: const Color(0xFFEAF4FC),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          'Вам отправили приглашение в компанию. Войдите или создайте аккаунт, чтобы посмотреть магазины и подключить дисконт.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
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
                        : () async {
                            final registered = await Navigator.of(context)
                                .push<bool>(
                                  MaterialPageRoute<bool>(
                                    builder: (_) =>
                                        RegistrationPage(authService: auth),
                                  ),
                                );
                            if (mounted && registered == true) {
                              await openProfile();
                            }
                          },
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
