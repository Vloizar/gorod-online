import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_service.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key, required this.authService});

  final AuthService authService;

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordConfirmationController = TextEditingController();
  final recoveryCodeController = TextEditingController();
  List<RegistrationCity> cities = const [];
  ConsentDocument? consent;
  int? selectedCityId;
  bool loading = true;
  bool submitting = false;
  bool consentAccepted = false;
  String? loadError;

  @override
  void initState() {
    super.initState();
    loadOptions();
  }

  Future<void> loadOptions() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final results = await Future.wait([
        widget.authService.registrationCities(),
        widget.authService.personalDataConsent(),
      ]);
      if (!mounted) return;
      setState(() {
        cities = results[0] as List<RegistrationCity>;
        consent = results[1] as ConsentDocument;
      });
    } on LoginException catch (error) {
      if (mounted) setState(() => loadError = error.message);
    } catch (_) {
      if (mounted)
        setState(() => loadError = 'Не удалось загрузить данные регистрации');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> showConsent() async {
    final document = consent;
    if (document == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Согласие на обработку персональных данных'),
        content: SingleChildScrollView(child: Text(document.content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> showCityHelp() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Почему нет моего города?'),
      content: const Text(
        'Мы открываем города поэтапно и сначала готовим местный каталог компаний. '
        'Если города пока нет в списке, регистрация в нём ещё не открыта.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    ),
  );

  Future<void> register() async {
    if (submitting) return;
    final document = consent;
    final cityId = selectedCityId;
    if (nameController.text.trim().isEmpty ||
        phoneController.text.replaceAll(RegExp(r'\D'), '').length != 10 ||
        cityId == null ||
        passwordController.text.length < 8 ||
        passwordController.text != passwordConfirmationController.text ||
        recoveryCodeController.text.length != 4 ||
        !consentAccepted ||
        document == null) {
      showMessage('Проверьте поля и подтвердите согласие');
      return;
    }
    setState(() => submitting = true);
    try {
      await widget.authService.register(
        name: nameController.text,
        phone: '+7${phoneController.text.replaceAll(RegExp(r'\D'), '')}',
        cityId: cityId,
        password: passwordController.text,
        recoveryCode: recoveryCodeController.text,
        consent: document,
      );
      if (!mounted) return;
      showMessage('Регистрация завершена');
      Navigator.of(context).pop();
    } on ConsentChangedException {
      try {
        final updatedDocument = await widget.authService.personalDataConsent();
        if (!mounted) return;
        setState(() {
          consent = updatedDocument;
          consentAccepted = false;
        });
        await showConsent();
        if (mounted) {
          showMessage(
            'Прочитайте обновлённое согласие и подтвердите его, чтобы продолжить регистрацию',
          );
        }
      } on LoginException catch (error) {
        if (mounted) showMessage(error.message);
      } catch (_) {
        if (mounted) {
          showMessage('Не удалось загрузить обновлённое согласие');
        }
      }
    } on LoginException catch (error) {
      if (mounted) showMessage(error.message);
    } catch (_) {
      if (mounted)
        showMessage('Не удалось зарегистрироваться. Попробуйте ещё раз');
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
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    passwordConfirmationController.dispose();
    recoveryCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : loadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(loadError!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: loadOptions,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              )
            : Form(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    TextField(
                      controller: nameController,
                      enabled: !submitting,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Имя',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: selectedCityId,
                      items: cities
                          .map(
                            (city) => DropdownMenuItem(
                              value: city.id,
                              child: Text(city.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: submitting
                          ? null
                          : (value) => setState(() => selectedCityId = value),
                      decoration: const InputDecoration(
                        labelText: 'Город',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: showCityHelp,
                        child: const Text('Почему нет моего города?'),
                      ),
                    ),
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
                      controller: passwordController,
                      enabled: !submitting,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Пароль',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordConfirmationController,
                      enabled: !submitting,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Повторите пароль',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Код восстановления из 4 цифр'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: recoveryCodeController,
                      enabled: !submitting,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: consentAccepted,
                      onChanged: submitting
                          ? null
                          : (value) => setState(
                              () => consentAccepted = value ?? false,
                            ),
                      title: const Text(
                        'Соглашаюсь на обработку персональных данных',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    TextButton(
                      onPressed: showConsent,
                      child: const Text('Прочитать согласие'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: submitting ? null : register,
                      child: submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Зарегистрироваться'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class RussianPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final pastedCountryCode = digits.length > 10 && digits.startsWith('7');
    if (pastedCountryCode) digits = digits.substring(1);
    final limited = digits.length > 10 ? digits.substring(0, 10) : digits;
    final chunks = <String>[];
    var remaining = limited;
    for (final size in [3, 3, 2, 2]) {
      if (remaining.isEmpty) break;
      final take = remaining.length < size ? remaining.length : size;
      chunks.add(remaining.substring(0, take));
      remaining = remaining.substring(take);
    }
    final formatted = chunks.join(' ');
    int digitCountBefore(int offset) {
      final safeOffset = offset.clamp(0, newValue.text.length).toInt();
      var count = newValue.text
          .substring(0, safeOffset)
          .replaceAll(RegExp(r'\D'), '')
          .length;
      if (pastedCountryCode && safeOffset > 0) count--;
      return count.clamp(0, limited.length).toInt();
    }

    int offsetForDigitCount(int count) {
      if (count == 0) return 0;
      var seen = 0;
      var offset = 0;
      while (offset < formatted.length && seen < count) {
        if (RegExp(r'\d').hasMatch(formatted[offset])) seen++;
        offset++;
      }
      if (offset < formatted.length && formatted[offset] == ' ') offset++;
      return offset;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection(
        baseOffset: offsetForDigitCount(
          digitCountBefore(newValue.selection.baseOffset),
        ),
        extentOffset: offsetForDigitCount(
          digitCountBefore(newValue.selection.extentOffset),
        ),
      ),
    );
  }
}
