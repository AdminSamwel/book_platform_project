import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/language_toggle.dart';

// ─── Emoji categories used in the picker ────────────────────────────────────
const _kEmojis = [
  '❤️','😂','😍','🔥','👍','👏','😮','😢','😡','🙏','✨','💯',
  '😊','😎','🤔','😅','🥹','🤩','😭','😤','🤝','💪','👀','🎉',
  '📚','✍️','💡','🌟','👌','🙌','💬','🗣️','📖','🤓','🥳','😇',
];

class CommentsScreen extends StatefulWidget {
  final int bookId;
  const CommentsScreen({super.key, required this.bookId});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen>
    with TickerProviderStateMixin {
  static const _storage = FlutterSecureStorage();

  final ApiService    _api        = ApiService();
  final _textCtrl                  = TextEditingController();
  final _scrollCtrl                = ScrollController();
  final _inputFocus                = FocusNode();

  List<dynamic> _comments          = [];
  bool          _loading           = true;
  bool          _sending           = false;
  bool          _showEmojis        = false;

  // Reply state
  Map<String, dynamic>? _replyTarget;

  // Current logged-in user
  int?    _myUserId;

  // Book author id (fetched from first comment that has is_author=true, or from API)
  int? _bookAuthorId;

  @override
  void initState() {
    super.initState();
    _initUser();
    _loadComments();
  }

  Future<void> _initUser() async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      try {
        // Decode JWT payload without external package
        final parts   = token.split('.');
        if (parts.length == 3) {
          final payload = parts[1];
          final norm    = base64Url.normalize(payload);
          final decoded = jsonDecode(utf8.decode(base64Url.decode(norm)))
              as Map<String, dynamic>;
          setState(() {
            _myUserId   = decoded['user_id'] as int?;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _loadComments({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final data = await _api.fetchComments(widget.bookId);
      // Find book author id from comments
      final authorComment = data.firstWhere(
          (c) => c['is_author'] == true, orElse: () => null);
      if (mounted) {
        setState(() {
          _comments    = data;
          _loading     = false;
          if (authorComment != null) {
            _bookAuthorId = authorComment['user_id'] as int?;
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Send comment / reply ──────────────────────────────────────────────────
  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _sending = true; _showEmojis = false; });
    try {
      await _api.postComment(
        widget.bookId, text,
        parentId: _replyTarget?['id'] as int?,
      );
      _textCtrl.clear();
      setState(() => _replyTarget = null);
      await _loadComments(silent: true);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('imefungiwa') || msg.contains('banned')) {
        _showSnack(S.cannotComment, isError: true);
      } else {
        _showSnack('${S.sendFailed}: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Delete comment ────────────────────────────────────────────────────────
  Future<void> _deleteComment(Map<String, dynamic> comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.delete_outline_rounded, color: AppTheme.danger),
          const SizedBox(width: 8),
          Text(S.deleteMsg),
        ]),
        content: Text(S.confirmDelete),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(S.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger),
            child: Text(S.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.deleteComment(widget.bookId, comment['id'] as int);
      _showSnack(S.msgDeleted);
      await _loadComments(silent: true);
    } catch (e) {
      _showSnack('$e', isError: true);
    }
  }

  // ── React to comment ──────────────────────────────────────────────────────
  Future<void> _react(Map<String, dynamic> comment, String emoji) async {
    if (_myUserId == null) {
      _showSnack(S.t('Ingia kwanza kutumia emoji', 'Login first to react'),
          isError: true);
      return;
    }
    try {
      final updated = await _api.reactToComment(
          widget.bookId, comment['id'] as int, emoji);
      // Update reactions in place (no full reload needed)
      setState(() {
        final idx = _comments.indexWhere((c) => c['id'] == comment['id']);
        if (idx != -1) {
          _comments[idx] = Map<String, dynamic>.from(_comments[idx])
            ..['reactions'] = updated;
        }
      });
    } catch (e) {
      _showSnack('$e', isError: true);
    }
  }

  // ── Report comment ────────────────────────────────────────────────────────
  Future<void> _reportComment(Map<String, dynamic> comment) async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ReportSheet(),
    );
    if (result == null) return;
    try {
      await _api.reportComment(
        widget.bookId, comment['id'] as int,
        result['reason'] ?? 'other',
        details: result['details'] ?? '',
      );
      _showSnack(S.reportSent);
      await _loadComments(silent: true);
    } catch (e) {
      _showSnack('$e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.danger : AppTheme.success,
    ));
  }

  // ── Long-press context menu ───────────────────────────────────────────────
  void _onLongPress(Map<String, dynamic> comment) {
    final isMyMsg   = (comment['user_id'] as int?) == _myUserId;
    final isDeleted = comment['is_deleted'] == true;
    if (isDeleted) return;

    // Check if current user is book author
    final isBookAuthor = _myUserId != null && _myUserId == _bookAuthorId;
    final canDelete    = isMyMsg || isBookAuthor;
    final isFlagged    = comment['is_flagged'] == true;
    final canReport    = !isMyMsg && _myUserId != null;

    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContextMenu(
        comment:   comment,
        canDelete: canDelete,
        isViolation: canDelete && isBookAuthor && !isMyMsg && isFlagged,
        canReport: canReport,
        onReply:   () {
          setState(() => _replyTarget = comment);
          Navigator.pop(context);
          _inputFocus.requestFocus();
        },
        onDelete: canDelete
            ? () { Navigator.pop(context); _deleteComment(comment); }
            : null,
        onReport: canReport
            ? () { Navigator.pop(context); _reportComment(comment); }
            : null,
        onReact: (emoji) {
          Navigator.pop(context);
          _react(comment, emoji);
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();

    // Unique participants
    final participants = _comments
        .map((c) => c['username'])
        .toSet()
        .length;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.discussion,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (!_loading && _comments.isNotEmpty)
              Text('$participants ${S.participants}',
                  style: const TextStyle(fontSize: 11,
                      color: Colors.white70, fontWeight: FontWeight.normal)),
          ],
        ),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => _loadComments(),
            tooltip: S.t('Onyesha upya', 'Refresh'),
          ),
          const LanguageDropdown(),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ── Message list ──────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(
                    color: AppTheme.primary))
                : _comments.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16),
                        itemCount: _comments.length,
                        itemBuilder: (_, i) =>
                            _ChatBubble(
                              comment:    _comments[i],
                              isMine:     (_comments[i]['user_id'] as int?) ==
                                          _myUserId,
                              onLongPress: () => _onLongPress(_comments[i]),
                              onReact:    (emoji) =>
                                          _react(_comments[i], emoji),
                              onReply:    () {
                                setState(() => _replyTarget = _comments[i]);
                                _inputFocus.requestFocus();
                              },
                            ),
                      ),
          ),

          // ── Reply preview bar ─────────────────────────────────────────────
          if (_replyTarget != null)
            _ReplyBar(
              comment: _replyTarget!,
              onCancel: () => setState(() => _replyTarget = null),
            ),

          // ── Emoji picker ──────────────────────────────────────────────────
          if (_showEmojis) _EmojiBar(onPick: (e) {
            _textCtrl.text += e;
            _textCtrl.selection = TextSelection.fromPosition(
                TextPosition(offset: _textCtrl.text.length));
          }),

          // ── Input bar ─────────────────────────────────────────────────────
          _InputBar(
            controller:  _textCtrl,
            focusNode:   _inputFocus,
            sending:     _sending,
            showEmojis:  _showEmojis,
            onToggleEmoji: () => setState(() => _showEmojis = !_showEmojis),
            onSend:      _send,
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
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.chat_bubble_outline_rounded, size: 52,
              color: AppTheme.primary.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 20),
        Text(S.noComments,
            style: TextStyle(fontSize: 18,
                fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
        const SizedBox(height: 8),
        Text(S.beFirst,
            style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 14)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          icon: const Icon(Icons.chat_rounded),
          label: Text(S.writeComment),
          onPressed: () => _inputFocus.requestFocus(),
        ),
      ],
    ),
  );

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CHAT BUBBLE
// ═══════════════════════════════════════════════════════════════════════════
class _ChatBubble extends StatelessWidget {
  final Map<String, dynamic> comment;
  final bool    isMine;
  final VoidCallback onLongPress;
  final VoidCallback onReply;
  final void Function(String emoji) onReact;

