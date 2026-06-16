import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/book_provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/safe_image.dart';
import '../widgets/language_toggle.dart';
import 'book_detail_screen.dart';
import 'category_books_screen.dart';
import 'my_library_screen.dart';
import 'wallet_screen.dart';
import 'subscription_screen.dart';
import 'profile_screen.dart';
import 'upload_book_screen.dart';
import 'wishlist_screen.dart';
import 'cart_screen.dart';
import 'manage_categories_screen.dart';
import 'settings_screen.dart';
import '../widgets/notification_bell.dart';
import '../widgets/cart_button.dart';
import '../widgets/text_size_toggle.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api        = ApiService();
  List<dynamic>    _categories = [];
  bool             _loadingCats = true;
  String           _username    = '';
  String           _userRole    = 'reader';

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _username = auth.username;
    _userRole = auth.role;
    _loadData();
  }

  Future<void> _loadData() async {
    // Defer fetchBooks to after the first frame to avoid setState-during-build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bookProv = context.read<BookProvider>();
      bookProv.fetchBooks();
      bookProv.fetchBestSellers();
      if (_userRole == 'reader') bookProv.fetchForYou();
    });
    try {
      final cats = await _api.fetchCategories();
      if (mounted) setState(() { _categories = cats; _loadingCats = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingCats = false);
    }
  }

  void _openAllBooks({String? categoryName, bool forYou = false}) {
    final bookProv = context.read<BookProvider>();
    final count = forYou ? bookProv.forYou.length : bookProv.books.length;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CategoryBooksScreen(
        categoryName: categoryName ?? S.allBooks,
        bookCount: count,
        forYou: forYou,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); // rebuild on lang change
    final auth     = context.watch<AuthProvider>();
    final bookProv = context.watch<BookProvider>();
    final isWide   = !Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      drawer: isWide ? null : _buildDrawer(auth),
      body: isWide
          ? _wideLayout(auth, bookProv)
          : _mobileLayout(auth, bookProv),
      floatingActionButton: _userRole == 'author'
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.upload_file_rounded),
              label: Text(S.uploadBook),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const UploadBookScreen()))
                .then((_) => _loadData()),
            )
          : null,
    );
  }

  // ════════════════════════════════════════════
  // WIDE LAYOUT (Tablet + Desktop)
  // ════════════════════════════════════════════
  Widget _wideLayout(AuthProvider auth, BookProvider bookProv) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Side navigation
        _buildSideNav(auth),
        // Main content
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: CenteredContent(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWideHeader(auth),
                      _buildSearchBarWidget(),
                      _buildQuickActions(),
                      if (bookProv.bestSellers.isNotEmpty) ...[
                        _buildFeaturedBook(bookProv.bestSellers.first),
                        if (bookProv.bestSellers.length > 1) ...[
                          _buildSectionLabel(S.bestSellers),
                          _buildNewBooksRow(
                              bookProv.bestSellers.skip(1).take(4).toList()),
                        ],
                      ],
                      if (_userRole == 'reader' && bookProv.forYou.isNotEmpty) ...[
                        _buildSectionLabel(S.forYou, onViewAll: () => _openAllBooks(
                            categoryName: S.forYou, forYou: true)),
                        _buildNewBooksRow(bookProv.forYou),
                      ],
                      _buildSectionLabel(S.browseByCategory),
                      _buildCategoriesGrid(),
                      if (bookProv.books.isNotEmpty) ...[
                        _buildSectionLabel(S.newBooks, onViewAll: _openAllBooks),
                        _buildNewBooksRow(bookProv.books),
                      ],
                      const SizedBox(height: 80),
                    ],
                  )),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWideHeader(AuthProvider auth) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3730A3), Color(0xFF6D28D9), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.35),
            blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          // Bokeh circles
          Positioned(top: -50, right: -40, child: _bokeh(180, 0.09)),
          Positioned(top: 20, right: 160, child: _bokeh(50, 0.10)),
          Positioned(bottom: -30, left: -20, child: _bokeh(120, 0.07)),
          // Content
          Padding(
            padding: const EdgeInsets.all(26),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.waving_hand_rounded,
                            color: Colors.amber, size: 16),
                        const SizedBox(width: 7),
                        Text(
                          _username.isEmpty ? '${S.greeting}!'
                              : '${S.greeting}, ${_username[0].toUpperCase()}'
                                '${_username.substring(1)}!',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 14),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Text(S.discoverBooks,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 10),
                      Text(S.librarySubtitle,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 14)),
                    ],
                  ),
                ),
                const TextSizeToggle(light: true),
                const SizedBox(width: 8),
                const IconTheme(
                  data: IconThemeData(color: Colors.white),
                  child: Row(children: [CartButton(), NotificationBell()]),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen())),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35), width: 2.5),
                    ),
                    child: _userAvatar(radius: 26, fontSize: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // MOBILE LAYOUT
  // ════════════════════════════════════════════
  Widget _mobileLayout(AuthProvider auth, BookProvider bookProv) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primary,
      child: CustomScrollView(
        slivers: [
          _buildSliverAppBar(auth),
          SliverToBoxAdapter(child: _buildSearchBarWidget()),
          SliverToBoxAdapter(child: _buildQuickActions()),
          if (bookProv.bestSellers.isNotEmpty) ...[
            SliverToBoxAdapter(child: _buildFeaturedBook(bookProv.bestSellers.first)),
            if (bookProv.bestSellers.length > 1) ...[
              SliverToBoxAdapter(child: _buildSectionLabel(S.bestSellers)),
              SliverToBoxAdapter(child: _buildNewBooksRow(
                  bookProv.bestSellers.skip(1).take(4).toList())),
            ],
          ],
          if (_userRole == 'reader' && bookProv.forYou.isNotEmpty) ...[
            SliverToBoxAdapter(child: _buildSectionLabel(S.forYou, onViewAll: () => _openAllBooks(
                categoryName: S.forYou, forYou: true))),
            SliverToBoxAdapter(child: _buildNewBooksRow(bookProv.forYou)),
          ],
          SliverToBoxAdapter(child: _buildSectionLabel(S.browseByCategory)),
          SliverToBoxAdapter(child: _buildCategoriesGrid()),
          if (bookProv.books.isNotEmpty) ...[
            SliverToBoxAdapter(child: _buildSectionLabel(S.newBooks, onViewAll: _openAllBooks)),
            SliverToBoxAdapter(child: _buildNewBooksRow(bookProv.books)),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(AuthProvider auth) {
    final topInset      = MediaQuery.of(context).padding.top;
    final expandedHeight = topInset + kToolbarHeight + 120.0;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      floating: false,
      backgroundColor: AppTheme.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: Builder(builder: (ctx) => IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: () => Scaffold.of(ctx).openDrawer(),
      )),
      actions: [
        const TextSizeToggle(light: true),
        const SizedBox(width: 4),
        const LanguageDropdown(),
        const SizedBox(width: 4),
        const CartButton(),
        const NotificationBell(),
        IconButton(
          icon: const Icon(Icons.account_balance_wallet_rounded),
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const WalletScreen())),
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final settings   = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
          final minExtent  = settings?.minExtent  ?? (topInset + kToolbarHeight);
          final maxExtent  = settings?.maxExtent  ?? expandedHeight;
          final curExtent  = settings?.currentExtent ?? expandedHeight;
          final delta      = maxExtent - minExtent;
          final t          = delta <= 0 ? 0.0
              : ((1.0 - (curExtent - minExtent) / delta).clamp(0.0, 1.0));
          final fadeOpacity = (1.0 - t * 1.5).clamp(0.0, 1.0);

          return FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Gradient base
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF3730A3), Color(0xFF6D28D9), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                // Bokeh decorative circles
                Positioned(top: -45, right: -35,
                    child: _bokeh(190, 0.08)),
                Positioned(top: 35, right: 72,
                    child: _bokeh(58, 0.11)),
                Positioned(bottom: -30, left: -25,
                    child: _bokeh(140, 0.07)),
                Positioned(bottom: 20, right: 140,
                    child: _bokeh(36, 0.09)),
                // Fading content (greeting + avatar)
                Positioned.fill(
                  child: Opacity(
                    opacity: fadeOpacity,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          20, topInset + kToolbarHeight + 10, 20, 18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Row(children: [
                                  const Icon(Icons.waving_hand_rounded,
                                      color: Colors.amber, size: 15),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _username.isEmpty ? S.greeting
                                          : '${S.greeting}, ${_username[0].toUpperCase()}'
                                            '${_username.substring(1)}',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 5),
                                Text(S.discoverBooks,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text(S.librarySubtitle,
                                    style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.65),
                                        fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(
                                    builder: (_) => const ProfileScreen())),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    width: 2.5),
                                boxShadow: [BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 12, offset: const Offset(0, 4))],
                              ),
                              child: _userAvatar(radius: 24, fontSize: 19),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            title: Opacity(
              opacity: (t * 1.5).clamp(0.0, 1.0),
              child: Text(S.library,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 14),
            centerTitle: false,
          );
        },
      ),
    );
  }

  Widget _bokeh(double size, double alpha) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );

  // ════════════════════════════════════════════
  // SHARED WIDGETS
  // ════════════════════════════════════════════

  Widget _buildQuickActions() {
    final pad = Responsive.pagePadding(context);
    final items = <_HomeAction>[
      _HomeAction(Icons.library_books_rounded, S.myLibrary,
          const Color(0xFF4F46E5),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const MyLibraryScreen()))),
      _HomeAction(Icons.favorite_rounded, S.wishlist,
          const Color(0xFFE91E63),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const WishlistScreen()))),
      _HomeAction(Icons.star_rounded, S.subscription,
          const Color(0xFF9C27B0),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()))),
      _HomeAction(Icons.account_balance_wallet_rounded, S.wallet,
          const Color(0xFF10B981),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const WalletScreen()))),
      if (_userRole == 'reader')
        _HomeAction(Icons.tune_rounded, S.manageCategories,
            const Color(0xFFF59E0B),
            () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ManageCategoriesScreen()))
              .then((_) => _loadData())),
    ];

    return SizedBox(
      height: 82,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(pad, 10, pad, 6),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final a = items[i];
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: a.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.card(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: a.color.withValues(alpha: 0.2)),
                  boxShadow: [BoxShadow(
                    color: a.color.withValues(alpha: 0.08),
                    blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: a.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(a.icon, size: 18, color: a.color),
                    ),
                    const SizedBox(height: 5),
                    Text(a.label,
                        style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary(context),
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedBook(dynamic book) {
    final pad = Responsive.pagePadding(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 8, pad, 4),
      child: GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: book.id))),
        child: Container(
          height: 158,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.22),
                blurRadius: 22, offset: const Offset(0, 8)),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Blurred background
              safeNetworkImage(book.coverImage, fit: BoxFit.cover),
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.88),
                      Colors.black.withValues(alpha: 0.25),
                    ],
                  ),
                ),
              ),
              // Content row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Cover thumbnail
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: safeNetworkImage(book.coverImage,
                            width: 84, height: 120),
                      ),
                    ),
                  ),
                  // Info
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(7)),
                            child: Text(
                              S.t('🔥 Inayopendwa', '🔥 Trending'),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(book.title,
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 15,
                                  fontWeight: FontWeight.w800, height: 1.25)),
                          const SizedBox(height: 5),
                          Text(book.authorName,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.70),
                                  fontSize: 12)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (book.ratingsCount > 0) ...[
                                const Icon(Icons.star_rounded,
                                    color: Colors.amber, size: 14),
                                const SizedBox(width: 3),
                                Text(book.avgRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(width: 12),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: book.isFree
                                      ? AppTheme.success
                                      : Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.3))),
                                child: Text(
                                  book.isFree ? S.free : 'TZS ${book.price}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: 14),
                    child: Icon(Icons.arrow_forward_ios_rounded,
                        color: Colors.white54, size: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBarWidget() {
    final pad = Responsive.pagePadding(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 16, pad, 4),
      child: GestureDetector(
        onTap: _showSearchSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.15), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.07),
                blurRadius: 16, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.search_rounded,
                    color: AppTheme.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(S.searchHint,
                    style: TextStyle(
                        color: AppTheme.textSecondary(context),
                        fontSize: Responsive.bodySize(context))),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(S.search,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, {VoidCallback? onViewAll}) {
    final pad = Responsive.pagePadding(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 24, pad, 12),
      child: Row(
        children: [
          Container(
            width: 4, height: 22,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(
                  fontSize: Responsive.titleSize(context) - 1,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary(context),
                  letterSpacing: -0.2,
                )),
          ),
          if (onViewAll != null)
            GestureDetector(
              onTap: onViewAll,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(S.viewAll,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary)),
                    const SizedBox(width: 3),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 10, color: AppTheme.primary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    if (_loadingCats) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }
    if (_categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(S.noCategory,
            style: TextStyle(color: AppTheme.textSecondary(context),
                fontSize: Responsive.bodySize(context)))),
      );
    }

    final pad  = Responsive.pagePadding(context);
    final cols = Responsive.categoryColumns(context);
    final ratio = Responsive.categoryCardRatio(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: pad),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          childAspectRatio: ratio,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _categories.length,
        itemBuilder: (_, i) => _categoryCard(_categories[i]),
      ),
    );
  }

  Widget _categoryCard(dynamic cat) {
    final name      = cat['name']?.toString() ?? '';
    final slug      = cat['slug']?.toString() ?? '';
    final bookCount = cat['book_count'] as int? ?? 0;
    final covers    = (cat['cover_images'] as List<dynamic>?) ?? [];
    final colors    = _catColors(slug);
    final icon      = _catIcon(slug);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => CategoryBooksScreen(
          categorySlug: slug,
          categoryName: name,
          bookCount: bookCount,
        ),
      )),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: colors[0].withValues(alpha: 0.25),
            blurRadius: 10, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background
            covers.isNotEmpty
                ? _coverCollage(covers, colors)
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
            // Overlay gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.72),
                  ],
                  stops: const [0.3, 1.0],
                ),
              ),
            ),
            // Content
            Positioned(
              left: 12, right: 12, bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: Colors.white,
                          size: Responsive.isMobile(context) ? 14 : 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(name,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: Responsive.isMobile(context)
                                    ? 13 : 15)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          bookCount == 0
                              ? S.notStarted
                              : '$bookCount ${bookCount == 1 ? S.book : S.books}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white, size: 12),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverCollage(List<dynamic> covers, List<Color> colors) {
    if (covers.length == 1) {
      return safeNetworkImage(covers[0].toString(), fit: BoxFit.cover);
    }
    return GridView.count(
      crossAxisCount: 2,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      children: covers.take(4).map((url) =>
        safeNetworkImage(url.toString(), fit: BoxFit.cover)).toList(),
    );
  }

  Widget _buildNewBooksRow(List books) {
    final pad        = Responsive.pagePadding(context);
    final cardWidth  = Responsive.isMobile(context) ? 130.0
        : Responsive.isTablet(context) ? 160.0 : 180.0;
    final cardHeight = Responsive.isMobile(context) ? 210.0
        : Responsive.isTablet(context) ? 250.0 : 280.0;

    return SizedBox(
      height: cardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(pad, 0, pad, 8),
        itemCount: books.length,
        itemBuilder: (_, i) => _newBookCard(books[i], cardWidth),
      ),
    );
  }

  Widget _newBookCard(dynamic book, double width) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: book.id))),
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 14, offset: const Offset(0, 6)),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 2, offset: const Offset(0, 1)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Jalada la kitabu
                      safeNetworkImage(book.coverImage,
                          fit: BoxFit.cover,
                          placeholder: _bookPlaceholder(book.title)),
                      // Kivuli laini chini ya jalada kwa ajili ya beji
                      Positioned(
                        left: 0, right: 0, bottom: 0,
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.45),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Beji ya bei / "Bure"
                      Positioned(
                        top: 8, left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: book.isFree
                                ? AppTheme.success
                                : Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            book.isFree ? S.free : 'TZS ${book.price}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white,
                                fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      // Beji ya kikomo cha umri
                      if (book.minAge > 0)
                        Positioned(
                          top: 8, right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.danger,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(S.ageBadge(book.minAge),
                                style: const TextStyle(color: Colors.white,
                                    fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      // Beji ya tathmini (rating)
                      if (book.ratingsCount > 0)
                        Positioned(
                          right: 8, bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: Colors.amber, size: 13),
                                const SizedBox(width: 2),
                                Text(book.avgRating.toStringAsFixed(1),
                                    style: const TextStyle(color: Colors.white,
                                        fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      // Locked overlay (kitabu kinahitaji mpango wa juu)
                      if (book.isLocked) ...[
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
                                if (book.requiredPlanName != null) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(book.requiredPlanName!,
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
                      if (book.isAgeRestricted && !book.isLocked) ...[
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
                      // Mstari mwepesi wa pembeni unaoonyesha kingo za kitabu
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  width: 1),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(book.title,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: Responsive.bodySize(context),
                    fontWeight: FontWeight.w700, color: AppTheme.textPrimary(context),
                    height: 1.2)),
            const SizedBox(height: 2),
            Text(book.authorName,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context))),
          ],
        ),
      ),
    );
  }

  /// Avatar ya mtumiaji aliyeingia: inaonyesha picha ya profaili (avatar)
  /// kama imewekwa, vinginevyo herufi ya kwanza ya jina lake.
  Widget _userAvatar({required double radius, required double fontSize}) {
    final avatarUrl = context.watch<AuthProvider>().avatarUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white.withValues(alpha: 0.2),
      backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
          ? NetworkImage(avatarUrl)
          : null,
      child: (avatarUrl == null || avatarUrl.isEmpty)
          ? Text(
              _username.isEmpty ? 'U' : _username[0].toUpperCase(),
              style: TextStyle(color: Colors.white,
                  fontSize: fontSize, fontWeight: FontWeight.bold))
          : null,
    );
  }

  Widget _bookPlaceholder(String title) => Container(
    decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
    child: Center(
      child: Text(
        title.isNotEmpty ? title[0].toUpperCase() : 'K',
        style: const TextStyle(color: Colors.white,
            fontSize: 32, fontWeight: FontWeight.bold),
      ),
    ),
  );

  // ── Side Navigation (Tablet/Desktop) ──
  Widget _buildSideNav(AuthProvider auth) {
    final isDesktop = Responsive.isDesktop(context);
    final width     = isDesktop ? 240.0 : 72.0;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        boxShadow: AppTheme.isDark(context) ? const [] : [BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 10)],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                isDesktop ? 20 : 12, 40, isDesktop ? 20 : 12, 20),
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
            child: isDesktop ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _userAvatar(radius: 26, fontSize: 20),
                const SizedBox(height: 10),
                Text(_username,
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold)),
                Text(_userRole == 'author' ? S.author : S.reader,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
              ],
            ) : const Center(
              child: Icon(Icons.menu_book_rounded,
                  color: Colors.white, size: 28),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _sideItem(Icons.home_rounded, S.home, true, () {}),
                _sideItem(Icons.library_books_rounded, S.myLibrary, false,
                    () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const MyLibraryScreen()))),
                _sideItem(Icons.favorite_rounded, S.wishlist, false,
                    () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const WishlistScreen()))),
                _sideItem(Icons.shopping_cart_rounded, S.cart, false,
                    () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const CartScreen()))),
                if (_userRole == 'reader')
                  _sideItem(Icons.tune_rounded, S.manageCategories, false,
                      () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const ManageCategoriesScreen()))
                        .then((_) => _loadData())),
                _sideItem(Icons.account_balance_wallet_rounded, S.wallet, false,
                    () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const WalletScreen()))),
                _sideItem(Icons.star_rounded, S.subscription, false,
                    () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const SubscriptionScreen()))),
                _sideItem(Icons.person_rounded, S.profile, false,
                    () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const ProfileScreen()))),
                _sideItem(Icons.settings_rounded, S.settings, false,
                    () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const SettingsScreen()))),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Divider(),
                ),
                _sideItem(Icons.logout_rounded, S.logout, false, () {
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

  Widget _sideItem(IconData icon, String label, bool active,
      VoidCallback onTap, {Color? color}) {
    final c          = color ?? (active ? AppTheme.primary : AppTheme.textPrimary(context));
    final isDesktop  = Responsive.isDesktop(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: active
                ? AppTheme.primary.withValues(alpha: 0.1)
                : c.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: c, size: 20),
        ),
        title: isDesktop
            ? Text(label, style: TextStyle(
                color: c, fontWeight: active
                    ? FontWeight.w700 : FontWeight.w500, fontSize: 14))
            : null,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selected: active,
        selectedTileColor: AppTheme.primary.withValues(alpha: 0.06),
        contentPadding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 12 : 8, vertical: 0),
        minLeadingWidth: 0,
      ),
    );
  }

  // ── Mobile Drawer ──
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
                _userAvatar(radius: 30, fontSize: 24),
                const SizedBox(height: 12),
                Text(_username, style: const TextStyle(
                    color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.bold)),
                Text(_userRole == 'author' ? S.author : S.reader,
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _drawerItem(Icons.home_rounded, S.home,
                    () => Navigator.pop(context)),
                _drawerItem(Icons.library_books_rounded, S.myLibrary, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const MyLibraryScreen()));
                }),
                _drawerItem(Icons.favorite_rounded, S.wishlist, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const WishlistScreen()));
                }),
                _drawerItem(Icons.shopping_cart_rounded, S.cart, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const CartScreen()));
                }),
                if (_userRole == 'reader')
                  _drawerItem(Icons.tune_rounded, S.manageCategories, () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const ManageCategoriesScreen()))
                      .then((_) => _loadData());
                  }),
                _drawerItem(Icons.account_balance_wallet_rounded, S.wallet, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const WalletScreen()));
                }),
                _drawerItem(Icons.star_rounded, S.subscription, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const SubscriptionScreen()));
                }),
                _drawerItem(Icons.person_rounded, S.profile, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const ProfileScreen()));
                }),
                _drawerItem(Icons.settings_rounded, S.settings, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const SettingsScreen()));
                }),
                const Divider(height: 24),
                _drawerItem(Icons.logout_rounded, S.logout, () {
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
    final c = color ?? AppTheme.textPrimary(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: c, size: 20),
        ),
        title: Text(label, style: TextStyle(
            color: c, fontWeight: FontWeight.w500, fontSize: 14)),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      ),
    );
  }

  // ── Search ──
  void _showSearchSheet() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16,
                  MediaQuery.of(context).viewInsets.bottom + 8),
              child: TextField(
                controller: ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: S.searchHint,
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppTheme.primary),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.primary),
                  ),
                ),
                onSubmitted: (q) {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => _SearchScreen(query: q),
                  ));
                },
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_rounded, size: 56,
                        color: AppTheme.borderColor(context)),
                    const SizedBox(height: 12),
                    Text(S.typeToSearch,
                        style: TextStyle(color: AppTheme.textSecondary(context))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──
  IconData _catIcon(String slug) {
    const map = {
      'sayansi-teknolojia': Icons.science_rounded,
      'historia-utamaduni': Icons.history_edu_rounded,
      'biashara-uchumi':    Icons.business_center_rounded,
      'elimu-masomo':       Icons.school_rounded,
      'riwaya-hadithi':     Icons.auto_stories_rounded,
      'afya-maisha':        Icons.favorite_rounded,
      'dini-imani':         Icons.star_rounded,
      'watoto':             Icons.child_care_rounded,
    };
    return map[slug] ?? Icons.menu_book_rounded;
  }

  List<Color> _catColors(String slug) {
    const map = {
      'sayansi-teknolojia': [Color(0xFF667EEA), Color(0xFF764BA2)],
      'historia-utamaduni': [Color(0xFFCB356B), Color(0xFFBD3F32)],
      'biashara-uchumi':    [Color(0xFF11998E), Color(0xFF38EF7D)],
      'elimu-masomo':       [Color(0xFF4FACFE), Color(0xFF00F2FE)],
      'riwaya-hadithi':     [Color(0xFFFA709A), Color(0xFFFEE140)],
      'afya-maisha':        [Color(0xFF43E97B), Color(0xFF38F9D7)],
      'dini-imani':         [Color(0xFFE96B5A), Color(0xFFFAB95A)],
      'watoto':             [Color(0xFF84FAB0), Color(0xFF8FD3F4)],
    };
    return (map[slug] ?? [AppTheme.primary, AppTheme.secondary])
        .cast<Color>();
  }
}

