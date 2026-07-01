import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/book_provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import '../services/offline_book_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/safe_image.dart';
import '../widgets/language_toggle.dart';
import '../widgets/share_book_sheet.dart';
import 'reader_screen.dart';
import 'audio_player_screen.dart';
import 'comments_screen.dart';
import 'subscription_screen.dart';
import 'profile_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final int bookId;
  const BookDetailScreen({super.key, required this.bookId});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen>
    with TickerProviderStateMixin {
  final ApiService _api  = ApiService();
  late final AnimationController _bgCtrl;
  Map<String, dynamic>? _detail;
  bool _loading  = true;
  bool _buying   = false;
  bool _saved    = false;
  bool _saving   = false;
  bool _inWishlist = false;
  bool _wishlistBusy = false;
  bool _inCart   = false;
  bool _addingToCart = false;

  // Offline download (kwa vitabu vilivyonunuliwa/bure pekee)
  bool _isOfflineAvailable = false;
  bool _downloadingOffline = false;

  // Ratings
  List<dynamic> _ratings = [];
  Map<String, dynamic>? _myRating;
  int _selectedStars = 0;
  final TextEditingController _reviewCtrl = TextEditingController();
  bool _submittingRating = false;

  // Subscription usage (for free-plan selection flow)
  Map<String, dynamic>? _subUsage;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final results = await Future.wait([
        context.read<BookProvider>().fetchBookDetail(widget.bookId),
        _api.checkSaved(widget.bookId),
        _api.checkWishlist(widget.bookId),
      ]);
      final data  = results[0] as Map<String, dynamic>;
      final saved = results[1] as bool;
      final inWishlist = results[2] as bool;
      setState(() {
        _detail = data;
        _saved = saved;
        _inWishlist = inWishlist;
        _loading = false;
      });
      _loadRatings();
      _refreshOfflineStatus();
      // Load subscription usage in background
      _api.fetchSubscriptionUsage().then((u) {
        if (mounted) setState(() => _subUsage = u);
      }).catchError((_) {});
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.danger));
      }
    }
  }

  Future<void> _toggleSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      bool newState;
      if (_saved) {
        newState = await _api.removeFromLibrary(widget.bookId);
      } else {
        newState = await _api.saveBook(widget.bookId);
      }
      if (mounted) {
        setState(() { _saved = newState; _saving = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            Icon(newState ? Icons.bookmark_rounded : Icons.bookmark_remove_rounded,
                color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(newState
                ? S.t('Kimehifadhiwa kwenye maktaba yako!', 'Saved to your library!')
                : S.t('Kimetolewa kwenye maktaba', 'Removed from library')),
          ]),
          backgroundColor: newState ? AppTheme.primary : AppTheme.textMuted,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$e'), backgroundColor: AppTheme.danger));
      }
    }
  }

  Future<void> _toggleWishlist() async {
    if (_wishlistBusy) return;
    setState(() => _wishlistBusy = true);
    try {
      bool newState;
      if (_inWishlist) {
        newState = await _api.removeFromWishlist(widget.bookId);
      } else {
        newState = await _api.addToWishlist(widget.bookId);
      }
      if (mounted) {
        setState(() { _inWishlist = newState; _wishlistBusy = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newState ? S.addedToWishlist : S.removedFromWishlist),
          backgroundColor: newState ? AppTheme.secondary : AppTheme.textMuted,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _wishlistBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppTheme.danger,
        ));
      }
    }
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _reviewCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRatings() async {
    try {
      final results = await Future.wait([
        _api.fetchBookRatings(widget.bookId),
        _api.fetchMyRating(widget.bookId),
      ]);
      final ratings = results[0] as List<dynamic>;
      final mine = results[1] as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          _ratings = ratings;
          _myRating = mine;
          _selectedStars = mine != null ? (mine['score'] as num).toInt() : 0;
          _reviewCtrl.text = mine != null ? (mine['comment']?.toString() ?? '') : '';
        });
      }
    } catch (_) {}
  }

  Future<void> _submitRating() async {
    if (_selectedStars < 1) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(S.selectRatingFirst), backgroundColor: AppTheme.warning));
      return;
    }
    final bookProv = context.read<BookProvider>();
    setState(() => _submittingRating = true);
    try {
      await _api.submitRating(widget.bookId, _selectedStars, _reviewCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(S.ratingSubmitted), backgroundColor: AppTheme.success));
        await _loadRatings();
        final data = await bookProv.fetchBookDetail(widget.bookId);
        if (mounted) setState(() => _detail = data);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppTheme.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _submittingRating = false);
    }
  }

  Future<void> _addToCart() async {
    if (_addingToCart || _inCart) return;
    setState(() => _addingToCart = true);
    try {
      await _api.addToCart(widget.bookId);
      if (mounted) {
        setState(() { _inCart = true; _addingToCart = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(S.addedToCart),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _addingToCart = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppTheme.danger,
        ));
      }
    }
  }

  Future<void> _purchase() async {
    setState(() => _buying = true);
    try {
      final result = await context.read<BookProvider>().purchaseBook(widget.bookId);
      if (mounted) {
        final autoUpgraded = result['auto_upgraded'] == true;
        final msg = autoUpgraded
            ? (result['detail'] ?? S.buySuccess)
            : S.buySuccess;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg.toString()),
          backgroundColor: autoUpgraded ? const Color(0xFF7C3AED) : AppTheme.success,
          duration: Duration(seconds: autoUpgraded ? 5 : 2),
        ));
        // Refresh subscription usage after purchase
        _api.fetchSubscriptionUsage().then((u) {
          if (mounted) setState(() => _subUsage = u);
        }).catchError((_) {});
        // Silently cache book encrypted for offline reading
        _autoCacheBook();
        final data = await context.read<BookProvider>().fetchBookDetail(widget.bookId);
        if (mounted) setState(() => _detail = data);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppTheme.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  /// Encrypted auto-cache — runs silently in background right after purchase
  /// so the book is available offline immediately.
  void _autoCacheBook() {
    final title = _detail?['title']?.toString() ?? '';
    _api.fetchBookBytes(widget.bookId).then((result) {
      final bytes = result['bytes'] as Uint8List;
      final ct    = (result['content_type'] as String? ?? 'text/plain');
      OfflineBookService.instance.saveBook(
        bookId: widget.bookId,
        bytes: bytes,
        contentType: ct,
        title: title,
      ).then((_) {
        if (mounted) setState(() => _isOfflineAvailable = true);
      });
    }).catchError((_) {});
  }

  bool get _canDownload =>
      _detail?['can_download'] == true || _detail?['is_free'] == true;

  Future<void> _refreshOfflineStatus() async {
    if (!_canDownload) return;
    final available = await OfflineBookService.instance.isAvailableOffline(widget.bookId);
    if (mounted) setState(() => _isOfflineAvailable = available);
  }

  /// Kitufe cha kupakua/kufuta nakala ya offline — kwa vitabu vilivyonunuliwa
  /// au vya bure pekee. Vitabu vinavyofikiwa kwa usajili wa kila mwezi tu
  /// havipati kitufe hiki — lazima visomwe mtandaoni.
  Future<void> _toggleOfflineDownload() async {
    if (_downloadingOffline) return;

    if (_isOfflineAvailable) {
      await OfflineBookService.instance.deleteBook(widget.bookId);
      if (mounted) {
        setState(() => _isOfflineAvailable = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(S.t('Nakala ya offline imefutwa', 'Offline copy removed')),
          backgroundColor: AppTheme.textMuted,
        ));
      }
      return;
    }

    setState(() => _downloadingOffline = true);
    try {
      final title  = _detail?['title']?.toString() ?? '';
      final result = await _api.fetchBookBytes(widget.bookId);
      final bytes  = result['bytes'] as Uint8List;
      final ct     = (result['content_type'] as String? ?? 'text/plain');
      final ok = await OfflineBookService.instance.saveBook(
        bookId: widget.bookId, bytes: bytes, contentType: ct, title: title);
      if (mounted) {
        setState(() { _isOfflineAvailable = ok; _downloadingOffline = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? S.t('Kitabu kimepakuliwa — sasa kinasomeka offline!', 'Book downloaded — now available offline!')
              : S.t('Kitabu ni kikubwa mno kuhifadhiwa offline', 'Book is too large to store offline')),
          backgroundColor: ok ? AppTheme.success : AppTheme.warning,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloadingOffline = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppTheme.danger,
        ));
      }
    }
  }

  Future<void> _selectFreeBook() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.card_giftcard_rounded, color: AppTheme.primary),
          const SizedBox(width: 10),
          Text(S.t('Kitabu cha Bure', 'Free Book Selection')),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.t(
              'Kama msomaji wa mpango wa Bure, unaweza kuchagua kitabu KIMOJA cha kulipa kusoma bila malipo.',
              'As a Free plan reader, you can choose ONE paid book to read for free.',
            ), style: const TextStyle(height: 1.5)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppTheme.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(S.t(
                  'Baada ya kuchagua huwezi kubadilisha. Chagua kwa makini!',
                  'Once selected, you cannot change it. Choose carefully!',
                ), style: const TextStyle(fontSize: 12, height: 1.4))),
              ]),
            ),
            const SizedBox(height: 12),
            Text(
              '"${_detail?['title'] ?? ''}"',
              style: const TextStyle(fontWeight: FontWeight.bold,
                  fontSize: 15, color: AppTheme.primary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.t('Chagua Kitabu Hiki', 'Select This Book'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final bookProv = context.read<BookProvider>();
    try {
      await _api.selectFreeBook(widget.bookId);
      if (!mounted) return;
      // Refresh usage and book detail
      final usage  = await _api.fetchSubscriptionUsage();
      final detail = await bookProv.fetchBookDetail(widget.bookId);
      if (!mounted) return;
      setState(() {
        _subUsage = usage;
        _detail   = detail;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(S.t(
          'Umechagua kitabu chako cha bure! Sasa unaweza kusoma.',
          'Your free book selected! You can now read it.')),
        backgroundColor: AppTheme.success,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppTheme.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(backgroundColor: const Color(0xFF0D0D1A)),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }
    if (_detail == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(S.noDesc)),
      );
    }

    context.watch<LanguageProvider>(); // rebuild on lang change
    return Responsive.isDesktop(context)
        ? _desktopLayout()
        : _mobileLayout();
  }

  // ── Mobile Layout ──
  Widget _mobileLayout() {
    final isFree   = _detail!['is_free'] == true;
    // Angalia kwa njia salama — null, false, au 0 zote zinamaanisha "hapana"
    final hasAudio = _detail!['has_audio'] == true;
    final hasText  = _detail!['has_text'] == true;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF0D0D1A),
            foregroundColor: Colors.white,
            actions: [
              _shareButton(),
              _wishlistButton(),
              _bookmarkButton(),
              const LanguageDropdown(),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Animated category-specific background
                  AnimatedBuilder(
                    animation: _bgCtrl,
                    builder: (_, __) => CustomPaint(
                      painter: _CategoryBgPainter(
                        _bgCtrl.value,
                        _detail!['category_name']?.toString() ?? '',
                      ),
                    ),
                  ),
                  // Cover image centered on top of animation
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: safeNetworkImage(
                            _detail!['cover_image']?.toString(),
                            width: 120, height: 170),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildContent(isFree, hasAudio, hasText)),
        ],
      ),
    );
  }

  // ── Desktop Layout ──
  Widget _desktopLayout() {
    final isFree   = _detail!['is_free'] == true;
    final hasAudio = _detail!['has_audio'] == true;
    final hasText  = _detail!['has_text'] == true;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: Text(_detail!['title'] ?? ''),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
        actions: [
          _shareButton(),
          _bookmarkButton(),
          const LanguageDropdown(),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppTheme.shadow(context),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: safeNetworkImage(
                          _detail!['cover_image']?.toString(),
                          width: 200, height: 280),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildPriceBadge(isFree),
                  ],
                ),
              ),
              // Details
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(0, 32, 32, 32),
                  child: _buildContent(isFree, hasAudio, hasText,
                      isDesktop: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Kitufe cha kushare kitabu kwenye mitandao ya kijamii
  Widget _shareButton() {
    return Tooltip(
      message: S.shareBook,
      child: IconButton(
        icon: const Icon(Icons.share_rounded, color: Colors.white, size: 24),
        onPressed: () => ShareBookSheet.show(context, _detail!),
      ),
    );
  }

  /// Kitufe cha Wishlist (moyo) — kuongeza/kutoa kwenye Wishlist
  Widget _wishlistButton() {
    if (_wishlistBusy) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2)),
      );
    }
    return Tooltip(
      message: _inWishlist ? S.removeFromWishlist : S.addToWishlist,
      child: IconButton(
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(
            _inWishlist ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            key: ValueKey(_inWishlist),
            color: _inWishlist ? AppTheme.danger : Colors.white,
            size: 24,
          ),
        ),
        onPressed: _toggleWishlist,
      ),
    );
  }

  /// Kitufe cha Bookmark — kuongeza/kutoa kwenye Maktaba Yangu
  Widget _bookmarkButton() {
    if (_saving) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2)),
      );
    }
    return Tooltip(
      message: _saved
          ? S.t('Toa kwenye Maktaba Yangu', 'Remove from My Library')
          : S.t('Ongeza kwenye Maktaba Yangu', 'Add to My Library'),
      child: IconButton(
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(
            _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            key: ValueKey(_saved),
            color: _saved ? Colors.amber : Colors.white,
            size: 26,
          ),
        ),
        onPressed: _toggleSave,
      ),
    );
  }

  Widget _buildContent(bool isFree, bool hasAudio, bool hasText,
      {bool isDesktop = false}) {
    final title  = _detail!['title'] ?? '';
    final author = _detail!['author_name'] ?? '';
    final desc   = _detail!['description'] ?? '';
    return Semantics(
      label: 'Maelezo ya kitabu $title na $author',
      child: Container(
        margin: isDesktop ? null : const EdgeInsets.only(top: 16),
        decoration: isDesktop
            ? BoxDecoration(color: AppTheme.card(context))
            : BoxDecoration(
                color: AppTheme.card(context),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24)),
                boxShadow: AppTheme.shadow(context),
              ),
        padding: isDesktop
            ? EdgeInsets.zero
            : const EdgeInsets.fromLTRB(24, 22, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isDesktop) ...[
              // Mpini mdogo wa juu kuonyesha hii ni "sheet" ya taarifa
              Center(
                child: Container(
                  width: 44, height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor(context),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(title,
                  style: TextStyle(
                      fontSize: Responsive.titleSize(context),
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                      color: AppTheme.textPrimary(context))),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.person_outline_rounded,
                    size: 16, color: AppTheme.textSecondary(context)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(author, style: TextStyle(
                      color: AppTheme.textSecondary(context), fontSize: 14)),
                ),
              ]),
              const SizedBox(height: 14),
              _buildPriceBadge(isFree),
              const SizedBox(height: 18),
              Divider(color: AppTheme.borderColor(context)),
              const SizedBox(height: 18),
            ] else ...[
              Text(title,
                  style: TextStyle(fontSize: 26,
                      fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.person_outline_rounded,
                    size: 16, color: AppTheme.textSecondary(context)),
                const SizedBox(width: 4),
                Text(author, style: TextStyle(
                    color: AppTheme.textSecondary(context), fontSize: 15)),
              ]),
              const SizedBox(height: 16),
            ],

            // Format badges (Maandishi / Sauti)
            _buildFormatBadges(hasText, hasAudio),
            const SizedBox(height: 20),

            // Action buttons
            _buildActionButtons(isFree, hasText, hasAudio),
            const SizedBox(height: 24),

            // Description
            Text(S.aboutBook,
                style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
            const SizedBox(height: 8),
            Text(desc.isEmpty ? S.noDesc : desc,
                style: TextStyle(
                    color: AppTheme.textSecondary(context), height: 1.6, fontSize: 14)),
            const SizedBox(height: 24),

            // ── Library Metadata Card ──
            _buildMetadataCard(),
            const SizedBox(height: 20),

            // ── Ratings & Reviews ──
            _buildRatingsSection(),
            const SizedBox(height: 20),

            // Comments button
            OutlinedButton.icon(
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: Text(S.viewComments),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: BorderSide(color: AppTheme.borderColor(context)),
                padding: const EdgeInsets.symmetric(
                    vertical: 12, horizontal: 20),
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => CommentsScreen(bookId: widget.bookId))),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingsSection() {
    final avgRating = (_detail?['avg_rating'] is num)
        ? (_detail!['avg_rating'] as num).toDouble() : 0.0;
    final ratingsCount = (_detail?['ratings_count'] is num)
        ? (_detail!['ratings_count'] as num).toInt() : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(S.ratingsAndReviews,
                  style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
              const Spacer(),
              if (ratingsCount > 0) ...[
                const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                const SizedBox(width: 4),
                Text('${avgRating.toStringAsFixed(1)} ($ratingsCount)',
                    style: TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600, color: AppTheme.textPrimary(context))),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Star input
          Text(S.yourRating,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary(context))),
          const SizedBox(height: 6),
          Row(
            children: List.generate(5, (i) {
              final starIndex = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _selectedStars = starIndex),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    starIndex <= _selectedStars
                        ? Icons.star_rounded : Icons.star_border_rounded,
                    color: Colors.amber, size: 32,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _reviewCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: S.writeReviewHint,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submittingRating ? null : _submitRating,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _submittingRating
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(_myRating != null ? S.updateRating : S.submitRating,
                      style: const TextStyle(color: Colors.white)),
            ),
          ),

          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 6),

          // Existing reviews
          if (_ratings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(S.noRatingsYet,
                  style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _ratings.length,
              separatorBuilder: (_, __) => const Divider(height: 20),
              itemBuilder: (_, i) => _reviewTile(_ratings[i]),
            ),
        ],
      ),
    );
  }

  Widget _reviewTile(dynamic r) {
    final score = (r['score'] as num?)?.toInt() ?? 0;
    final comment = r['comment']?.toString() ?? '';
    final username = r['username']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
              child: Text(username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppTheme.primary,
                      fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            Text(username, style: TextStyle(
                fontWeight: FontWeight.w600, color: AppTheme.textPrimary(context), fontSize: 13)),
            const SizedBox(width: 8),
            Row(
              children: List.generate(5, (i) => Icon(
                  i < score ? Icons.star_rounded : Icons.star_border_rounded,
                  color: Colors.amber, size: 14)),
            ),
          ],
        ),
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(comment, style: TextStyle(
              color: AppTheme.textSecondary(context), fontSize: 13, height: 1.4)),
        ],
      ],
    );
  }

  Widget _buildPriceBadge(bool isFree) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: isFree
            ? const LinearGradient(colors: [
                Color(0xFF10B981), Color(0xFF059669)])
            : AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isFree ? S.bure : 'TZS ${_detail!['price']}',
        style: const TextStyle(color: Colors.white,
            fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildFormatBadges(bool hasText, bool hasAudio) {
    final minAge = (_detail?['min_age'] is num)
        ? (_detail!['min_age'] as num).toInt() : 0;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        // Badge ya maandishi
        if (hasText)
          _formatBadge(Icons.menu_book_rounded, S.textAvail,
              AppTheme.primary, active: true)
        else
          _formatBadge(Icons.menu_book_rounded, S.noText,
              AppTheme.textSecondary(context), active: false),

        // Badge ya sauti — inaonyesha hali halisi
        if (hasAudio)
          _formatBadge(Icons.headphones_rounded, S.audioAvail,
              const Color(0xFF7C3AED), active: true)
        else
          _formatBadge(Icons.music_off_rounded, S.noAudio,
              AppTheme.textSecondary(context), active: false),

        // Badge ya kikomo cha umri
        if (minAge > 0)
          _formatBadge(Icons.gpp_maybe_rounded, S.ageBadge(minAge),
              AppTheme.danger, active: true),
      ],
    );
  }

  Widget _formatBadge(IconData icon, String label, Color color,
      {bool active = true}) {
    final effectiveColor = active ? color : AppTheme.textSecondary(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? effectiveColor.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active
              ? effectiveColor.withValues(alpha: 0.35)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: effectiveColor),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(
          fontSize: 12,
          color: effectiveColor,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
        )),
      ]),
    );
  }

  // ── Library Metadata Card ──────────────────────────────────────────────────
  Widget _buildMetadataCard() {
    final d = _detail!;

    // Build list of metadata rows — only show if value exists
    final List<_MetaRow> rows = [
      if ((d['isbn'] ?? '').toString().isNotEmpty)
        _MetaRow(Icons.tag_rounded, S.detailIsbn, d['isbn'].toString()),
      if ((d['book_authors'] ?? '').toString().isNotEmpty)
        _MetaRow(Icons.people_alt_rounded, S.detailAuthors,
            d['book_authors'].toString())
      else if ((d['author_name'] ?? '').toString().isNotEmpty)
        _MetaRow(Icons.person_rounded, S.detailAuthors,
            d['author_name'].toString()),
      if ((d['publisher'] ?? '').toString().isNotEmpty)
        _MetaRow(Icons.business_rounded, S.detailPublisher,
            d['publisher'].toString()),
      if (d['year_published'] != null)
        _MetaRow(Icons.calendar_today_rounded, S.detailYear,
            d['year_published'].toString()),
      if ((d['edition'] ?? '').toString().isNotEmpty)
        _MetaRow(Icons.layers_rounded, S.detailEdition,
            d['edition'].toString()),
      if (d['page_count'] != null)
        _MetaRow(Icons.menu_book_rounded, S.detailPages,
            d['page_count'].toString()),
      if ((d['book_language'] ?? '').toString().isNotEmpty)
        _MetaRow(Icons.translate_rounded, S.detailLanguage,
            d['book_language'].toString()),
      if ((d['category_name'] ?? '').toString().isNotEmpty)
        _MetaRow(Icons.category_rounded, S.detailCategory,
            d['category_name'].toString()),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: AppTheme.shadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppTheme.primary.withValues(alpha: 0.1),
                AppTheme.primary.withValues(alpha: 0.03),
              ]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.library_books_rounded,
                    color: AppTheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(S.metadataTitle,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                        fontSize: 14)),
              ],
            ),
          ),
          // Rows
          ...rows.asMap().entries.map((entry) {
            final i = entry.key;
            final row = entry.value;
            return Column(
              children: [
                if (i > 0)
                  const Divider(height: 1, indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(row.icon, size: 16,
                            color: AppTheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(row.label,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary(context),
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text(row.value,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textPrimary(context),
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  /// Kitufe cha "Pakua kwa Offline" (vitabu vilivyonunuliwa/bure) au ujumbe
  /// wa kuwakumbusha wasomaji wa usajili kwamba lazima wasome mtandaoni.
  Widget _buildOfflineControl() {
    if (!_canDownload) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.textMuted.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(Icons.wifi_rounded, size: 16, color: AppTheme.textSecondary(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              S.t(
                'Kitabu hiki kimefunguliwa kwa usajili — kinasomeka mtandaoni pekee, hakiwezi kupakuliwa.',
                'This book is unlocked via subscription — it can only be read online and cannot be downloaded.',
              ),
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary(context), height: 1.4),
            ),
          ),
        ]),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          icon: _downloadingOffline
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(_isOfflineAvailable
                  ? Icons.offline_pin_rounded : Icons.download_for_offline_rounded),
          label: Text(_downloadingOffline
              ? S.t('Inapakua...', 'Downloading...')
              : _isOfflineAvailable
                  ? S.t('Inapatikana Offline (futa)', 'Available Offline (remove)')
                  : S.t('Pakua kwa Offline', 'Download for Offline')),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: _isOfflineAvailable ? AppTheme.success : AppTheme.primary,
            side: BorderSide(
                color: _isOfflineAvailable ? AppTheme.success : AppTheme.primary,
                width: 1.5),
          ),
          onPressed: _downloadingOffline ? null : _toggleOfflineDownload,
        ),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.lock_outline_rounded, size: 13, color: AppTheme.textSecondary(context)),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              S.t(
                'Nakala hii inahifadhiwa ndani ya app tu na inasomeka humu humu — haiwi faili la kawaida na haliwezi kutumwa/kushirikiwa nje ya app.',
                'This copy is stored inside the app only and opens here — it is not a regular file and cannot be sent or shared outside the app.',
              ),
              style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondary(context), height: 1.35),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildActionButtons(bool isFree, bool hasText, bool hasAudio) {
    final isLocked = _detail!['is_locked'] == true;
    final requiredPlanName = _detail!['required_plan_name']?.toString();
    final isAgeRestricted = _detail!['is_age_restricted'] == true;
    final minAge = (_detail?['min_age'] is num)
        ? (_detail!['min_age'] as num).toInt() : 0;
    final blocked = isLocked || isAgeRestricted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isAgeRestricted) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.danger.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.gpp_maybe_rounded, color: AppTheme.danger),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(S.ageRestrictionTitle,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary(context))),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(S.ageRestrictionMessage(minAge),
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.textPrimary(context))),
                const SizedBox(height: 4),
                Text(S.ageRestrictionNoDob,
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary(context))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.person_outline_rounded),
            label: Text(S.goToProfile, style: const TextStyle(fontSize: 15)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: AppTheme.danger,
              side: const BorderSide(color: AppTheme.danger, width: 1.5),
            ),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const ProfileScreen()));
            },
          ),
          const SizedBox(height: 10),
        ],

        if (isLocked) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_rounded, color: AppTheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    requiredPlanName != null
                        ? '${S.requiresPlanPrefix} $requiredPlanName'
                        : S.upgradeToUnlock,
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.textPrimary(context)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Free plan — offer one-time free book selection
          if (_subUsage != null &&
              _subUsage!['plan_level'] == 0 &&
              !isFree &&
              !(_subUsage?['has_audio'] == true) &&
              !(_subUsage?['has_free_selection'] ?? false)) ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.card_giftcard_rounded),
              label: Text(
                S.t('Chagua kama Kitabu Chako cha Bure', 'Use as My Free Book'),
                style: const TextStyle(fontSize: 14)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFF10B981),
              ),
              onPressed: _selectFreeBook,
            ),
            const SizedBox(height: 6),
            Text(
              S.t('Mpango wa Bure: kitabu kimoja cha kulipa bila malipo',
                  'Free plan: one paid book at no cost'),
              style: TextStyle(fontSize: 11,
                  color: AppTheme.textSecondary(context)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
          ] else if (_subUsage != null &&
              _subUsage!['plan_level'] == 0 &&
              (_subUsage?['has_free_selection'] ?? false) &&
              _subUsage!['free_book_id'] != widget.bookId) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded,
                    color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  S.t(
                    'Umeshachagua kitabu kingine kwa mpango wa Bure. Panda mpango kupata zaidi.',
                    'You already selected a different free book. Upgrade for more.',
                  ),
                  style: const TextStyle(fontSize: 12, height: 1.4),
                )),
              ]),
            ),
            const SizedBox(height: 10),
          ],
          ElevatedButton.icon(
            icon: const Icon(Icons.workspace_premium_rounded),
            label: Text(S.goToPlans, style: const TextStyle(fontSize: 15)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppTheme.primary,
            ),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const SubscriptionScreen()));
            },
          ),
          const SizedBox(height: 10),
        ],

        // Soma Maandishi button
        if (hasText)
          Semantics(
            button: true,
            label: 'Soma kitabu kwa maandishi',
            child: Opacity(
              opacity: blocked ? 0.5 : 1.0,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.menu_book_rounded),
                label: Text(S.readText, style: const TextStyle(fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppTheme.primary,
                ),
                onPressed: blocked ? null : () {
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ReaderScreen(
                          bookId: widget.bookId, canDownload: _canDownload)));
                },
              ),
            ),
          ),

        if (hasText && !blocked) ...[
          const SizedBox(height: 10),
          _buildOfflineControl(),
        ],

        if (hasText) const SizedBox(height: 10),

        // Sikiliza Sauti button — INAONEKANA KILA WAKATI
        // Lakini DISABLED (grayed out) kama hakuna audio au kitabu kimefungwa
        Semantics(
          button: true,
          label: hasAudio
              ? 'Sikiliza kitabu kwa sauti'
              : 'Sauti haipo — kitufe kikamatiliwa',
          child: Opacity(
            opacity: (hasAudio && !blocked) ? 1.0 : 0.5,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.headphones_rounded),
              label: Text(S.listenAudio, style: const TextStyle(fontSize: 15)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: hasAudio
                    ? const Color(0xFF7C3AED)
                    : Colors.grey.shade400,
              ),
              // DISABLED (null onPressed) kama hakuna audio au kimefungwa
              onPressed: (hasAudio && !blocked) ? () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => AudioPlayerScreen(
                    bookId:     widget.bookId,
                    bookTitle:  _detail!['title'] ?? '',
                    authorName: _detail!['author_name'] ?? '',
                    coverImage: _detail!['cover_image']?.toString(),
                  ),
                ));
              } : null,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Ongeza kwenye Kikapu button (kama kitabu si bure)
        if (!isFree) ...[
          Semantics(
            button: true,
            label: _inCart ? 'Kipo kwenye kikapu' : 'Ongeza kwenye kikapu',
            child: OutlinedButton.icon(
              icon: _addingToCart
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_inCart
                      ? Icons.check_circle_rounded
                      : Icons.add_shopping_cart_rounded),
              label: Text(_inCart ? S.alreadyInCart : S.addToCart),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: AppTheme.secondary,
                side: const BorderSide(color: AppTheme.secondary, width: 1.5),
              ),
              onPressed: (_addingToCart || _inCart) ? null : _addToCart,
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Nunua button (kama kitabu si bure)
        if (!isFree)
          Semantics(
            button: true,
            label: 'Nunua kitabu kwa TZS ${_detail!['price']}',
            child: OutlinedButton.icon(
              icon: _buying
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.shopping_cart_rounded),
              label: Text(_buying ? S.buyingBook : '${S.buyBook} - TZS ${_detail!['price']}'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary, width: 1.5),
              ),
              onPressed: _buying ? null : () { _purchase(); },
            ),
          ),

      ],
    );
  }
}