  const _ChatBubble({
    required this.comment,
    required this.isMine,
    required this.onLongPress,
    required this.onReply,
    required this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    final isDeleted = comment['is_deleted'] == true;
    final isAuthor  = comment['is_author']  == true;
    final username  = comment['username']   ?? 'Mgeni';
    final text      = comment['display_text'] ??
                      comment['text'] ?? '';
    final time      = _formatTime(comment['created_at']?.toString() ?? '');
    final reactions = (comment['reactions'] as List?) ?? [];
    final replyUser = comment['reply_to_user'] as String?;
    final replyPrev = comment['reply_preview'] as String?;
    final isFlagged = comment['is_flagged'] == true && !isDeleted;

    final bubbleColor = isDeleted
        ? (AppTheme.isDark(context) ? AppTheme.darkBorder : Colors.grey.shade100)
        : isMine
            ? AppTheme.primary
            : AppTheme.card(context);
    final textColor = isMine && !isDeleted ? Colors.white : AppTheme.textPrimary(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar (left side only)
          if (!isMine) ...[
            _Avatar(
              username: username,
              isAuthor: isAuthor,
              avatarUrl: comment['user_avatar'] as String?,
            ),
            const SizedBox(width: 6),
          ],

          // Bubble
          Flexible(
            child: GestureDetector(
              onLongPress: onLongPress,
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Name + author badge (other side only)
                  if (!isMine)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(username,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isAuthor
                                      ? AppTheme.primary
                                      : AppTheme.textSecondary(context))),
                          if (isAuthor) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(S.authorBadge,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    ),

                  // Message bubble
                  Container(
                    constraints: BoxConstraints(
                        maxWidth:
                            MediaQuery.of(context).size.width * 0.72),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft:     const Radius.circular(18),
                        topRight:    const Radius.circular(18),
                        bottomLeft:  Radius.circular(isMine ? 18 : 4),
                        bottomRight: Radius.circular(isMine ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 6, offset: const Offset(0, 2))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Reply preview
                        if (replyUser != null && replyPrev != null)
                          _ReplyPreview(
                              user: replyUser,
                              text: replyPrev,
                              isMine: isMine),

                        // Text
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Text(text,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: isDeleted
                                      ? AppTheme.textSecondary(context)
                                      : textColor,
                                  fontStyle: isDeleted
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                  height: 1.4)),
                        ),

                        // Flagged warning chip
                        if (isFlagged)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.warning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(S.flaggedMsg,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isMine
                                          ? Colors.white
                                          : AppTheme.warning)),
                            ),
                          ),

