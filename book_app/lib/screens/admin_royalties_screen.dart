import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class AdminRoyaltiesScreen extends StatefulWidget {
  const AdminRoyaltiesScreen({super.key});

  @override
  State<AdminRoyaltiesScreen> createState() => _AdminRoyaltiesScreenState();
}

class _AdminRoyaltiesScreenState extends State<AdminRoyaltiesScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _pool;
  bool _loading = true;
  bool _distributing = false;
  String? _error;

  final _purchaseCtrl = TextEditingController();
  final _subscriptionCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _purchaseCtrl.dispose();
    _subscriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final settings = await _api.fetchRoyaltySettings();
      final pool = await _api.fetchRevenuePool();
      if (!mounted) return;
      _purchaseCtrl.text = '${settings['purchase_commission_percent']}';
      _subscriptionCtrl.text = '${settings['subscription_commission_percent']}';
      setState(() { _pool = pool; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _api.updateRoyaltySettings({
        'purchase_commission_percent': _purchaseCtrl.text.trim(),
        'subscription_commission_percent': _subscriptionCtrl.text.trim(),
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

  Future<void> _distribute() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.distributeNow),
        content: Text(S.confirmDistribute),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(S.yes)),
        ],
      ),
    );
    if (confirm != true) return;

    final now = DateTime.now();
    setState(() => _distributing = true);
    try {
      await _api.distributeRevenuePool(year: now.year, month: now.month);
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
    } finally {
      if (mounted) setState(() => _distributing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.royalties),
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
    final pool = _pool!;
    final breakdown = (pool['breakdown'] as List?) ?? [];
    final distributed = pool['distributed'] == true;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle(S.commissionSettings),
          const SizedBox(height: 12),
          _card(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _purchaseCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: S.purchaseCommission),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subscriptionCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: S.subscriptionCommission),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: _saveSettings, child: Text(S.save)),
              ),
            ],
          )),
          const SizedBox(height: 24),
          _sectionTitle('${S.currentMonthPool} (${pool['year']}-${pool['month'].toString().padLeft(2, '0')})'),
          const SizedBox(height: 12),
          _card(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv(S.totalPoolRevenue, 'TZS ${pool['total_revenue']}'),
              _kv(S.platformShare, 'TZS ${pool['platform_amount']}'),
              _kv(S.authorsPool, 'TZS ${pool['author_pool']}'),
              _kv(S.totalReads, '${pool['total_reads']}'),
              const SizedBox(height: 12),
              if (distributed)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(S.alreadyDistributed,
                          style: const TextStyle(color: AppTheme.success, fontSize: 12))),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _distributing ? null : _distribute,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                    icon: _distributing
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.payments_rounded),
                    label: Text(S.distributeNow),
                  ),
                ),
            ],
          )),
          const SizedBox(height: 24),
          _sectionTitle(S.distributionPreview),
          const SizedBox(height: 12),
          if (breakdown.isEmpty)
            _card(child: Center(child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(S.noData, style: TextStyle(color: AppTheme.textSecondary(context))),
            )))
          else
            ...breakdown.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _card(child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${b['title']}',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                              color: AppTheme.textPrimary(context)),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text('${b['author']} · ${b['reads']} reads · ${b['share_percent']}%',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context))),
                      ],
                    ),
                  ),
                  Text('TZS ${b['payout']}',
                    style: const TextStyle(fontWeight: FontWeight.bold,
                        fontSize: 13, color: AppTheme.primary)),
                ],
              )),
            )),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16,
          color: AppTheme.textPrimary(context)));

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.card(context),
      borderRadius: BorderRadius.circular(16),
      boxShadow: AppTheme.shadow(context),
    ),
    child: child,
  );

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context))),
        Text(v, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary(context))),
      ],
    ),
  );
}