// ── Quick action data ──────────────────────────────────────────────────────────
class _HomeAction {
  final IconData    icon;
  final String      label;
  final Color       color;
  final VoidCallback onTap;
  const _HomeAction(this.icon, this.label, this.color, this.onTap);
}

// ── Search Results Screen ──
class _SearchScreen extends StatefulWidget {
  final String query;
  const _SearchScreen({required this.query});
  @override
  State<_SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<_SearchScreen> {
  final ApiService _api   = ApiService();
  List<dynamic>   _books  = [];
  bool            _loading = true;

  @override
  void initState() { super.initState(); _search(); }

  Future<void> _search() async {
    try {
      final b = await _api.fetchBooks(search: widget.query);
      if (mounted) setState(() { _books = b; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); // rebuild on lang change
    final cols  = Responsive.bookColumns(context);
    final pad   = Responsive.pagePadding(context);
    final ratio = Responsive.bookCardRatio(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${S.searchResults}: "${widget.query}"'),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _books.isEmpty
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off_rounded, size: 64,
                        color: AppTheme.primary.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text('${S.noResults} "${widget.query}"',
                        style: TextStyle(color: AppTheme.textSecondary(context))),
                  ],
                ))
              : CenteredContent(
                  child: GridView.builder(
                    padding: EdgeInsets.all(pad),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      childAspectRatio: ratio,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _books.length,
                    itemBuilder: (_, i) {
                      final b = _books[i];
                      return GestureDetector(
                        onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) =>
                            BookDetailScreen(bookId: b['id'] as int))),
                        child: _buildResultCard(b),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildResultCard(dynamic b) {
    final isFree = b['is_free'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: AppTheme.shadow(context),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: safeNetworkImage(
                  b['cover_image']?.toString(), fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(b['title']?.toString() ?? '',
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
        Text(b['author_name']?.toString() ?? '',
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary(context))),
        Text(isFree ? S.free : 'TZS ${b['price']}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                color: isFree ? AppTheme.success : AppTheme.primary)),
      ],
    );
  }
}
