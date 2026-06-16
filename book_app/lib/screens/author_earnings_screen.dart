import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class AuthorEarningsScreen extends StatefulWidget {
  const AuthorEarningsScreen({super.key});

  @override
  State<AuthorEarningsScreen> createState() => _AuthorEarningsScreenState();
}

class _AuthorEarningsScreenState extends State<AuthorEarningsScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _data;
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
      final data = await _api.fetchMyEarnings();
      if (!mounted) return;
      setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.myEarnings),
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
    final data = _data!;
    final entries = (data['entries'] as List?) ?? [];

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _summaryCard(S.fromPurchases, data['total_purchase'])),
              const SizedBox(width: 12),
              Expanded(child: _summaryCard(S.fromSubscriptions, data['total_subscription'])),
            ],
          ),
          const SizedBox(height: 12),
          _summaryCard(S.totalEarnings, data['total'], highlight: true),
          const SizedBox(height: 24),
          Text(S.earningsHistory,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16,
                  color: AppTheme.textPrimary(context))),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.card(context),
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.shadow(context),
              ),
              child: Center(child: Text(S.noData, style: TextStyle(color: AppTheme.textSecondary(context)))),
            )
          else
            ...entries.map((e) => _entryCard(e)),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, dynamic amount, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight ? AppTheme.primary : AppTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12,
              color: highlight ? Colors.white70 : AppTheme.textSecondary(context))),
          const SizedBox(height: 6),
          Text('TZS $amount', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
              color: highlight ? Colors.white : AppTheme.textPrimary(context))),
        ],
      ),
    );
  }

  Widget _entryCard(Map<String, dynamic> e) {
    final isSubscription = e['source'] == 'subscription';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppTheme.shadow(context),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isSubscription ? AppTheme.accent : AppTheme.success).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isSubscription ? Icons.menu_book_rounded : Icons.shopping_cart_rounded,
                color: isSubscription ? AppTheme.accent : AppTheme.success,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${e['book_title']}',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                        color: AppTheme.textPrimary(context)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    isSubscription
                        ? '${e['year']}-${e['month'].toString().padLeft(2, '0')} · ${e['reads']} reads · ${e['share_percent']}%'
                        : (isSubscription ? S.fromSubscriptions : S.fromPurchases),
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
                  ),
                ],
              ),
            ),
            Text('TZS ${e['amount']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
          ],
        ),
      ),
    );
  }
}