// ── Helper: metadata row data ─────────────────────────────────────────────────
class _MetaRow {
  final IconData icon;
  final String label;
  final String value;
  const _MetaRow(this.icon, this.label, this.value);
}

// ── Category-aware animated background ───────────────────────────────────────

enum _CatStyle {
  books, fiction, science, history, education, business,
  health, children, sports, arts, romance, religion, thriller,
}

class _CategoryBgPainter extends CustomPainter {
  final double t;
  final String category;

  _CategoryBgPainter(this.t, this.category);

  _CatStyle get _style {
    final c = category.toLowerCase();
    if (c.contains('hadithi') || c.contains('fiction') || c.contains('riwaya') ||
        c.contains('novel') || c.contains('masimulizi')) { return _CatStyle.fiction; }
    if (c.contains('sayansi') || c.contains('science') || c.contains('teknolojia') ||
        c.contains('tech') || c.contains('hisabati')) { return _CatStyle.science; }
    if (c.contains('historia') || c.contains('history') || c.contains('utamaduni') ||
        c.contains('culture') || c.contains('jamii')) { return _CatStyle.history; }
    if (c.contains('elimu') || c.contains('education') || c.contains('masomo') ||
        c.contains('darasa') || c.contains('shule')) { return _CatStyle.education; }
    if (c.contains('biashara') || c.contains('business') || c.contains('uchumi') ||
        c.contains('fedha') || c.contains('finance')) { return _CatStyle.business; }
    if (c.contains('afya') || c.contains('health') || c.contains('matibabu') ||
        c.contains('dawa') || c.contains('uuguzi')) { return _CatStyle.health; }
    if (c.contains('watoto') || c.contains('children') || c.contains('mtoto') ||
        c.contains('vijana')) { return _CatStyle.children; }
    if (c.contains('michezo') || c.contains('sport') || c.contains('mchezo') ||
        c.contains('mpira')) { return _CatStyle.sports; }
    if (c.contains('sanaa') || c.contains('art') || c.contains('muziki') ||
        c.contains('music') || c.contains('burudani')) { return _CatStyle.arts; }
    if (c.contains('upendo') || c.contains('romance') || c.contains('mapenzi') ||
        c.contains('love')) { return _CatStyle.romance; }
    if (c.contains('dini') || c.contains('religion') || c.contains('imani') ||
        c.contains('ibada') || c.contains('quran') || c.contains('biblia') ||
        c.contains('islamic') || c.contains('kristo')) { return _CatStyle.religion; }
    if (c.contains('thriller') || c.contains('msisitizo') || c.contains('horror') ||
        c.contains('mystery') || c.contains('siri') || c.contains('uhalifu')) { return _CatStyle.thriller; }
    return _CatStyle.books;
  }

