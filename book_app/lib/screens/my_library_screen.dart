import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/safe_image.dart';
import '../widgets/language_toggle.dart';
import 'book_detail_screen.dart';

class MyLibraryScreen extends StatefulWidget {
  const MyLibraryScreen({super.key});

  @override
  State<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _MyLibraryScreenState extends State<MyLibraryScreen> {
  final ApiService  _api    = ApiService();
  List<dynamic>     _books  = [];
  bool              _loading = true;
  String            _filter  = 'all'; // all | saved | purchased

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    setState(() => _loading = true);
    try {
      final books = await _api.fetchLibrary();
      if (mounted) setState(() { _books = books; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _filteredBooks {
    if (_filter == 'saved')     return _books.where((b) => b['is_saved'] == true && b['is_purchased'] != true).toList();
    if (_filter == 'purchased') return _books.where((b) => b['is_purchased'] == true).toList();
    return _books;
  }

  Future<void> _removeFromLibrary(int bookId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(S.t('Toa kwenye Maktaba?', 'Remove from Library?')),
        content: Text(S.t(
          '"$title" itatolewa kwenye maktaba yako.',
          '"$title" will be removed from your library.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.t('Toa', 'Remove'))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.removeFromLibrary(bookId);
      _loadLibrary();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(S.t('Imetolewa kwenye maktaba', 'Removed from library')),
        backgroundColor: AppTheme.textMuted,
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$e'), backgroundColor: AppTheme.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    final books = _filteredBooks;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: Text(S.myLibrary),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
        actions: const [
          LanguageDropdown(),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          _buildFilterBar(),
          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(
                    color: AppTheme.primary))
                : books.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        onRefresh: _loadLibrary,
                        color: AppTheme.primary,
                        child: GridView.builder(
                          padding: EdgeInsets.fromLTRB(
                            Responsive.pagePadding(context), 12,
                            Responsive.pagePadding(context), 80),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: Responsive.bookColumns(context),
                            childAspectRatio: 0.62,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: books.length,
                          itemBuilder: (_, i) => _bookCard(books[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: AppTheme.card(context),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('all',
                    S.t('Vyote (${_books.length})', 'All (${_books.length})')),
                  const SizedBox(width: 8),
                  _filterChip('saved',
                    S.t('Zilizohifadhiwa', 'Saved'),
                    icon: Icons.bookmark_rounded),
                  const SizedBox(width: 8),
                  _filterChip('purchased',
                    S.t('Zilizononuliwa', 'Purchased'),
                    icon: Icons.shopping_bag_rounded),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label, {IconData? icon}) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : AppTheme.bg(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppTheme.primary : AppTheme.borderColor(context)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 14,
                color: active ? Colors.white : AppTheme.textSecondary(context)),
            const SizedBox(width: 5),
          ],
          Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppTheme.textSecondary(context))),
        ]),
      ),
    );
  }

  Widget _bookCard(dynamic book) {
    final id          = book['id'] as int;
    final title       = book['title']?.toString() ?? '';
    final author      = book['author_name']?.toString() ?? '';
    final cover       = book['cover_image']?.toString();
    final isPurchased = book['is_purchased'] == true;
    final isSaved     = book['is_saved'] == true;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: id))),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppTheme.shadow(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cover ──
            Expanded(
              flex: 6,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    safeNetworkImage(cover, fit: BoxFit.cover,
                      placeholder: _placeholder(title)),
                    // Gradient bottom
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent,
                              Colors.black.withValues(alpha: 0.55)],
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_circle_fill_rounded,
                                color: Colors.white, size: 15),
                            const SizedBox(width: 4),
                            Text(S.readText,
                                style: const TextStyle(color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    // Badge: Saved / Purchased
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isPurchased
                              ? AppTheme.success
                              : AppTheme.primary.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(isPurchased
                              ? Icons.check_rounded : Icons.bookmark_rounded,
                              color: Colors.white, size: 10),
                          const SizedBox(width: 3),
                          Text(isPurchased
                              ? S.t('Nununuliwa', 'Bought')
                              : S.t('Hifadhi', 'Saved'),
                              style: const TextStyle(color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Info ──
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Flexible: kwenye skrini finyu kichwa kinapungua hadi
                    // mstari 1 badala ya kufurika (overflow) chini ya kadi
                    Flexible(
                      child: Text(title, maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary(context), height: 1.2)),
                    ),
                    const SizedBox(height: 2),
                    Text(author, maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10,
                            color: AppTheme.textSecondary(context))),
                    const Spacer(),
                    // Kitufe cha kutoa (kwa vitabu vilivyohifadhiwa tu, si vilivyonunuliwa)
                    if (isSaved && !isPurchased)
                      GestureDetector(
                        onTap: () => _removeFromLibrary(id, title),
                        child: Row(children: [
                          const Icon(Icons.bookmark_remove_rounded,
                              size: 13,
                              color: AppTheme.danger),
                          const SizedBox(width: 3),
                          Text(S.t('Toa', 'Remove'),
                              style: const TextStyle(fontSize: 10,
                                  color: AppTheme.danger)),
                        ]),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(String title) => Container(
    decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
    child: Center(
      child: Text(title.isNotEmpty ? title[0].toUpperCase() : 'K',
          style: const TextStyle(color: Colors.white,
              fontSize: 28, fontWeight: FontWeight.bold)),
    ),
  );

  Widget _emptyState() {
    final isSavedFilter = _filter == 'saved';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSavedFilter
                    ? Icons.bookmark_border_rounded
                    : Icons.library_books_outlined,
                size: 52, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            Text(
              _filter == 'all'
                  ? S.t('Maktaba yako iko tupu', 'Your library is empty')
                  : _filter == 'saved'
                      ? S.t('Hakuna vitabu vilivyohifadhiwa', 'No saved books')
                      : S.t('Hakuna vitabu vilivyononuliwa', 'No purchased books'),
              style: TextStyle(fontSize: 17,
                  fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _filter == 'all'
                  ? S.t(
                      'Bonyeza ikoni ya bookmark\nkwenye kitabu chochote kukiongeza hapa',
                      'Tap the bookmark icon\non any book to add it here')
                  : S.t(
                      'Rudi kwenye duka la vitabu\nna uhifadhi vitabu unavyovipenda',
                      'Go back to the book store\nand save books you like'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.textSecondary(context), height: 1.5, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
