import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/safe_image.dart';
import 'book_detail_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.fetchWishlist();
      if (mounted) setState(() { _items = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(int bookId) async {
    final removed = _items.firstWhere((b) => b['id'] == bookId, orElse: () => null);
    setState(() => _items.removeWhere((b) => b['id'] == bookId));
    try {
      await _api.removeFromWishlist(bookId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(S.removedFromWishlist),
          backgroundColor: AppTheme.textMuted,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (_) {
      if (removed != null && mounted) setState(() => _items.add(removed));
    }
  }

  Future<void> _addToCart(int bookId) async {
    try {
      await _api.addToCart(bookId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(S.addedToCart),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppTheme.danger,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: Text(S.myWishlist),
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
                      itemBuilder: (_, i) => _wishlistTile(_items[i]),
                    ),
                  ),
                ),
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
              color: AppTheme.danger.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.favorite_border_rounded,
                size: 52, color: AppTheme.danger.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          Text(S.wishlistEmpty,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(context))),
          const SizedBox(height: 6),
          Text(S.wishlistEmptyHint,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context))),
        ],
      ),
    );
  }

  Widget _wishlistTile(dynamic book) {
    final isFree = book['is_free'] == true;
    final isPurchased = book['is_purchased'] == true;
    return Material(
      color: AppTheme.card(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => BookDetailScreen(bookId: book['id'] as int))),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: safeNetworkImage(book['cover_image']?.toString(),
                    width: 52, height: 70),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book['title']?.toString() ?? '',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary(context)),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(book['author_name']?.toString() ?? '',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context))),
                    const SizedBox(height: 4),
                    Text(isFree ? S.free : 'TZS ${book['price']}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                            color: isFree ? AppTheme.success : AppTheme.primary)),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.favorite_rounded, color: AppTheme.danger),
                    tooltip: S.removeFromWishlist,
                    onPressed: () => _remove(book['id'] as int),
                  ),
                  if (!isFree && !isPurchased)
                    IconButton(
                      icon: const Icon(Icons.add_shopping_cart_rounded, color: AppTheme.secondary),
                      tooltip: S.addToCart,
                      onPressed: () => _addToCart(book['id'] as int),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
