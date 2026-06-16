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
      final plans = await _api.fetchAdminPlans();
      if (!mounted) return;
      setState(() { _plans = plans; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _editPlan(Map<String, dynamic> plan) async {
    final priceCtrl = TextEditingController(text: '${plan['price']}');
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
              decoration: const InputDecoration(labelText: 'Price (TZS)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: durationCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Duration (days)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(S.save)),
        ],
      ),
    );
    if (result != true) return;
    try {
      await _api.updateAdminPlan(plan['id'] as int, {
        'price': priceCtrl.text.trim(),
        'duration_days': int.tryParse(durationCtrl.text.trim()) ?? plan['duration_days'],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(S.actionSuccess),
        backgroundColor: AppTheme.success,
      ));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppTheme.danger,
      ));
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
      return Center(child: Text(_error!, style: const TextStyle(color: AppTheme.danger)));
    }
    if (_plans.isEmpty) {
      return Center(child: Text(S.noData, style: TextStyle(color: AppTheme.textSecondary(context))));
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
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _plans.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final p = _plans[i];
          final level = (p['level'] as int?) ?? 0;
          final colorPair = level < colors.length ? colors[level] : colors[1];
          return Container(
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
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context))),
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
        },
      ),
    );
  }
}
