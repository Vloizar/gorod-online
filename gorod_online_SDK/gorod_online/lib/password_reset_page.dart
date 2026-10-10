import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_service.dart';
import 'registration_page.dart' show RussianPhoneFormatter;

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({super.key, required this.authService});

  final AuthService authService;

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final phoneController = TextEditingController();
  final recoveryCodeController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordConfirmationController = TextEditingController();
  bool submitting = false;

  @override
  void dispose() {
    phoneController.dispose();
    recoveryCodeController.dispose();
    passwordController.dispose();
    passwordConfirmationController.dispose();
    super.dispose();
  }

  Future<void> resetPassword() async {
    if (submitting) return;
    final phoneDigits = phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (phoneDigits.length != 10 ||
        recoveryCodeController.text.length != 4 ||
        passwordController.text.length < 8 ||
        passwordController.text != passwordConfirmationController.text) {
      showMessage('Проверьте телефон, код и пароль');
      return;
    }

    setState(() => submitting = true);
    try {
      await widget.authService.resetPassword(
        phone: '+7$phoneDigits',
        recoveryCode: recoveryCodeController.text,
        password: passwordController.text,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Пароль изменён'),
          content: const Text('Теперь войдите с новым паролем.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Понятно'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on LoginException catch (error) {
      if (mounted) showMessage(error.message);
    } catch (_) {
      if (mounted)
        showMessage('Не удалось изменить пароль. Попробуйте ещё раз');
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  void showMessage(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Восстановление пароля')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Введите телефон и 4-значный код восстановления, '
            'который вы указали при регистрации.',
          ),
          const SizedBox(height: 24),
          TextField(
            controller: phoneController,
            enabled: !submitting,
            keyboardType: TextInputType.phone,
            inputFormatters: [RussianPhoneFormatter()],
            decoration: const InputDecoration(
              labelText: 'Телефон для входа',
              prefixText: '+7 ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: recoveryCodeController,
            enabled: !submitting,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Код восстановления',
              counterText: '',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: passwordController,
            enabled: !submitting,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Новый пароль',
              helperText: 'Не менее 8 символов',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: passwordConfirmationController,
            enabled: !submitting,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Повторите новый пароль',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: submitting ? null : resetPassword,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Изменить пароль'),
            ),
          ),
        ],
      ),
    ),
  );
}
