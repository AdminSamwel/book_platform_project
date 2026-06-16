import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class AdminPlansScreen extends StatefulWidget {
  const AdminPlansScreen({super.key});

  @override
  State<AdminPlansScreen> createState() => _AdminPlansScreenState();
}

class _AdminPlansScreenState extends State<AdminPlansScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _plans = [];
  Map<String, dynamic>? _settings;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.fetchAdminPlans(),
        _api.fetchSystemSettings(),
      ]);
      if (!mounted) return;
      setState(() {
        _plans    = results[0] as List;
        _settings = results[1] as Map<String, dynamic>;
        _loading  = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error   = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _editPlan(Map<String, dynamic> plan) async {
    final priceCtrl    = TextEditingController(text: '${plan['price']}');
    final durationCtrl = TextEditingController(text: '${plan['duration_days']}');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${plan['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Bei (TZS)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: durationCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Muda (siku)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(S.save)),
        ],
      ),
    );
    if (result != true || !mounted) return;
    try {
      await _api.updateAdminPlan(plan['id'] as int, {
        'price': priceCtrl.text.trim(),
        'duration_days': int.tryParse(durationCtrl.text.trim()) ?? plan['duration_days'],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(S.actionSuccess), backgroundColor: AppTheme.success));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppTheme.danger));
    }
  }

  Future<void> _editSettings() async {
    final basicCtrl = TextEditingController(
        text: '${_settings?['basic_book_limit'] ?? 5}');
    final audioCtrl = TextEditingController(
        text: '${_settings?['pro_audio_limit'] ?? 5}');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mipangilio ya Mfumo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vitabu vya Basic kwa kipindi',
                style: TextStyle(fontSize: 12,
                    color: AppTheme.textSecondary(ctx), fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextField(
              controller: basicCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Idadi ya vitabu (Basic)',
                prefixIcon: Icon(Icons.menu_book_rounded),
                hintText: 'k.m. 5',
              ),
            ),
            const SizedBox(height: 16),
            Text('Vitabu vya sauti vya Pro',
                style: TextStyle(fontSize: 12,
                    color: AppTheme.textSecondary(ctx), fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextField(
              controller: audioCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Idadi ya sauti (Pro)',
                prefixIcon: Icon(Icons.headphones_rounded),
                hintText: 'k.m. 5',
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '• Pro anapata idadi mara 2 ya Basic\n'
                '• Unlimited hana kikomo chochote',
                style: TextStyle(fontSize: 11,
                    color: AppTheme.textSecondary(ctx), height: 1.5),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.cancel)),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(S.save)),
        ],
      ),
    );
    if (result != true || !mounted) return;
    try {
      final updated = await _api.updateSystemSettings({
        'basic_book_limit': int.tryParse(basicCtrl.text.trim()) ?? 5,
        'pro_audio_limit':  int.tryParse(audioCtrl.text.trim())  ?? 5,
      });
      if (!mounted) return;
      setState(() => _settings = updated);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(S.actionSuccess), backgroundColor: AppTheme.success));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppTheme.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.managePlans),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, style: const TextStyle(color: AppTheme.danger)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: Text(S.retry)),
        ],
      ));
    }
    final colors = [
      [const Color(0xFF94A3B8), const Color(0xFFCBD5E1)],
      [const Color(0xFF6366F1), const Color(0xFF818CF8)],
      [const Color(0xFF7C3AED), const Color(0xFFA78BFA)],
      [const Color(0xFF0EA5E9), const Color(0xFF38BDF8)],
    ];
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Mipangilio ya Mfumo ─────────────────────────────────────────
          _sectionLabel('Mipangilio ya Vitabu kwa Mpango'),
          const SizedBox(height: 10),
          _settingsCard(),
          const SizedBox(height: 20),
          // ── Mipango ─────────────────────────────────────────────────────
          _sectionLabel(S.managePlans),
          const SizedBox(height: 10),
          ...List.generate(_plans.length, (i) {
            final p     = _plans[i];
            final level = (p['level'] as int?) ?? 0;
            final pair  = level < colors.length ? colors[level] : colors[1];
            return _planCard(p, pair);
          }),
        ],
      ),
    );
  }

  Widget _settingsCard() {
    final basic = _settings?['basic_book_limit'] ?? 5;
    final audio = _settings?['pro_audio_limit'] ?? 5;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadow(context),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.tune_rounded,
                    color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Mipangilio ya Vitabu',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                      color: AppTheme.textPrimary(context))),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: AppTheme.primary),
                tooltip: 'Hariri',
                onPressed: _editSettings,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _settingRow(Icons.menu_book_rounded, const Color(0xFF6366F1),
              'Basic — vitabu kwa kipindi', '$basic vitabu'),
          const SizedBox(height: 8),
          _settingRow(Icons.auto_awesome_rounded, const Color(0xFF7C3AED),
              'Pro — vitabu kwa kipindi', '${basic * 2} vitabu (2× Basic)'),
          const SizedBox(height: 8),
          _settingRow(Icons.headphones_rounded, const Color(0xFF0EA5E9),
              'Pro — vitabu vya sauti', '$audio vitabu'),
          const SizedBox(height: 8),
          _settingRow(Icons.all_inclusive_rounded, const Color(0xFF10B981),
              'Unlimited — vitabu vyote', 'Bila kikomo'),
        ],
      ),
    );
  }

  Widget _settingRow(IconData icon, Color color, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 12,
              color: AppTheme.textSecondary(context))),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(value, style: TextStyle(fontSize: 11,
              fontWeight: FontWeight.w700, color: color)),
        ),
      ],
    );
  }

  Widget _planCard(dynamic p, List<Color> colorPair) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.shadow(context),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colorPair,
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p['name']}',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                      color: AppTheme.textPrimary(context))),
                const SizedBox(height: 2),
                Text('TZS ${p['price']} · ${p['duration_days']} ${S.perDays}',
                  style: TextStyle(fontSize: 12,
                      color: AppTheme.textSecondary(context))),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppTheme.primary),
            onPressed: () => _editPlan(p),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String title) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 4, height: 20,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4C1D95), Color(0xFF4F46E5)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
          color: AppTheme.textPrimary(context))),
    ],
  );
}
