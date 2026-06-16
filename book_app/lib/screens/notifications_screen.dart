import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'comments_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.fetchNotifications();
      if (mounted) setState(() { _notifications = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _api.markAllNotificationsRead();
      if (mounted) {
        setState(() {
          _notifications = _notifications
              .map((n) => {...Map<String, dynamic>.from(n), 'is_read': true})
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _onTapNotification(Map<String, dynamic> n) async {
    if (n['is_read'] != true) {
      try {
        await _api.markNotificationRead(n['id'] as int);
        setState(() {
          final idx = _notifications.indexWhere((e) => e['id'] == n['id']);
          if (idx != -1) {
            _notifications[idx] = {...Map<String, dynamic>.from(_notifications[idx]), 'is_read': true};
          }
        });
      } catch (_) {}
    }
    final bookId = n['book'];
    if (bookId != null && mounted) {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => CommentsScreen(bookId: bookId as int)));
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'reply':       return Icons.reply_rounded;
      case 'reaction':    return Icons.emoji_emotions_rounded;
      case 'flagged':     return Icons.warning_amber_rounded;
      case 'removed':     return Icons.delete_forever_rounded;
      case 'report':         return Icons.flag_rounded;
      case 'moderation':     return Icons.shield_rounded;
      case 'author_message': return Icons.campaign_rounded;
      default:            return Icons.chat_bubble_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'flagged':
      case 'report':         return AppTheme.warning;
      case 'removed':        return AppTheme.danger;
      case 'author_message': return const Color(0xFF7C3AED);
      default:               return AppTheme.primary;
    }
  }

  String _timeAgo(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return S.justNow;
      if (diff.inMinutes < 60) return '${diff.inMinutes} ${S.minutesAgo}';
      if (diff.inHours < 24) return '${diff.inHours} ${S.hoursAgo}';
      return '${diff.inDays} ${S.daysAgo}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: Text(S.notifications),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
        actions: [
          if (_notifications.any((n) => n['is_read'] != true))
            IconButton(
              icon: const Icon(Icons.done_all_rounded, color: Colors.white),
              tooltip: S.markAllRead,
              onPressed: _markAllRead,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.notifications_none_rounded,
                            size: 52, color: AppTheme.primary.withValues(alpha: 0.5)),
                      ),
                      const SizedBox(height: 20),
                      Text(S.noNotifications,
                          style: TextStyle(fontSize: 16, color: AppTheme.textSecondary(context))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final n = _notifications[i];
                      final isRead = n['is_read'] == true;
                      final type = n['notif_type'] as String? ?? 'comment';
                      return Material(
                        color: isRead ? AppTheme.card(context) : AppTheme.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _onTapNotification(n),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _colorFor(type).withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(_iconFor(type), color: _colorFor(type), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(n['message'] ?? '',
                                          style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                                              color: AppTheme.textPrimary(context))),
                                      const SizedBox(height: 4),
                                      Text(_timeAgo(n['created_at']?.toString() ?? ''),
                                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context))),
                                    ],
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    width: 9, height: 9,
                                    margin: const EdgeInsets.only(top: 4, left: 6),
                                    decoration: const BoxDecoration(
                                        color: AppTheme.primary, shape: BoxShape.circle),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