                        // Time + reply button
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(time,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: isMine
                                          ? Colors.white60
                                          : AppTheme.textSecondary(context))),
                              if (!isDeleted) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: onReply,
                                  child: Text(S.replyMsg,
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: isMine
                                              ? Colors.white70
                                              : AppTheme.primary)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Reactions row
                  if (reactions.isNotEmpty)
                    _ReactionsRow(
                        reactions: reactions, onTap: onReact),
                ],
              ),
            ),
          ),

          // Spacer for own message avatar position
          if (isMine) const SizedBox(width: 4),
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h  = dt.hour.toString().padLeft(2, '0');
      final m  = dt.minute.toString().padLeft(2, '0');
      // Show date if not today
      final now   = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final day   = DateTime(dt.year, dt.month, dt.day);
      if (day == today) return '$h:$m';
      return '${dt.day}/${dt.month}  $h:$m';
    } catch (_) {
      return '';
    }
  }
}

// ── Avatar ───────────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String username;
  final bool   isAuthor;
  final String? avatarUrl;
  const _Avatar({required this.username, required this.isAuthor, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final initial = username.isNotEmpty ? username[0].toUpperCase() : 'U';
    final color   = isAuthor ? AppTheme.primary : const Color(0xFF7C3AED);
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    return Stack(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.15),
          backgroundImage: hasAvatar ? NetworkImage(avatarUrl!) : null,
          child: hasAvatar
              ? null
              : Text(initial,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        if (isAuthor)
          Positioned(
            bottom: 0, right: 0,
            child: Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5)),
              child: const Icon(Icons.edit_rounded,
                  color: Colors.white, size: 7),
            ),
          ),
      ],
    );
  }
}