  static List<Color> _gradientFor(_CatStyle s) {
    switch (s) {
      case _CatStyle.books:     return const [Color(0xFF0D0D1A), Color(0xFF14082B), Color(0xFF081624)];
      case _CatStyle.fiction:   return const [Color(0xFF070025), Color(0xFF110042), Color(0xFF040015)];
      case _CatStyle.science:   return const [Color(0xFF002530), Color(0xFF003A48), Color(0xFF001520)];
      case _CatStyle.history:   return const [Color(0xFF1C1000), Color(0xFF2B1900), Color(0xFF0F0A00)];
      case _CatStyle.education: return const [Color(0xFF001435), Color(0xFF002050), Color(0xFF000C22)];
      case _CatStyle.business:  return const [Color(0xFF001A10), Color(0xFF002C1A), Color(0xFF000E08)];
      case _CatStyle.health:    return const [Color(0xFF1A0015), Color(0xFF280020), Color(0xFF0D000B)];
      case _CatStyle.children:  return const [Color(0xFF14003A), Color(0xFF200058), Color(0xFF0A0025)];
      case _CatStyle.sports:    return const [Color(0xFF1A0800), Color(0xFF2C1200), Color(0xFF0D0400)];
      case _CatStyle.arts:      return const [Color(0xFF1A0028), Color(0xFF28003E), Color(0xFF0D0018)];
      case _CatStyle.romance:   return const [Color(0xFF1A0010), Color(0xFF280018), Color(0xFF0D0008)];
      case _CatStyle.religion:  return const [Color(0xFF1A1400), Color(0xFF281E00), Color(0xFF0D0B00)];
      case _CatStyle.thriller:  return const [Color(0xFF050508), Color(0xFF080810), Color(0xFF020205)];
    }
  }

