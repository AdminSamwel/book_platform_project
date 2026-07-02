import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/wallet_provider.dart';
import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/safe_image.dart';
import '../widgets/language_toggle.dart';
import '../widgets/notification_bell.dart';
import 'upload_book_screen.dart';
import 'edit_book_screen.dart';
import 'wallet_screen.dart';
import 'profile_screen.dart';
import 'home_screen.dart';
import 'author_readers_screen.dart';
import 'author_earnings_screen.dart';

class AuthorDashboardScreen extends StatefulWidget {
  const AuthorDashboardScreen({super.key});

  @override
  State<AuthorDashboardScreen> createState() => _AuthorDashboardScreenState();
}

class _AuthorDashboardScreenState extends State<AuthorDashboardScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _myBooks = [];
  bool _loading          = true;
  int _totalReaders      = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Tumia my-books endpoint — inapata vitabu vyote pamoja na visivyochapishwa
      final myBooks = await _api.fetchMyBooks();

      if (!mounted) return;
      await context.read<WalletProvider>().fetchWallet();

      int totalReaders = _totalReaders;
      try {
        final readersData = await _api.fetchAuthorReaders();
        totalReaders = (readersData['total_readers'] as num?)?.toInt() ?? 0;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _myBooks = myBooks;
          _totalReaders = totalReaders;
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
    final auth   = context.watch<AuthProvider>();
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      drawer: _buildDrawer(auth),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppTheme.primary,
        child: CustomScrollView(
          slivers: [
            _buildHeader(auth),
            SliverToBoxAdapter(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(child: CircularProgressIndicator(
                          color: AppTheme.primary)))
                  : Column(
                      children: [
                        _buildStatsRow(wallet),
                        _buildQuickActions(),
                        _buildMyBooksSection(),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.upload_file_rounded),
        label: Text(S.uploadBook),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const UploadBookScreen()));
          _loadData(); // Refresh baada ya upload
        },
      ),
    );
  }

  Widget _buildHeader(AuthProvider auth) {
    final topInset = MediaQuery.of(context).padding.top;
    return SliverAppBar(
      expandedHeight: topInset + kToolbarHeight + 110,
      pinned: true,
      backgroundColor: const Color(0xFF3730A3),
      foregroundColor: Colors.white,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      actions: [
        const LanguageDropdown(),
        const SizedBox(width: 4),
        const NotificationBell(),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ProfileScreen())),
          child: Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55), width: 2),
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: (auth.avatarUrl?.isNotEmpty ?? false)
                    ? NetworkImage(auth.avatarUrl!) : null,
                child: (auth.avatarUrl == null || auth.avatarUrl!.isEmpty)
                    ? Text(
                        auth.username.isEmpty ? 'A' :
                        auth.username[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 13))
                    : null,
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3730A3), Color(0xFF6D28D9), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(top: -20, right: -20, child: _bokeh(150, 0.14)),
            Positioned(bottom: 10, right: 90, child: _bokeh(70, 0.11)),
            Positioned(top: 50, left: -25, child: _bokeh(100, 0.09)),
            // ClipRect + OverflowBox: maudhui yanapangwa kwa urefu kamili wa
            // header wakati wote; header inapojikunja yanakatwa badala ya
            // kufurika (RenderFlex overflow) wakati wa scroll.
            Positioned.fill(
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.bottomCenter,
                  minHeight: topInset + kToolbarHeight + 110,
                  maxHeight: topInset + kToolbarHeight + 110,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        20, topInset + kToolbarHeight + 4, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.edit_rounded,
                                color: Colors.white70, size: 12),
                            const SizedBox(width: 5),
                            Text(S.authorDashboard,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          ]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          auth.username.isEmpty
                              ? '${S.greeting}! ✍️'
                              : '${S.greeting}, ${auth.username[0].toUpperCase()}${auth.username.substring(1)}! ✍️',
                          style: const TextStyle(color: Colors.white,
                              fontSize: 22, fontWeight: FontWeight.w800),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(WalletProvider wallet) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        children: [
          _statCard(
            icon: Icons.menu_book_rounded,
            label: S.myBooks,
            value: '${_myBooks.length}',
            gradient: AppTheme.primaryGradient,
          ),
          const SizedBox(width: 12),
          _statCard(
            icon: Icons.account_balance_wallet_rounded,
            label: S.balanceTzs,
            value: wallet.balance.toStringAsFixed(0),
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)]),
          ),
          const SizedBox(width: 12),
          _statCard(
            icon: Icons.people_rounded,
            label: S.readers,
            value: '$_totalReaders',
            gradient: const LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AuthorReadersScreen())),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required LinearGradient gradient,
    VoidCallback? onTap,
  }) {
    final card = Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                if (onTap != null)
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.7), size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
              style: const TextStyle(color: Colors.white,
                  fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 10),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
    );
    return Expanded(
      child: onTap != null
          ? GestureDetector(onTap: onTap, child: card)
          : card,
    );
  }

  Widget _buildQuickActions() {
    final acts = [
      _AuthorAction(Icons.upload_file_rounded, S.uploadBookShort,
          AppTheme.primary,
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const UploadBookScreen()))
              .then((_) => _loadData())),
      _AuthorAction(Icons.account_balance_wallet_rounded, S.walletShort,
          const Color(0xFF10B981),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const WalletScreen()))),
      _AuthorAction(Icons.pie_chart_rounded, S.myEarnings,
          const Color(0xFF0EA5E9),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AuthorEarningsScreen()))),
      _AuthorAction(Icons.people_rounded, S.readers,
          const Color(0xFFF59E0B),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AuthorReadersScreen()))),
      _AuthorAction(Icons.person_rounded, S.profileShort,
          const Color(0xFF7C3AED),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()))),
      _AuthorAction(Icons.storefront_rounded, S.bookStoreShort,
          const Color(0xFFEC4899),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const HomeScreen()))),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _sectionLabel(S.quickActions),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 88,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: acts.length,
              padding: const EdgeInsets.only(right: 16),
              itemBuilder: (_, i) {
                final a = acts[i];
                return GestureDetector(
                  onTap: a.onTap,
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.card(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: a.color.withValues(alpha: 0.2)),
                      boxShadow: [BoxShadow(
                        color: a.color.withValues(alpha: 0.12),
                        blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: a.color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(a.icon, color: a.color, size: 20),
                        ),
                        const SizedBox(height: 6),
                        Text(a.label, textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary(context))),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyBooksSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel(S.myBooks),
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const UploadBookScreen()))
                    .then((_) => _loadData()),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.add_rounded,
                        size: 14, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Text(S.t('Ongeza', 'Add New'),
                        style: const TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary)),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _myBooks.isEmpty
              ? _emptyBooksState()
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _myBooks.length,
                  itemBuilder: (ctx, i) => _bookRow(_myBooks[i]),
                ),
        ],
      ),
    );
  }

  Widget _bookRow(dynamic book) {
    final isFree     = book['is_free'] ?? false;
    final price      = book['price'] ?? '0';
    final isPublished = book['is_published'] == true;
    final bookId     = book['id'] as int;
    final hasAudio   = book['has_audio'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
          color: AppTheme.primary.withValues(alpha: 0.06),
          blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Cover
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: safeNetworkImage(
                    book['cover_image']?.toString(),
                    width: 48, height: 60,
                    placeholder: _miniPlaceholder()),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book['title'] ?? '',
                        style: TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 14, color: AppTheme.textPrimary(context)),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Row(children: [
                        Text(isFree ? S.free : 'TZS $price',
                          style: TextStyle(
                            color: isFree ? AppTheme.success : AppTheme.primary,
                            fontSize: 12, fontWeight: FontWeight.w600)),
                        if (hasAudio) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.headphones_rounded,
                              size: 14, color: Color(0xFF7C3AED)),
                        ],
                      ]),
                    ],
                  ),
                ),
                // Published badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPublished
                        ? AppTheme.success.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPublished ? S.published : S.draft,
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: isPublished ? AppTheme.success : Colors.orange),
                  ),
                ),
              ],
            ),
          ),
          // Action buttons chini ya kadi
          Container(
            decoration: BoxDecoration(
              color: AppTheme.bg(context),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(14)),
            ),
            child: Row(
              children: [
                // Hariri kitufe
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: Text(S.t('Hariri', 'Edit'),
                        style: const TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primary),
                    onPressed: () async {
                      final changed = await Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                          EditBookScreen(bookId: bookId)));
                      if (changed == true) _loadData();
                    },
                  ),
                ),
                Container(width: 1, height: 30, color: AppTheme.borderColor(context)),
                // Chapisha/Futa uchapishaji
                Expanded(
                  child: TextButton.icon(
                    icon: Icon(
                      isPublished
                          ? Icons.visibility_off_rounded
                          : Icons.publish_rounded,
                      size: 16),
                    label: Text(
                      isPublished
                          ? S.t('Ficha', 'Unpublish')
                          : S.t('Chapisha', 'Publish'),
                      style: const TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      foregroundColor: isPublished
                          ? Colors.orange : AppTheme.success),
                    onPressed: () => _togglePublish(bookId, !isPublished),
                  ),
                ),
                Container(width: 1, height: 30, color: AppTheme.borderColor(context)),
                // Tuma ujumbe kwa wasomaji
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.campaign_rounded, size: 16),
                    label: Text(S.t('Wasomaji', 'Readers'),
                        style: const TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF7C3AED)),
                    onPressed: () => _openBroadcastDialog(
                        bookId, book['title']?.toString() ?? ''),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openBroadcastDialog(int bookId, String bookTitle) async {
    final ctrl = TextEditingController();
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.card(ctx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(children: [
                const Icon(Icons.campaign_rounded, color: Color(0xFF7C3AED)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(S.messageReaders,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 4),
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('📚 $bookTitle',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7C3AED))),
              ),
              TextField(
                controller: ctrl,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: S.broadcastHint,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  icon: const Icon(Icons.send_rounded),
                  label: Text(S.broadcastSend),
                  onPressed: () async {
                    final text = ctrl.text.trim();
                    if (text.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text(S.broadcastEmpty),
                          backgroundColor: AppTheme.danger));
                      return;
                    }
                    try {
                      final count =
                          await _api.broadcastToReaders(bookId, text);
                      if (ctx.mounted) Navigator.pop(ctx, true);
                      if (mounted) {
                        final messenger = ScaffoldMessenger.of(context);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          messenger.showSnackBar(SnackBar(
                            content: Text(count > 0
                                ? '${S.broadcastSentOk} ($count)'
                                : S.broadcastNoReaders),
                            backgroundColor: count > 0
                                ? AppTheme.success
                                : Colors.orange,
                          ));
                        });
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text('$e'),
                            backgroundColor: AppTheme.danger));
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    ctrl.dispose();
  }

  Future<void> _togglePublish(int bookId, bool publish) async {
    try {
      await _api.updateBook(bookId: bookId, isPublished: publish);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(publish
              ? S.t('Kitabu kimechapishwa!', 'Book published!')
              : S.t('Kitabu kimefichwa.', 'Book unpublished.')),
          backgroundColor: publish ? AppTheme.success : Colors.orange,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$e'), backgroundColor: AppTheme.danger));
      }
    }
  }

  Widget _miniPlaceholder() {
    return Container(
      width: 48, height: 60,
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.menu_book_rounded,
          color: AppTheme.primary, size: 24),
    );
  }

  Widget _emptyBooksState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.1), style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.library_add_rounded, size: 52,
              color: AppTheme.primary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(S.noBooksYet,
            style: TextStyle(fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary(context), fontSize: 15)),
          const SizedBox(height: 6),
          Text(S.noBooksDesc,
            style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: Text(S.uploadFirst),
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const UploadBookScreen()))
                .then((_) => _loadData()),
          ),
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
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3730A3), Color(0xFF6D28D9), Color(0xFF4F46E5)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(top: -10, right: -10, child: _bokeh(80, 0.12)),
                Positioned(bottom: 0, right: 60, child: _bokeh(50, 0.09)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5), width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        backgroundImage: (auth.avatarUrl != null &&
                                auth.avatarUrl!.isNotEmpty)
                            ? NetworkImage(auth.avatarUrl!)
                            : null,
                        child: (auth.avatarUrl == null || auth.avatarUrl!.isEmpty)
                            ? Text(
                                auth.username.isEmpty ? 'A' :
                                auth.username[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white,
                                    fontSize: 24, fontWeight: FontWeight.bold))
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(auth.username,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(S.author,
                        style: const TextStyle(color: Colors.white,
                            fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _drawerItem(Icons.dashboard_rounded, S.dashboard,
                  () => Navigator.pop(context)),
                _drawerItem(Icons.upload_file_rounded, S.uploadBook, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const UploadBookScreen()))
                      .then((_) => _loadData());
                }),
                _drawerItem(Icons.storefront_rounded, S.bookStore, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const HomeScreen()));
                }),
                _drawerItem(Icons.account_balance_wallet_rounded, S.wallet, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const WalletScreen()));
                }),
                _drawerItem(Icons.pie_chart_rounded, S.myEarnings, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const AuthorEarningsScreen()));
                }),
                _drawerItem(Icons.person_rounded, S.profile, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const ProfileScreen()));
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

  Widget _bokeh(double size, double alpha) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );

  Widget _sectionLabel(String title) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 4, height: 20,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6D28D9), Color(0xFF4F46E5)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
          color: AppTheme.textPrimary(context))),
    ],
  );
}

class _AuthorAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AuthorAction(this.icon, this.label, this.color, this.onTap);
}

