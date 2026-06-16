import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

class AuthorReadersScreen extends StatefulWidget {
  const AuthorReadersScreen({super.key});

  @override
  State<AuthorReadersScreen> createState() => _AuthorReadersScreenState();
}

class _AuthorReadersScreenState extends State<AuthorReadersScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  int _totalReaders = 0;
  List<dynamic> _books = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.fetchAuthorReaders();
      if (mounted) {
        setState(() {
          _totalReaders = (data['total_readers'] as num?)?.toInt() ?? 0;
          _books = data['books'] ?? [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: Text(S.readersStats),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _load,
              child: CenteredContent(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _totalCard(),
                    const SizedBox(height: 20),
                    Text(S.readersPerBook,
                        style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
                    const SizedBox(height: 12),
                    if (_books.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(S.noReadersYet,
                              style: TextStyle(color: AppTheme.textSecondary(context))),
                        ),
                      )
                    else
                      ..._books.map((b) => _bookReaderTile(b)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _totalCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
              blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$_totalReaders',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 30, fontWeight: FontWeight.bold)),
              Text(S.totalReaders,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showShareStats(int bookId, String title) async {
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<Map<String, dynamic>>(
        future: _api.fetchBookShareStats(bookId),
        builder: (ctx, snapshot) {
          if (!snapshot.hasData) {
            return AlertDialog(
              title: Text(S.shareStats),
              content: const SizedBox(
                  height: 80, child: Center(child: CircularProgressIndicator())),
            );
          }
          final data = snapshot.data!;
          final totalClicks = data['total_clicks'] ?? 0;
          final signups = data['signups'] ?? 0;
          final byPlatform = (data['by_platform'] as Map?) ?? {};
          return AlertDialog(
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${S.totalShareClicks}: $totalClicks',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${S.totalSignups}: $signups',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                if (byPlatform.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...byPlatform.entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('${e.key.toString().isEmpty ? "?" : e.key}: ${e.value}'),
                      )),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(S.close),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bookReaderTile(dynamic b) {
    final cover = b['cover_image'] as String?;
    final bookId = (b['book_id'] as num?)?.toInt();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: cover != null
                ? Image.network(cover, width: 48, height: 64, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _coverPlaceholder())
                : _coverPlaceholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(b['title']?.toString() ?? '',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary(context)),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_rounded, size: 14, color: AppTheme.primary),
                  const SizedBox(width: 4),
                  Text('${b['readers']}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                          color: AppTheme.primary)),
                ],
              ),
              const SizedBox(height: 2),
              Text('${S.buyersLabel}: ${b['buyers']}',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context))),
            ],
          ),
          if (bookId != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.share_rounded, size: 18, color: AppTheme.textSecondary(context)),
              tooltip: S.shareStats,
              onPressed: () => _showShareStats(bookId, b['title']?.toString() ?? ''),
            ),
          ],
        ],
      ),
    );
  }

  Widget _coverPlaceholder() => Container(
        width: 48, height: 64,
        color: AppTheme.borderColor(context),
        child: Icon(Icons.menu_book_rounded, color: AppTheme.textSecondary(context), size: 20),
      );
}
