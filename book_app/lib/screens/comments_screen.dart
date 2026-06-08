import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class CommentsScreen extends StatefulWidget {
  final int bookId;
  const CommentsScreen({super.key, required this.bookId});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final ApiService _api     = ApiService();
  final _textCtrl           = TextEditingController();
  final _scrollCtrl         = ScrollController();
  List<dynamic> _comments   = [];
  bool _loading             = true;
  bool _sending             = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final data = await _api.fetchComments(widget.bookId);
      setState(() { _comments = data; _loading = false; });
      _scrollToBottom();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _postComment() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _api.postComment(widget.bookId, text);
      _textCtrl.clear();
      await _loadComments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Hitilafu: $e'),
        backgroundColor: AppTheme.danger,
      ));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Maoni (${_comments.length})'),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(
                    color: AppTheme.primary))
                : _comments.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: _comments.length,
                        itemBuilder: (ctx, i) => _commentBubble(_comments[i]),
                      ),
          ),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _commentBubble(dynamic comment) {
    final username = comment['username'] ?? 'Mgeni';
    final text     = comment['text'] ?? '';
    final date     = comment['created_at']?.toString().substring(0, 10) ?? '';
    final initial  = username.isNotEmpty ? username[0].toUpperCase() : 'U';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
            child: Text(initial,
              style: const TextStyle(
                  color: AppTheme.primary, fontWeight: FontWeight.bold,
                  fontSize: 13)),
          ),
          const SizedBox(width: 10),
          // Bubble
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(username,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13,
                          color: AppTheme.textDark)),
                    const SizedBox(width: 8),
                    Text(date,
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.textMuted)),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.06),
                        blurRadius: 8, offset: const Offset(0, 2))
                    ],
                  ),
                  child: Text(text,
                    style: const TextStyle(
                        fontSize: 14, color: AppTheme.textDark, height: 1.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.08),
            blurRadius: 12, offset: const Offset(0, -4))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textCtrl,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Andika maoni yako...',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                fillColor: AppTheme.surface,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sending ? null : _postComment,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: _sending ? null : AppTheme.primaryGradient,
                color: _sending ? Colors.grey.shade300 : null,
                shape: BoxShape.circle,
                boxShadow: _sending ? null : [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                    blurRadius: 8, offset: const Offset(0, 3))
                ],
              ),
              child: _sending
                  ? const Center(child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 60,
              color: AppTheme.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('Hakuna maoni bado',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                color: AppTheme.textDark)),
          const SizedBox(height: 8),
          const Text('Kuwa wa kwanza kutoa maoni!',
            style: TextStyle(color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}
