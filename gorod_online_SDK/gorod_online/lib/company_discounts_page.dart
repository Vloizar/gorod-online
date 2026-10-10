import 'package:flutter/material.dart';

import 'auth_service.dart';

class CompanyDiscountsPage extends StatefulWidget {
  const CompanyDiscountsPage({super.key, required this.authService});

  final AuthService authService;

  @override
  State<CompanyDiscountsPage> createState() => _CompanyDiscountsPageState();
}

class _CompanyDiscountsPageState extends State<CompanyDiscountsPage> {
  final codeController = TextEditingController();
  List<Map<String, dynamic>> memberships = const [];
  bool loading = true;
  bool joining = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadMemberships();
  }

  Future<void> loadMemberships() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.authService.companyMemberships();
      if (mounted) setState(() => memberships = result);
    } on LoginException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted)
        setState(() => error = 'Не удалось загрузить список компаний');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> joinCompany() async {
    final code = codeController.text.trim();
    if (code.isEmpty || joining) return;
    setState(() {
      joining = true;
      error = null;
    });
    try {
      final result = await widget.authService.joinCompany(code);
      final member = result['membership'] as Map<String, dynamic>;
      final company = member['company'] as Map<String, dynamic>;
      final alreadyMember = result['already_member'] == true;
      final bonus = result['welcome_bonus'] as int? ?? 0;
      codeController.clear();
      await loadMemberships();
      if (!mounted) return;
      setState(() => joining = false);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(
            alreadyMember ? Icons.check_circle_outline : Icons.card_giftcard,
            color: const Color(0xFFF56622),
            size: 34,
          ),
          title: Text(
            alreadyMember ? 'Вы уже подключены' : 'Дисконт подключён',
          ),
          content: Text(
            alreadyMember
                ? 'Вы уже участвуете в программе «${company['name']}».'
                : bonus > 0
                ? 'Вы подключили дисконт компании «${company['name']}».\n\nВам начислено $bonus приветственных бонусов.'
                : 'Вы подключили дисконт компании «${company['name']}».',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Понятно'),
            ),
          ],
        ),
      );
    } on LoginException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Не удалось подключить компанию');
    } finally {
      if (mounted) setState(() => joining = false);
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Дисконт')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadMemberships,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Мои компании',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF17283D),
                ),
              ),
              const SizedBox(height: 12),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (error != null && memberships.isEmpty)
                _MessageCard(
                  message: error!,
                  action: TextButton(
                    onPressed: loadMemberships,
                    child: const Text('Повторить'),
                  ),
                )
              else if (memberships.isEmpty)
                const _MessageCard(
                  message: 'Вы пока не подключили дисконты компаний.',
                )
              else
                ...memberships.map(_membershipCard),
              const SizedBox(height: 24),
              Text(
                'Добавить дисконт',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF17283D),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Введите код приглашения от друга или код магазина.'),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                enabled: !joining,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => joinCompany(),
                decoration: const InputDecoration(
                  labelText: 'Код приглашения или код магазина',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (error != null && memberships.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              FilledButton.icon(
                onPressed: joining ? null : joinCompany,
                icon: joining
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Подключить дисконт'),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF56622),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _membershipCard(Map<String, dynamic> membership) {
    final company = membership['company'] as Map<String, dynamic>;
    final inviter = membership['invited_by'] as String?;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              company['name'] as String? ?? 'Компания',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.monetization_on_outlined,
                  color: Color(0xFFF56622),
                ),
                const SizedBox(width: 6),
                Text('Бонусный баланс: ${membership['bonus_balance'] ?? 0}'),
              ],
            ),
            if (inviter != null) ...[
              const SizedBox(height: 4),
              Text(
                'Пригласил(а): $inviter',
                style: const TextStyle(color: Colors.blueGrey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          if (action != null) action!,
        ],
      ),
    ),
  );
}
