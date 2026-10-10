import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
  bool previewing = false;
  String? error;
  Map<String, dynamic>? invitationPreview;
  String? previewCode;

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

  Future<void> inspectInvitation() async {
    final code = codeController.text.trim();
    if (code.isEmpty || joining || previewing) return;
    setState(() {
      previewing = true;
      error = null;
    });
    try {
      final result = await widget.authService.companyInvitationPreview(code);
      if (!mounted) return;
      setState(() {
        invitationPreview = result;
        previewCode = code;
      });
    } on LoginException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Не удалось открыть приглашение');
    } finally {
      if (mounted) setState(() => previewing = false);
    }
  }

  Future<void> joinCompany() async {
    final code = codeController.text.trim();
    if (code.isEmpty || joining || previewCode != code) return;
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
      setState(() {
        invitationPreview = null;
        previewCode = null;
      });
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
                'Подключение к компании',
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
                enabled: !joining && !previewing,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onChanged: (value) {
                  if (previewCode != null && previewCode != value.trim()) {
                    setState(() {
                      invitationPreview = null;
                      previewCode = null;
                    });
                  }
                },
                onSubmitted: (_) => invitationPreview == null
                    ? inspectInvitation()
                    : joinCompany(),
                decoration: const InputDecoration(
                  labelText: 'Код приглашения или код магазина',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (invitationPreview != null)
                _invitationCard(invitationPreview!),
              FilledButton.icon(
                onPressed: joining || previewing
                    ? null
                    : invitationPreview == null
                    ? inspectInvitation
                    : invitationPreview!['already_member'] == true
                    ? null
                    : invitationPreview!['accepting_members'] != true
                    ? null
                    : joinCompany,
                icon: joining || previewing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    previewing
                        ? 'Проверяем код…'
                        : invitationPreview == null
                        ? 'Показать компанию'
                        : invitationPreview!['already_member'] == true
                        ? 'Вы уже подключены'
                        : invitationPreview!['accepting_members'] != true
                        ? 'Вступление временно недоступно'
                        : 'Добавить дисконт',
                  ),
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

  Widget _invitationCard(Map<String, dynamic> preview) {
    final company = preview['company'] as Map<String, dynamic>;
    final invitedBy = preview['invited_by'] as String?;
    final invitationCity = preview['invitation_city'] as Map<String, dynamic>?;
    final stores = (preview['stores'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final pointsByCity = <String, List<Map<String, dynamic>>>{};
    for (final store in stores) {
      final city = store['city'] as Map<String, dynamic>?;
      final cityName = city?['name'] as String? ?? 'Город не указан';
      pointsByCity.putIfAbsent(cityName, () => []).add(store);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              company['name'] as String? ?? 'Компания',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            if (invitedBy != null) ...[
              const SizedBox(height: 6),
              Text('Вас приглашает: $invitedBy'),
            ],
            if (invitationCity != null) ...[
              const SizedBox(height: 4),
              Text(
                'Город приглашения: ${invitationCity['name']}',
                style: const TextStyle(color: Colors.blueGrey),
              ),
            ],
            if (company['short_description'] is String &&
                (company['short_description'] as String).isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(company['short_description'] as String),
            ],
            if (preview['has_stores_in_user_city'] != true)
              const _NoticeCard(
                message: 'В вашем городе нет этой компании',
                icon: Icons.location_city,
              ),
            if (preview['accepting_members'] != true)
              const _NoticeCard(
                message: 'Компания временно не принимает новых участников.',
                icon: Icons.info_outline,
              ),
            const SizedBox(height: 14),
            Text(
              'Точки компании',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (stores.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Сейчас нет активных точек.'),
              )
            else
              ...pointsByCity.entries.map((entry) {
                final isInvitationCity = entry.value.any(
                  (store) => store['invitation_city'] == true,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (isInvitationCity)
                          const Chip(
                            label: Text('Город приглашения'),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    ...entry.value.map(_storeCard),
                  ],
                );
              }),
            if (stores.any(_hasCoordinates)) ...[
              const SizedBox(height: 16),
              Text(
                'Все точки на карте',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _storesMap(stores),
            ] else if (stores.isNotEmpty) ...[
              const SizedBox(height: 12),
              const _NoticeCard(
                message:
                    'Для показа точек на карте нужно добавить их координаты.',
                icon: Icons.map_outlined,
              ),
            ],
            if (company['description'] is String &&
                (company['description'] as String).isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(company['description'] as String),
            ],
          ],
        ),
      ),
    );
  }

  Widget _storeCard(Map<String, dynamic> store) {
    final photos = (store['photos'] as List? ?? const [])
        .whereType<String>()
        .take(5)
        .toList(growable: false);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photos.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    _photoUrl(photos[index]),
                    width: 160,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 160,
                      color: const Color(0xFFF2F5F8),
                      alignment: Alignment.center,
                      child: const Icon(Icons.storefront_outlined),
                    ),
                  ),
                ),
              ),
            ),
          if (store['name'] is String && (store['name'] as String).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                store['name'] as String,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 3),
          Text(store['address'] as String? ?? 'Адрес не указан'),
          if (store['phone'] is String && (store['phone'] as String).isNotEmpty)
            Text(store['phone'] as String),
          if (store['work_schedule'] is String &&
              (store['work_schedule'] as String).isNotEmpty)
            Text(
              store['work_schedule'] as String,
              style: const TextStyle(color: Colors.blueGrey),
            ),
        ],
      ),
    );
  }

  String _photoUrl(String photo) {
    final uri = Uri.tryParse(photo);
    if (uri != null && uri.hasAuthority) return photo;
    final base = Uri.tryParse(widget.authService.baseUrl);
    return base?.resolve(photo).toString() ?? photo;
  }

  bool _hasCoordinates(Map<String, dynamic> store) =>
      store['latitude'] is num && store['longitude'] is num;

  Widget _storesMap(List<Map<String, dynamic>> stores) {
    final locations = stores.where(_hasCoordinates).toList(growable: false);
    final coordinates = locations
        .map(
          (store) => LatLng(
            (store['latitude'] as num).toDouble(),
            (store['longitude'] as num).toDouble(),
          ),
        )
        .toList(growable: false);
    final first = coordinates.first;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 250,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: first,
            initialZoom: 12,
            initialCameraFit: coordinates.length > 1
                ? CameraFit.coordinates(
                    coordinates: coordinates,
                    padding: const EdgeInsets.all(36),
                    maxZoom: 14,
                  )
                : null,
            maxZoom: 18,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.gorod_online',
              maxZoom: 19,
            ),
            MarkerLayer(
              markers: [
                for (var index = 0; index < locations.length; index++)
                  Marker(
                    point: coordinates[index],
                    width: 42,
                    height: 48,
                    child: Column(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF56622),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.location_on,
                          color: Color(0xFFF56622),
                          size: 14,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ],
            ),
          ],
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

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4EA),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFF56622), size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ],
    ),
  );
}