  static double _speedFor(_CatStyle s) {
    if (s == _CatStyle.sports || s == _CatStyle.thriller) { return 1.8; }
    if (s == _CatStyle.romance || s == _CatStyle.religion) { return 0.65; }
    return 1.0;
  }

  // [xFactor, phaseOffset] for 12 floating elements
  static const List<List<double>> _pos = [
    [0.07, 0.00], [0.20, 0.18], [0.34, 0.38], [0.50, 0.55],
    [0.65, 0.12], [0.80, 0.72], [0.92, 0.30], [0.14, 0.82],
    [0.44, 0.25], [0.57, 0.48], [0.75, 0.65], [0.88, 0.08],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final style = _style;

    // 1. Background gradient
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          colors: _gradientFor(style),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & size),
    );

    // 2. Style-specific background texture
    _drawTexture(canvas, size, style);

    // 3. Floating particle elements
    final speed = _speedFor(style);
    for (int i = 0; i < _pos.length; i++) {
      final p = _pos[i];
      final progress = ((t * speed) + p[1]) % 1.0;
      final x = size.width * p[0];
      final y = size.height * (1.05 - progress * 1.1);
      final op = (math.sin(progress * math.pi) * 0.32).clamp(0.0, 0.32);
      if (op < 0.01) continue;
      final sz = 15.0 + (i % 5) * 3.5;
      canvas.save();
      canvas.translate(x, y);
      _drawElement(canvas, style, i, sz, op);
      canvas.restore();
    }
  }

  // ── Background textures ───────────────────────────────────────────────────

  void _drawTexture(Canvas canvas, Size size, _CatStyle style) {
    if (style == _CatStyle.science) {
      _hexGrid(canvas, size);
    } else if (style == _CatStyle.fiction) {
      _starField(canvas, size);
    } else if (style == _CatStyle.thriller) {
      _scanLines(canvas, size);
    } else {
      _dotGrid(canvas, size);
    }
    // Radial ambient glow for atmospheric styles
    Color? glowColor;
    if (style == _CatStyle.romance) glowColor = const Color(0xFF8B0040);
    if (style == _CatStyle.religion) glowColor = const Color(0xFF5C4200);
    if (style == _CatStyle.fiction)  glowColor = const Color(0xFF2E0080);
    if (glowColor != null) {
      canvas.drawCircle(
        Offset(size.width / 2, size.height * 0.4),
        size.width * 0.7,
        Paint()
          ..shader = RadialGradient(
            colors: [glowColor.withValues(alpha: 0.28), Colors.transparent],
          ).createShader(Rect.fromCircle(
            center: Offset(size.width / 2, size.height * 0.4),
            radius: size.width * 0.7)),
      );
    }
  }

  void _dotGrid(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.04);
    for (double dx = 0; dx < size.width; dx += 30) {
      for (double dy = 0; dy < size.height; dy += 30) {
        canvas.drawCircle(Offset(dx, dy), 1.2, p);
      }
    }
  }

  void _hexGrid(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    const r = 24.0;
    final rowH = r * math.sqrt(3);
    for (double row = -1; row * rowH < size.height + rowH; row++) {
      for (double col = -1; col * r * 1.5 < size.width + r * 2; col++) {
        final cx = col * r * 3 + (row.toInt().isOdd ? r * 1.5 : 0);
        final cy = row * rowH;
        final path = Path();
        for (int v = 0; v < 6; v++) {
          final a = v * math.pi / 3;
          final vx = cx + math.cos(a) * (r - 1);
          final vy = cy + math.sin(a) * (r - 1);
          v == 0 ? path.moveTo(vx, vy) : path.lineTo(vx, vy);
        }
        path.close();
        canvas.drawPath(path, p);
      }
    }
  }

  void _starField(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final p = Paint()..color = Colors.white.withValues(alpha: 0.22);
    for (int i = 0; i < 70; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        rng.nextDouble() * 1.3 + 0.3, p);
    }
  }

  void _scanLines(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 0.6;
    for (double dy = 0; dy < size.height; dy += 5) {
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), p);
    }
  }

  // ── Element dispatcher ────────────────────────────────────────────────────

  void _drawElement(Canvas canvas, _CatStyle style, int i, double s, double op) {
    if (style == _CatStyle.books) {
      canvas.rotate((i % 5 - 2) * 0.18);
      _book(canvas, s, op);
    } else if (style == _CatStyle.fiction) {
      canvas.rotate(t * math.pi * 0.12 * (i.isEven ? 1 : -1));
      _star5(canvas, s, op);
    } else if (style == _CatStyle.science) {
      canvas.rotate(_pos[i][1] * math.pi);
      if (i.isEven) { _hexagon(canvas, s, op); } else { _atom(canvas, s, op); }
    } else if (style == _CatStyle.history) {
      canvas.rotate(_pos[i][1] * 0.8);
      if (i.isEven) { _hourglass(canvas, s, op); } else { _gear(canvas, s, op); }
    } else if (style == _CatStyle.education) {
      canvas.rotate(_pos[i][1] * 0.4);
      if (i.isEven) { _cap(canvas, s, op); } else { _pencil(canvas, s, op); }
    } else if (style == _CatStyle.business) {
      if (i.isEven) { _barChart(canvas, s, op); } else { _arrowUp(canvas, s, op); }
    } else if (style == _CatStyle.health) {
      if (i.isEven) {
        _heart(canvas, s, op, Colors.pinkAccent);
      } else {
        _cross(canvas, s, op);
      }
    } else if (style == _CatStyle.children) {
      final m = i % 3;
      if (m == 0) {
        _balloon(canvas, s, op);
      } else if (m == 1) {
        _star5(canvas, s * 0.75, op);
      } else {
        _cloud(canvas, s, op);
      }
    } else if (style == _CatStyle.sports) {
      canvas.rotate(_pos[i][1] * 0.6);
      if (i.isEven) { _lightning(canvas, s, op); } else { _ball(canvas, s, op); }
    } else if (style == _CatStyle.arts) {
      canvas.rotate(_pos[i][1] * 0.5);
      if (i.isEven) { _musicNote(canvas, s, op); } else { _palette(canvas, s, op); }
    } else if (style == _CatStyle.romance) {
      canvas.rotate(_pos[i][1] * 0.3);
      if (i.isEven) {
        _heart(canvas, s, op, Colors.pinkAccent);
      } else {
        _petal(canvas, s * 0.7, op);
      }
    } else if (style == _CatStyle.religion) {
      canvas.rotate(_pos[i][1] * math.pi / 6);
      if (i.isEven) { _star8(canvas, s, op); } else { _crescent(canvas, s, op); }
    } else {
      // thriller
      canvas.rotate(_pos[i][1] * 0.2);
      if (i.isEven) { _rainStreak(canvas, s, op); } else { _lightning(canvas, s * 0.8, op); }
    }
  }

  // ── Shape drawing functions ───────────────────────────────────────────────

  void _book(Canvas canvas, double s, double op) {
    final w = s * 0.62;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w, height: s),
        const Radius.circular(2)),
      Paint()..color = Colors.white.withValues(alpha: op));
    canvas.drawRect(Rect.fromLTWH(-w / 2, -s / 2, w * 0.16, s),
      Paint()..color = Colors.white.withValues(alpha: op * 0.5));
    final lp = Paint()..color = Colors.black.withValues(alpha: op * 0.3)..strokeWidth = 0.8;
    for (int i = 1; i <= 3; i++) {
      canvas.drawLine(
        Offset(-w * 0.1, -s * 0.25 + i * s * 0.12),
        Offset(w * 0.38,  -s * 0.25 + i * s * 0.12), lp);
    }
  }

  void _star5(Canvas canvas, double s, double op) {
    final r = s / 2;
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final a = i * math.pi / 5 - math.pi / 2;
      final rr = i.isEven ? r : r * 0.42;
      i == 0
          ? path.moveTo(math.cos(a) * rr, math.sin(a) * rr)
          : path.lineTo(math.cos(a) * rr, math.sin(a) * rr);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: op));
  }

  void _hexagon(Canvas canvas, double s, double op) {
    final r = s / 2;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      i == 0
          ? path.moveTo(math.cos(a) * r, math.sin(a) * r)
          : path.lineTo(math.cos(a) * r, math.sin(a) * r);
    }
    path.close();
    canvas.drawPath(path, Paint()
      ..color = Colors.cyanAccent.withValues(alpha: op)
      ..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawCircle(Offset.zero, r * 0.28,
      Paint()..color = Colors.cyanAccent.withValues(alpha: op * 0.7));
  }

  void _atom(Canvas canvas, double s, double op) {
    final r = s / 2;
    final p = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: op)
      ..style = PaintingStyle.stroke..strokeWidth = 1.2;
    for (int i = 0; i < 3; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 3);
      canvas.drawOval(Rect.fromCenter(
        center: Offset.zero, width: r * 2.0, height: r * 0.75), p);
      canvas.restore();
    }
    canvas.drawCircle(Offset.zero, r * 0.22,
      Paint()..color = Colors.cyanAccent.withValues(alpha: op));
  }

  void _hourglass(Canvas canvas, double s, double op) {
    final r = s / 2;
    final c = const Color(0xFFD4A853).withValues(alpha: op);
    canvas.drawPath(
      Path()..moveTo(-r, -r)..lineTo(r, -r)..lineTo(0, 0)..close(),
      Paint()..color = c);
    canvas.drawPath(
      Path()..moveTo(-r, r)..lineTo(r, r)..lineTo(0, 0)..close(),
      Paint()..color = c);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: r * 2.2, height: r * 2.2),
        const Radius.circular(3)),
      Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  void _gear(Canvas canvas, double s, double op) {
    final r = s / 2;
    final p = Paint()
      ..color = const Color(0xFFD4A853).withValues(alpha: op)
      ..style = PaintingStyle.stroke..strokeWidth = 1.5;
    canvas.drawCircle(Offset.zero, r * 0.65, p);
    canvas.drawCircle(Offset.zero, r * 0.28, p);
    for (int i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      canvas.drawLine(
        Offset(math.cos(a) * r * 0.65, math.sin(a) * r * 0.65),
        Offset(math.cos(a) * r, math.sin(a) * r), p);
    }
  }

  void _cap(Canvas canvas, double s, double op) {
    final r = s / 2;
    final c = Colors.lightBlueAccent.withValues(alpha: op);
    canvas.drawPath(
      Path()
        ..moveTo(0, -r * 0.5)..lineTo(r, 0)
        ..lineTo(0, r * 0.4)..lineTo(-r, 0)..close(),
      Paint()..color = c);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-r * 0.45, r * 0.38, r * 0.9, r * 0.38),
        const Radius.circular(2)),
      Paint()..color = c);
    final lp = Paint()..color = c..strokeWidth = 1.5;
    canvas.drawLine(Offset(r * 0.5, 0), Offset(r * 0.72, r * 0.6), lp);
    canvas.drawCircle(Offset(r * 0.72, r * 0.68), r * 0.1, Paint()..color = c);
  }

  void _pencil(Canvas canvas, double s, double op) {
    final r = s / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, -r * 0.1), width: r * 0.35, height: r * 1.35),
        const Radius.circular(2)),
      Paint()..color = Colors.lightBlueAccent.withValues(alpha: op));
    canvas.drawPath(
      Path()
        ..moveTo(-r * 0.175, r * 0.57)..lineTo(r * 0.175, r * 0.57)
        ..lineTo(0, r * 0.9)..close(),
      Paint()..color = Colors.amber.withValues(alpha: op * 0.9));
    canvas.drawRect(
      Rect.fromCenter(center: Offset(0, -r * 0.75), width: r * 0.35, height: r * 0.22),
      Paint()..color = Colors.pink.withValues(alpha: op * 0.7));
  }

  void _barChart(Canvas canvas, double s, double op) {
    final r = s / 2;
    const bw = 0.32;
    final xPos   = [-r * 0.62, -r * 0.22, r * 0.18, r * 0.58];
    final heights = [r * 0.7,   r * 1.1,   r * 0.85, r * 1.4];
    for (int i = 0; i < 4; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(xPos[i] - r * bw / 2, -heights[i], r * bw, heights[i]),
          const Radius.circular(2)),
        Paint()..color = Colors.greenAccent.withValues(alpha: op * (0.45 + i * 0.12)));
    }
    canvas.drawLine(Offset(-r, 0), Offset(r, 0),
      Paint()..color = Colors.greenAccent.withValues(alpha: op * 0.45)..strokeWidth = 1.2);
  }

  void _arrowUp(Canvas canvas, double s, double op) {
    final r = s / 2;
    final p = Paint()
      ..color = Colors.greenAccent.withValues(alpha: op)
      ..strokeWidth = 2.2..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    canvas.drawLine(Offset(0, r * 0.9), Offset(0, -r * 0.9), p);
    canvas.drawLine(Offset(0, -r * 0.9), Offset(-r * 0.5, -r * 0.35), p);
    canvas.drawLine(Offset(0, -r * 0.9), Offset(r * 0.5, -r * 0.35), p);
  }

  void _heart(Canvas canvas, double s, double op, Color tint) {
    final r = s / 2;
    final c = tint.withValues(alpha: op);
    final p = Paint()..color = c;
    canvas.drawCircle(Offset(-r * 0.28, -r * 0.22), r * 0.42, p);
    canvas.drawCircle(Offset( r * 0.28, -r * 0.22), r * 0.42, p);
    canvas.drawPath(
      Path()
        ..moveTo(-r * 0.64, -r * 0.1)
        ..lineTo( r * 0.64, -r * 0.1)
        ..lineTo(0, r * 0.62)..close(),
      p);
  }

  void _cross(Canvas canvas, double s, double op) {
    final r = s / 2;
    final p = Paint()
      ..color = Colors.pinkAccent.withValues(alpha: op)
      ..strokeWidth = s * 0.22..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, -r * 0.9), Offset(0, r * 0.9), p);
    canvas.drawLine(Offset(-r * 0.65, -r * 0.22), Offset(r * 0.65, -r * 0.22), p);
  }

  void _balloon(Canvas canvas, double s, double op) {
    final r = s / 2;
    canvas.drawCircle(Offset(0, -r * 0.18), r * 0.72,
      Paint()..color = Colors.purpleAccent.withValues(alpha: op));
    canvas.drawPath(
      Path()
        ..moveTo(0, r * 0.54)
        ..quadraticBezierTo(r * 0.18, r * 0.72, r * 0.05, r),
      Paint()
        ..color = Colors.purpleAccent.withValues(alpha: op * 0.55)
        ..style = PaintingStyle.stroke..strokeWidth = 1.2);
    canvas.drawCircle(Offset(0, r * 0.54), r * 0.1,
      Paint()..color = Colors.purpleAccent.withValues(alpha: op));
  }

  void _cloud(Canvas canvas, double s, double op) {
    final r = s / 2;
    final p = Paint()..color = Colors.white.withValues(alpha: op * 0.82);
    canvas.drawCircle(Offset(-r * 0.32, r * 0.08), r * 0.48, p);
    canvas.drawCircle(Offset( r * 0.32, r * 0.08), r * 0.48, p);
    canvas.drawCircle(Offset(0, -r * 0.14), r * 0.60, p);
    canvas.drawRect(Rect.fromLTWH(-r * 0.8, r * 0.04, r * 1.6, r * 0.52), p);
  }

  void _lightning(Canvas canvas, double s, double op) {
    final r = s / 2;
    canvas.drawPath(
      Path()
        ..moveTo( r * 0.22, -r)
        ..lineTo(-r * 0.12, -r * 0.04)
        ..lineTo( r * 0.18, -r * 0.04)
        ..lineTo(-r * 0.22,  r)
        ..lineTo( r * 0.12,  r * 0.04)
        ..lineTo(-r * 0.18,  r * 0.04)
        ..close(),
      Paint()..color = Colors.orangeAccent.withValues(alpha: op));
  }

  void _ball(Canvas canvas, double s, double op) {
    final r = s / 2;
    final p = Paint()
      ..color = Colors.orangeAccent.withValues(alpha: op)
      ..style = PaintingStyle.stroke..strokeWidth = 1.5;
    canvas.drawCircle(Offset.zero, r, p);
    canvas.drawArc(
      Rect.fromCenter(center: Offset.zero, width: r * 1.6, height: r * 0.9),
      0, math.pi, false, p);
    canvas.drawArc(
      Rect.fromCenter(center: Offset.zero, width: r * 1.6, height: r * 0.9),
      math.pi, math.pi, false, p);
  }

  void _musicNote(Canvas canvas, double s, double op) {
    final r = s / 2;
    final c = Colors.purpleAccent.withValues(alpha: op);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-r * 0.15, r * 0.42), width: r * 0.72, height: r * 0.52),
      Paint()..color = c);
    canvas.drawRect(
      Rect.fromLTWH(r * 0.21, -r * 0.92, r * 0.16, r * 1.44),
      Paint()..color = c);
    canvas.drawPath(
      Path()
        ..moveTo(r * 0.37, -r * 0.92)
        ..cubicTo(r * 0.9, -r * 0.42, r * 0.9, -r * 0.02, r * 0.37, r * 0.08),
      Paint()
        ..color = c..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.22..strokeCap = StrokeCap.round);
  }

  void _palette(Canvas canvas, double s, double op) {
    final r = s / 2;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, r * 0.1), width: r * 1.8, height: r * 1.4),
      Paint()
        ..color = Colors.purpleAccent.withValues(alpha: op)
        ..style = PaintingStyle.stroke..strokeWidth = 1.5);
    final dotOffsets = [
      Offset(-r * 0.50, -r * 0.22), Offset(-r * 0.12, -r * 0.48),
      Offset( r * 0.28, -r * 0.38), Offset( r * 0.55, -r * 0.05),
      Offset( r * 0.38,  r * 0.32),
    ];
    final dotColors = [
      Colors.redAccent, Colors.yellowAccent, Colors.blueAccent,
      Colors.greenAccent, Colors.pinkAccent,
    ];
    for (int j = 0; j < dotOffsets.length; j++) {
      canvas.drawCircle(dotOffsets[j], r * 0.18,
        Paint()..color = dotColors[j].withValues(alpha: op * 0.9));
    }
    canvas.drawCircle(Offset(-r * 0.42, r * 0.38), r * 0.18,
      Paint()
        ..color = Colors.purpleAccent.withValues(alpha: op)
        ..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  void _petal(Canvas canvas, double s, double op) {
    final r = s / 2;
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 0.5, height: r * 1.2),
      Paint()..color = Colors.pinkAccent.withValues(alpha: op));
  }

  void _star8(Canvas canvas, double s, double op) {
    final r = s / 2;
    final gold = const Color(0xFFFFD700).withValues(alpha: op);
    final p = Paint()..color = gold..style = PaintingStyle.stroke..strokeWidth = 1.5;
    for (int i = 0; i < 2; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 4);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: r * 1.3, height: r * 1.3), p);
      canvas.restore();
    }
    canvas.drawCircle(Offset.zero, r * 0.25, Paint()..color = gold);
  }

  void _crescent(Canvas canvas, double s, double op) {
    final r = s / 2;
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r)),
        Path()..addOval(Rect.fromCircle(
          center: Offset(r * 0.42, -r * 0.08), radius: r * 0.78)),
      ),
      Paint()..color = const Color(0xFFFFD700).withValues(alpha: op));
  }

  void _rainStreak(Canvas canvas, double s, double op) {
    final r = s / 2;
    final p = Paint()
      ..color = Colors.blueGrey.withValues(alpha: op * 0.8)
      ..strokeWidth = 1.0..strokeCap = StrokeCap.round;
    for (int i = -2; i <= 2; i++) {
      final x = i * r * 0.35;
      final len = r * (0.9 + i.abs() * 0.12);
      canvas.drawLine(Offset(x - len * 0.1, -len), Offset(x + len * 0.1, len), p);
    }
  }

  @override
  bool shouldRepaint(_CategoryBgPainter old) =>
      old.t != t || old.category != category;
}
