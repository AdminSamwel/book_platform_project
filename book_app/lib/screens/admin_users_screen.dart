import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final ApiService _api = ApiService();
  final _searchCtrl = TextEditingController();
  List<dynamic> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final users = await _api.fetchAdminUsers(search: _searchCtrl.text.trim());
      if (!mounted) return;
      setState(() { _users = users; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _toggleBan(Map<String, dynamic> user) async {
    try {
      await _api.toggleUserBan(user['id'] as int);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(S.actionSuccess),
        backgroundColor: AppTheme.success,
      ));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppTheme.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.manageUsers),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: S.search,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: AppTheme.danger)));
    }
    if (_users.isEmpty) {
      return Center(child: Text(S.noData, style: TextStyle(color: AppTheme.textSecondary(context))));
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: _users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final u = _users[i];
          final banned = u['is_banned'] == true;
          final isSuper = u['is_superuser'] == true;
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.card(context),
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppTheme.shadow(context),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: Icon(
                    isSuper ? Icons.admin_panel_settings_rounded
                        : (u['role'] == 'author' ? Icons.edit_note_rounded : Icons.person_rounded),
                    color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${u['username']}',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                            color: AppTheme.textPrimary(context))),
                      const SizedBox(height: 2),
                      Text('${u['email'] ?? ''} · ${u['role']}',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (banned) Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(S.bannedUsers,
                              style: const TextStyle(fontSize: 10, color: AppTheme.danger)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isSuper)
                  TextButton(
                    onPressed: () => _toggleBan(u),
                    style: TextButton.styleFrom(
                      foregroundColor: banned ? AppTheme.success : AppTheme.danger,
                    ),
                    child: Text(banned ? S.unban : S.ban),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
