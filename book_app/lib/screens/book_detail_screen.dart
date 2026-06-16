import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/book_provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_strings.dart';
import '../services/api_service.dart';
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

class _BookDetailScreenState extends State<BookDetailScreen> {
  final ApiService _api  = ApiService();
  Map<String, dynamic>? _detail;
  bool _loading  = true;
  bool _buying   = false;
  bool _saved    = false;
  bool _saving   = false;
  bool _inWishlist = false;
  bool _wishlistBusy = false;
  bool _inCart   = false;
  bool _addingToCart = false;

  // Ratings
  List<dynamic> _ratings = [];
  Map<String, dynamic>? _myRating;
  int _selectedStars = 0;
  final TextEditingController _reviewCtrl = TextEditingController();
  bool _submittingRating = false;

  @override
  void initState() {
    super.initState();
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
    setState(() => _submittingRating = true);
    try {
      await _api.submitRating(widget.bookId, _selectedStars, _reviewCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(S.ratingSubmitted), backgroundColor: AppTheme.success));
        await _loadRatings();
        // Refresh avg rating shown on this page
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
      await context.read<BookProvider>().purchaseBook(widget.bookId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(S.buySuccess),
          backgroundColor: AppTheme.success,
        ));
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppTheme.danger,
        ));
      }
    } finally {
      setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient))),
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
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppTheme.primary,
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
                  // Cover blur background
                  if (_detail!['cover_image'] != null)
                    Opacity(opacity: 0.4,
                        child: safeNetworkImage(
                            _detail!['cover_image']?.toString(),
                            fit: BoxFit.cover)),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: AppTheme.headerGradient),
                  ),
                  // Cover centered
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20)],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
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
                      builder: (_) => ReaderScreen(bookId: widget.bookId)));
                },
              ),
            ),
          ),

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
              onPressed: _buying ? null : () {
                _purchase();
              },
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
