import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'company_discounts_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.authService});

  final AuthService authService;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? profile;
  String? error;
  bool loading = true;
  bool deleting = false;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.authService.profile();
      if (mounted) setState(() => profile = result);
    } on LoginException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Не удалось загрузить профиль');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> confirmAccountDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить учетную запись?'),
        content: const Text(
          'Вы потеряете доступ к аккаунту. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => deleting = true);
    try {
      await widget.authService.deleteAccount();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Учётная запись удалена')));
      Navigator.of(context).pop();
    } on LoginException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(exception.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось удалить учётную запись')),
        );
      }
    } finally {
      if (mounted) setState(() => deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = profile;
    final city = account?['city'];
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error!),
                    TextButton(
                      onPressed: loadProfile,
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(
                          account?['name'] as String? ?? 'Пользователь',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 24),
                        _ProfileRow(
                          label: 'Телефон для входа',
                          value: account?['phone'] as String? ?? '—',
                        ),
                        _ProfileRow(
                          label: 'Код участника',
                          value: account?['member_code'] as String? ?? '—',
                        ),
                        if (city is Map<String, dynamic>)
                          _ProfileRow(
                            label: 'Город регистрации',
                            value:
                                (city['display_name'] as String?) ??
                                (city['name'] as String? ?? '—'),
                          ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CompanyDiscountsPage(
                                authService: widget.authService,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.local_offer_outlined),
                          label: const Text('Мои дисконты компаний'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextButton(
                      onPressed: deleting ? null : confirmAccountDeletion,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: deleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Удалить учетную запись'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(value),
      ],
    ),
  );
}
