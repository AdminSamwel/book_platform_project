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

class CategoryBooksScreen extends StatefulWidget {
  final String? categorySlug;
  final String  categoryName;
  final int     bookCount;
  final bool    forYou;

  const CategoryBooksScreen({
    super.key,
    this.categorySlug,
    required this.categoryName,
    required this.bookCount,
    this.forYou = false,
  });

  @override
  State<CategoryBooksScreen> createState() => _CategoryBooksScreenState();
}

class _CategoryBooksScreenState extends State<CategoryBooksScreen> {
  final ApiService _api     = ApiService();
  List<dynamic>   _books    = [];
  bool            _loading  = true;
  String          _sortBy   = 'newest';
  bool            _freeOnly = false;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() => _loading = true);
    try {
      final books = await _api.fetchBooks(
        categorySlug: widget.categorySlug,
        isFree: _freeOnly ? true : null,
        forYou: widget.forYou ? true : null,
      );
      if (_sortBy == 'price_asc') {
        books.sort((a, b) =>
            (double.tryParse(a['price'].toString()) ?? 0)
                .compareTo(double.tryParse(b['price'].toString()) ?? 0));
      } else if (_sortBy == 'price_desc') {
        books.sort((a, b) =>
            (double.tryParse(b['price'].toString()) ?? 0)
                .compareTo(double.tryParse(a['price'].toString()) ?? 0));
      }
      if (mounted) setState(() { _books = books; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); // rebuild on lang change
    final pad   = Responsive.pagePadding(context);
    final cols  = Responsive.bookColumns(context);
    final ratio = Responsive.bookCardRatio(context);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildHeader()],
        body: Column(
          children: [
            _buildFilterBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(
                      color: AppTheme.primary))
                  : _books.isEmpty
                      ? _emptyState()
                      : CenteredContent(
                          child: GridView.builder(
                            padding: EdgeInsets.fromLTRB(pad, 12, pad, 80),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols,
                              childAspectRatio: ratio,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: _books.length,
                            itemBuilder: (_, i) => _bookCard(_books[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildHeader() {
    return SliverAppBar(
      expandedHeight: Responsive.isMobile(context) ? 152 : 180,
      pinned: true,
      backgroundColor: AppTheme.primary,
      foregroundColor: Colors.white,
      actions: const [
        LanguageDropdown(),
        SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
          padding: const EdgeInsets.fromLTRB(20, 80, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(widget.categoryName,
                  style: TextStyle(color: Colors.white,
                      fontSize: Responsive.titleSize(context),
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.bookCount} ${widget.bookCount == 1 ? "kitabu" : "vitabu"}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        title: Text(widget.categoryName,
            style: const TextStyle(fontSize: 16, color: Colors.white)),
        titlePadding: const EdgeInsets.only(left: 56, bottom: 14),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: AppTheme.card(context),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Sort dropdown
          PopupMenuButton<String>(
            initialValue: _sortBy,
            onSelected: (v) { setState(() => _sortBy = v); _loadBooks(); },
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'newest',
                  child: Text(S.sortNewest)),
              PopupMenuItem(value: 'price_asc',
                  child: Text(S.sortPriceAsc)),
              PopupMenuItem(value: 'price_desc',
                  child: Text(S.sortPriceDesc)),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.bg(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.sort_rounded, size: 16,
                    color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  _sortBy == 'price_asc' ? 'Bei: Chini'
                      : _sortBy == 'price_desc' ? 'Bei: Juu' : S.sortNewest,
                  style: TextStyle(fontSize: 12,
                      color: AppTheme.textPrimary(context)),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, size: 16,
                    color: AppTheme.textSecondary(context)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          // Free filter
          GestureDetector(
            onTap: () {
              setState(() => _freeOnly = !_freeOnly);
              _loadBooks();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _freeOnly
                    ? AppTheme.success.withValues(alpha: 0.1)
                    : AppTheme.bg(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _freeOnly ? AppTheme.success : AppTheme.borderColor(context),
                  width: _freeOnly ? 1.5 : 1,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.card_giftcard_rounded, size: 14,
                    color: _freeOnly ? AppTheme.success : AppTheme.textSecondary(context)),
                const SizedBox(width: 5),
                Text(S.freeOnly,
                    style: TextStyle(fontSize: 12,
                        color: _freeOnly
                            ? AppTheme.success : AppTheme.textPrimary(context),
                        fontWeight: _freeOnly
                            ? FontWeight.w600 : FontWeight.normal)),
              ]),
            ),
          ),
          const Spacer(),
          Text('${_books.length} vitabu',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary(context))),
        ],
      ),
    );
  }

  Widget _bookCard(dynamic book) {
    final isFree   = book['is_free'] == true;
    final isLocked = book['is_locked'] == true;
    final isAgeRestricted = book['is_age_restricted'] == true;
    final minAge   = (book['min_age'] is num) ? (book['min_age'] as num).toInt() : 0;
    final reqPlan  = book['required_plan_name']?.toString();
    final price    = book['price']?.toString() ?? '0';
    final title    = book['title']?.toString() ?? '';
    final author   = book['author_name']?.toString() ?? '';
    final cover    = book['cover_image']?.toString();
    final id       = book['id'] as int;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: id))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover — kubwa, kama Amazon
          Expanded(
            flex: 7,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8, offset: const Offset(2, 4))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    safeNetworkImage(cover, fit: BoxFit.cover,
                        placeholder: _placeholder(title)),
                    // Free badge
                    if (isFree)
                      Positioned(
                        top: 8, left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.success,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text('BURE',
                              style: TextStyle(color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    // Beji ya kikomo cha umri
                    if (minAge > 0)
                      Positioned(
                        top: 8, right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.danger,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(S.ageBadge(minAge),
                              style: const TextStyle(color: Colors.white,
                                  fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    // Locked overlay (kitabu kinahitaji mpango wa juu)
                    if (isLocked) ...[
                      Container(color: Colors.black.withValues(alpha: 0.45)),
                      Positioned.fill(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.lock_rounded,
                                    color: AppTheme.primary, size: 20),
                              ),
                              if (reqPlan != null) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(reqPlan,
                                      style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primary)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                    // Age-restricted overlay (kikomo cha umri)
                    if (isAgeRestricted && !isLocked) ...[
                      Container(color: Colors.black.withValues(alpha: 0.45)),
                      Positioned.fill(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.gpp_maybe_rounded,
                                color: AppTheme.danger, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Title
          Flexible(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary(context), height: 1.3)),
                const SizedBox(height: 2),
                Text(author,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10, color: AppTheme.textSecondary(context))),
                const SizedBox(height: 4),
                // Price
                Text(
                  isFree ? 'Bure' : 'TZS $price',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold,
                    color: isFree ? AppTheme.success : AppTheme.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(String title) {
    final colors = [
      [const Color(0xFF667EEA), const Color(0xFF764BA2)],
      [const Color(0xFF43E97B), const Color(0xFF38F9D7)],
      [const Color(0xFFFA709A), const Color(0xFFFEE140)],
      [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
      [const Color(0xFFA18CD1), const Color(0xFFFBC2EB)],
    ];
    final idx = title.isEmpty ? 0 : title.codeUnitAt(0) % colors.length;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors[idx],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book_rounded,
              color: Colors.white, size: 36),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(title,
                maxLines: 3, textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white,
                    fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.library_books_outlined, size: 52,
              color: AppTheme.primary),
        ),
        const SizedBox(height: 16),
        Text('${S.noBooksInCat} ${widget.categoryName}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
        const SizedBox(height: 8),
        Text(S.comingSoon,
            style: TextStyle(color: AppTheme.textSecondary(context))),
      ],
    ),
  );
}
