import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/wallet_provider.dart';
import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/safe_image.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  bool _checkingOut = false;
  List<dynamic> _items = [];
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.fetchCart();
      final items = (data['items'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _items = items;
          _selected
            ..clear()
            ..addAll(items.map((it) => it['book_id'] as int));
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(int bookId) async {
    final removed = _items.firstWhere((it) => it['book_id'] == bookId, orElse: () => null);
    setState(() {
      _items.removeWhere((it) => it['book_id'] == bookId);
      _selected.remove(bookId);
    });
    try {
      await _api.removeFromCart(bookId);
    } catch (_) {
      if (removed != null && mounted) {
        setState(() {
          _items.add(removed);
          _selected.add(bookId);
        });
      }
    }
  }

  double _priceOf(dynamic item) =>
      item['is_free'] == true ? 0 : double.tryParse('${item['price']}') ?? 0;

  double get _selectedTotal => _items
      .where((it) => _selected.contains(it['book_id']))
      .fold(0.0, (sum, it) => sum + _priceOf(it));

  Future<void> _checkout({required bool selectedOnly}) async {
    if (selectedOnly && _selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(S.selectAtLeastOne), backgroundColor: AppTheme.warning));
      return;
    }
    setState(() => _checkingOut = true);
    try {
      final result = await _api.checkoutCart(
          bookIds: selectedOnly ? _selected.toList() : null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${S.checkoutSuccess}: TZS ${result['total_paid']}'),
          backgroundColor: AppTheme.success,
        ));
        await context.read<WalletProvider>().fetchWallet();
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppTheme.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    final total = _items.fold(0.0, (sum, it) => sum + _priceOf(it));

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: Text(S.myCart),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _items.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CenteredContent(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _cartTile(_items[i]),
                    ),
                  ),
                ),
      bottomNavigationBar: _items.isEmpty ? null : _buildBillBar(total),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shopping_cart_outlined,
                size: 52, color: AppTheme.secondary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          Text(S.cartEmpty,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(context))),
          const SizedBox(height: 6),
          Text(S.cartEmptyHint,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context))),
        ],
      ),
    );
  }

  Widget _cartTile(dynamic item) {
    final isFree = item['is_free'] == true;
    final bookId = item['book_id'] as int;
    final selected = _selected.contains(bookId);
    return Material(
      color: AppTheme.card(context),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              activeColor: AppTheme.primary,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selected.add(bookId);
                  } else {
                    _selected.remove(bookId);
                  }
                });
              },
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: safeNetworkImage(item['cover_image']?.toString(),
                  width: 52, height: 70),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['title']?.toString() ?? '',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary(context)),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(item['author_name']?.toString() ?? '',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context))),
                  const SizedBox(height: 4),
                  Text(isFree ? S.free : 'TZS ${item['price']}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                          color: isFree ? AppTheme.success : AppTheme.primary)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger),
              onPressed: () => _remove(bookId),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillBar(double total) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        boxShadow: AppTheme.isDark(context)
            ? const []
            : [BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10, offset: const Offset(0, -3))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${S.total} (${_items.length})',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context))),
                Text('TZS ${total.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary(context))),
              ],
            ),
            if (_selected.length != _items.length) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${S.paySelected} (${_selected.length})',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context))),
                  Text('TZS ${_selectedTotal.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                          color: AppTheme.primary)),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _checkingOut ? null : () => _checkout(selectedOnly: true),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                    ),
                    child: Text(S.paySelected),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _checkingOut ? null : () => _checkout(selectedOnly: false),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppTheme.primary,
                    ),
                    child: _checkingOut
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(S.payAll, style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
