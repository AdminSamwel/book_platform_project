import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/book_provider.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'book_detail_screen.dart';
import 'my_library_screen.dart';
import 'wallet_screen.dart';
import 'subscription_screen.dart';
import 'profile_screen.dart';
import 'upload_book_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _categories = [];
  String? _selectedCategory;
  bool? _filterFree;
  String _searchQuery = '';
  String _username = '';
  String _userRole = 'reader';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    context.read<BookProvider>().fetchBooks();
    try {
      final cats    = await _api.fetchCategories();
      final profile = await _api.fetchProfile();
      if (mounted) {
        setState(() {
        _categories = cats;
        _username   = profile['username'] ?? '';
        _userRole   = profile['role'] ?? 'reader';
        });
      }
    } catch (_) {}
  }

  Future<void> _applyFilters() async {
    await context.read<BookProvider>().fetchBooks(
      categorySlug: _selectedCategory,
      isFree: _filterFree,
      search: _searchQuery.isEmpty ? null : _searchQuery,
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth     = context.read<AuthProvider>();
    final bookProv = context.watch<BookProvider>();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      drawer: _buildDrawer(auth),
      body: RefreshIndicator(
        onRefresh: _applyFilters,
        color: AppTheme.primary,
        child: CustomScrollView(
          slivers: [
            _buildSliverHeader(),
            SliverToBoxAdapter(child: _buildSearchBar()),
            SliverToBoxAdapter(child: _buildCategoryBar()),
            if (bookProv.isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()))
            else if (bookProv.books.isEmpty)
              SliverFillRemaining(child: _buildEmptyState())
            else
              _buildBookGrid(bookProv.books),
          ],
        ),
      ),
      floatingActionButton: _userRole == 'author'
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Pakia Kitabu'),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const UploadBookScreen())),
            )
          : null,
    );
  }

  Widget _buildSliverHeader() {
    return SliverAppBar(
      expandedHeight: 130,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.primary,
      foregroundColor: Colors.white,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: () {},
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
          padding: const EdgeInsets.fromLTRB(20, 80, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                _username.isEmpty
                    ? 'Habari! 👋'
                    : 'Habari, ${_username[0].toUpperCase()}${_username.substring(1)}! 👋',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Text('Gundua Vitabu Vipya',
                style: TextStyle(color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        title: const Text('Maktaba', style: TextStyle(fontSize: 16)),
        titlePadding: const EdgeInsets.only(left: 56, bottom: 14),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) { _searchQuery = v; _applyFilters(); },
        decoration: InputDecoration(
          hintText: 'Tafuta kitabu au mwandishi...',
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                    _applyFilters();
                  })
              : null,
          fillColor: Colors.white,
          filled: true,
        ),
      ),
    );
  }

  Widget _buildCategoryBar() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _catChip('Zote', null, Icons.grid_view_rounded),
          ..._categories.map((c) => _catChip(c['name'], c['slug'], Icons.bookmark_border_rounded)),
          _catChip('Bure', '__free__', Icons.card_giftcard_rounded),
        ],
      ),
    );
  }

  Widget _catChip(String label, String? slug, IconData icon) {
    final isFreeFilter = slug == '__free__';
    final selected = isFreeFilter
        ? (_filterFree == true)
        : (_selectedCategory == slug && _filterFree == null);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (isFreeFilter) {
              _filterFree = selected ? null : true;
              _selectedCategory = null;
            } else {
              _selectedCategory = selected ? null : slug;
              _filterFree = null;
            }
          });
          _applyFilters();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: selected ? AppTheme.primaryGradient : null,
            color: selected ? null : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? Colors.transparent : const Color(0xFFE5E7EB)),
            boxShadow: selected ? [BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.3),
              blurRadius: 8, offset: const Offset(0, 2))] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14,
                color: selected ? Colors.white : AppTheme.textMuted),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500,
                color: selected ? Colors.white : AppTheme.textDark)),
            ],
          ),
        ),
      ),
    );
  }

  SliverPadding _buildBookGrid(List<Book> books) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) => _bookCard(books[i]),
          childCount: books.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.62,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
      ),
    );
  }

  Widget _bookCard(Book book) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: book.id))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.07),
            blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    book.coverImage != null
                        ? Image.network(book.coverImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _coverPlaceholder())
                        : _coverPlaceholder(),
                    // Price badge
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: book.isFree
                              ? const LinearGradient(
                                  colors: [AppTheme.success, Color(0xFF059669)])
                              : AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4)],
                        ),
                        child: Text(
                          book.isFree ? 'BURE' : 'TZS ${book.price}',
                          style: const TextStyle(color: Colors.white,
                              fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Info
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: AppTheme.textDark)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 11,
                            color: AppTheme.textMuted),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(book.authorName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11, color: AppTheme.textMuted)),
                        ),
                      ],
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

  Widget _coverPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.15),
            AppTheme.secondary.withValues(alpha: 0.1)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.menu_book_rounded, size: 52,
            color: AppTheme.primary),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books_outlined, size: 72,
              color: AppTheme.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('Hakuna vitabu bado',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                color: AppTheme.textDark)),
          const SizedBox(height: 8),
          const Text('Vitabu vitaonekana hapa baada ya kupakiwa',
            style: TextStyle(color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildDrawer(AuthProvider auth) {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30, backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(_username.isEmpty ? 'U'
                    : _username[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 24,
                        fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                Text(_username,
                  style: const TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.bold)),
                Text(_userRole == 'author' ? '✍️ Mwandishi' : '📖 Msomaji',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _drawerItem(Icons.home_rounded, 'Nyumbani', () => Navigator.pop(context)),
                _drawerItem(Icons.library_books_rounded, 'Maktaba Yangu', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const MyLibraryScreen()));
                }),
                _drawerItem(Icons.account_balance_wallet_rounded, 'Mkoba', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const WalletScreen()));
                }),
                _drawerItem(Icons.star_rounded, 'Usajili', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const SubscriptionScreen()));
                }),
                _drawerItem(Icons.person_rounded, 'Wasifu Wangu', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const ProfileScreen()));
                }),
                const Divider(height: 24),
                _drawerItem(Icons.logout_rounded, 'Toka', () {
                  auth.logout();
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/', (r) => false);
                }, color: AppTheme.danger),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    final c = color ?? AppTheme.textDark;
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: c, size: 20),
      ),
      title: Text(label,
        style: TextStyle(color: c, fontWeight: FontWeight.w500, fontSize: 14)),
      onTap: onTap,
      horizontalTitleGap: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