// ── Reply preview inside bubble ──────────────────────────────────────────────
class _ReplyPreview extends StatelessWidget {
  final String user;
  final String text;
  final bool   isMine;
  const _ReplyPreview(
      {required this.user, required this.text, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: isMine
            ? Colors.white.withValues(alpha: 0.2)
            : AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
              color: isMine ? Colors.white : AppTheme.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isMine ? Colors.white : AppTheme.primary)),
          Text(text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  color: isMine
                      ? Colors.white70
                      : AppTheme.textSecondary(context))),
        ],
      ),
    );
  }
}

// ── Reactions row ─────────────────────────────────────────────────────────────
class _ReactionsRow extends StatelessWidget {
  final List<dynamic>                reactions;
  final void Function(String emoji) onTap;
  const _ReactionsRow({required this.reactions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        children: reactions.map((r) {
          final emoji      = r['emoji'] as String;
          final count      = r['count']  as int;
          final reactedByMe = r['reacted_by_me'] == true;
          return GestureDetector(
            onTap: () => onTap(emoji),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: reactedByMe
                    ? AppTheme.primary.withValues(alpha: 0.15)
                    : AppTheme.card(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: reactedByMe
                      ? AppTheme.primary
                      : AppTheme.borderColor(context),
                ),
              ),
              child: Text('$emoji $count',
                  style: TextStyle(fontSize: 12, color: AppTheme.textPrimary(context))),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Reply bar (shown above input when replying) ───────────────────────────────
class _ReplyBar extends StatelessWidget {
  final Map<String, dynamic> comment;
  final VoidCallback         onCancel;
  const _ReplyBar({required this.comment, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final user = comment['username'] ?? '';
    final text = comment['display_text'] ?? comment['text'] ?? '';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        border: Border(
            top: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Container(
            width: 3, height: 36,
            decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${S.replyTo} $user',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary)),
                Text(text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary(context))),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AppTheme.textSecondary(context),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

// ── Emoji bar ─────────────────────────────────────────────────────────────────
class _EmojiBar extends StatelessWidget {
  final void Function(String) onPick;
  const _EmojiBar({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.card(context),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      height: 96,
      child: GridView.count(
        crossAxisCount: 9,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        children: _kEmojis.map((e) => GestureDetector(
          onTap: () => onPick(e),
          child: Center(
            child: Text(e,
                style: const TextStyle(fontSize: 22)),
          ),
        )).toList(),
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode             focusNode;
  final bool                  sending;
  final bool                  showEmojis;
  final VoidCallback          onToggleEmoji;
  final VoidCallback          onSend;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.showEmojis,
    required this.onToggleEmoji,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        boxShadow: AppTheme.isDark(context)
            ? const []
            : [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -3))
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Emoji toggle
          IconButton(
            icon: Icon(
              showEmojis
                  ? Icons.keyboard_rounded
                  : Icons.emoji_emotions_rounded,
              color: AppTheme.primary),
            onPressed: onToggleEmoji,
            tooltip: S.reactWith,
          ),

          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.bg(context),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller:          controller,
                focusNode:           focusNode,
                maxLines:            5,
                minLines:            1,
                textCapitalization:  TextCapitalization.sentences,
                style: TextStyle(color: AppTheme.textPrimary(context)),
                decoration: InputDecoration(
                  hintText: S.typeMessage,
                  hintStyle: TextStyle(
                      color: AppTheme.textSecondary(context), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send button
          GestureDetector(
            onTap: sending ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: sending ? null : AppTheme.primaryGradient,
                color:    sending ? Colors.grey.shade300 : null,
                shape:    BoxShape.circle,
                boxShadow: sending ? null : [
                  BoxShadow(
                    color:   AppTheme.primary.withValues(alpha: 0.35),
                    blurRadius: 8, offset: const Offset(0, 3))
                ],
              ),
              child: sending
                  ? const Center(
                      child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Context menu (long-press bottom sheet) ────────────────────────────────────
class _ContextMenu extends StatelessWidget {
  final Map<String, dynamic>        comment;
  final bool                         canDelete;
  final bool                         isViolation;
  final bool                         canReport;
  final VoidCallback                 onReply;
  final VoidCallback?                onDelete;
  final VoidCallback?                onReport;
  final void Function(String emoji)  onReact;

  const _ContextMenu({
    required this.comment,
    required this.canDelete,
    this.isViolation = false,
    this.canReport = false,
    required this.onReply,
    required this.onDelete,
    this.onReport,
    required this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Quick emoji reactions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S.reactWith,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary(context),
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ['❤️','😂','😍','🔥','👍','👏','😮','😢',
                              '🙏','✨','💯','📚'].map((e) =>
                    GestureDetector(
                      onTap: () => onReact(e),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.bg(context),
                          borderRadius: BorderRadius.circular(12)),
                        child: Text(e,
                            style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                  ).toList(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Actions
          ListTile(
            leading: const Icon(Icons.reply_rounded, color: AppTheme.primary),
            title: Text(S.replyMsg),
            onTap: onReply,
          ),
          if (canReport && onReport != null) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.flag_outlined,
                  color: AppTheme.warning),
              title: Text(S.reportMsg,
                  style: const TextStyle(color: AppTheme.warning)),
              onTap: onReport,
            ),
          ],
          if (canDelete && onDelete != null) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppTheme.danger),
              title: Text(isViolation ? S.removeViolation : S.deleteMsg,
                  style: const TextStyle(color: AppTheme.danger)),
              onTap: onDelete,
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Report sheet ──────────────────────────────────────────────────────────────
class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String _reason = 'profanity';
  final _detailsCtrl = TextEditingController();

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reasons = <String, String>{
      'profanity':  S.reasonProfanity,
      'spam':       S.reasonSpam,
      'harassment': S.reasonHarassment,
      'other':      S.reasonOther,
    };

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.card(context),
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
              const Icon(Icons.flag_rounded, color: AppTheme.warning),
              const SizedBox(width: 8),
              Text(S.reportMsg,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 6),
            Text(S.reportReason,
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary(context))),
            const SizedBox(height: 10),
            ...reasons.entries.map((e) => RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: e.key,
                  groupValue: _reason,
                  activeColor: AppTheme.primary,
                  title: Text(e.value, style: const TextStyle(fontSize: 14)),
                  onChanged: (v) => setState(() => _reason = v!),
                )),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: S.reportDetails,
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
                    backgroundColor: AppTheme.warning,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                icon: const Icon(Icons.send_rounded),
                label: Text(S.submitReport),
                onPressed: () => Navigator.pop(context, {
                  'reason': _reason,
                  'details': _detailsCtrl.text.trim(),
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
