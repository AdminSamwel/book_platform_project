import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/language_toggle.dart';
import 'admin_users_screen.dart';
import 'admin_books_screen.dart';
import 'admin_plans_screen.dart';
import 'admin_royalties_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final stats = await _api.fetchAdminStats();
      if (!mounted) return;
      setState(() { _stats = stats; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      drawer: _buildDrawer(auth),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primary,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 140,
              backgroundColor: AppTheme.primary,
              leading: Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Colors.white),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
              actions: const [LanguageDropdown(), SizedBox(width: 8)],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(S.adminDashboard,
                          style: const TextStyle(color: Colors.white,
                              fontSize: 22, fontWeight: FontWeight.bold),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(
                          auth.username.isEmpty
                              ? '${S.greeting}!'
                              : '${S.greeting}, ${auth.username}',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(_error!, style: const TextStyle(color: AppTheme.danger)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: Text(S.retry)),
          ],
        ),
      );
    }

    final s = _stats!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.overview,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16,
                color: AppTheme.textPrimary(context))),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _statCard(Icons.people_alt_rounded, S.totalUsers,
                  '${s['total_users']}', const [Color(0xFF6366F1), Color(0xFF818CF8)]),
              _statCard(Icons.edit_note_rounded, S.authors,
                  '${s['total_authors']}', const [Color(0xFF7C3AED), Color(0xFFA78BFA)]),
              _statCard(Icons.menu_book_rounded, S.totalBooks,
                  '${s['total_books']}', const [Color(0xFF0EA5E9), Color(0xFF38BDF8)]),
              _statCard(Icons.check_circle_rounded, S.publishedBooks,
                  '${s['published_books']}', const [Color(0xFF10B981), Color(0xFF34D399)]),
              _statCard(Icons.hourglass_top_rounded, S.pendingBooks,
                  '${s['pending_books']}', const [Color(0xFFF59E0B), Color(0xFFFBBF24)]),
              _statCard(Icons.block_rounded, S.bannedUsers,
                  '${s['banned_users']}', const [Color(0xFFEF4444), Color(0xFFF87171)]),
              _statCard(Icons.workspace_premium_rounded, S.activeSubs,
                  '${s['active_subscriptions']}', const [Color(0xFF94A3B8), Color(0xFFCBD5E1)]),
              _statCard(Icons.account_balance_wallet_rounded, S.walletBalance,
                  'TZS ${s['total_wallet_balance']}', const [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
              _statCard(Icons.payments_rounded, S.totalRevenue,
                  'TZS ${s['total_revenue']}', const [Color(0xFF06B6D4), Color(0xFF22D3EE)]),
              _statCard(Icons.layers_rounded, S.totalPlans,
                  '${s['total_plans']}', const [Color(0xFFEC4899), Color(0xFFF472B6)]),
            ],
          ),
          const SizedBox(height: 24),
          Text(S.dashboard,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16,
                color: AppTheme.textPrimary(context))),
          const SizedBox(height: 12),
          _navCard(Icons.people_rounded, S.manageUsers,
              const [Color(0xFF6366F1), Color(0xFF818CF8)],
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminUsersScreen()))),
          const SizedBox(height: 12),
          _navCard(Icons.menu_book_rounded, S.manageBooks,
              const [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminBooksScreen()))),
          const SizedBox(height: 12),
          _navCard(Icons.workspace_premium_rounded, S.managePlans,
              const [Color(0xFF7C3AED), Color(0xFFA78BFA)],
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminPlansScreen()))),
          const SizedBox(height: 12),
          _navCard(Icons.pie_chart_rounded, S.royalties,
              const [Color(0xFF059669), Color(0xFF34D399)],
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminRoyaltiesScreen()))),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.public_rounded, color: AppTheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(S.djangoAdminPanel,
                        style: TextStyle(fontWeight: FontWeight.w600,
                            fontSize: 13, color: AppTheme.textPrimary(context))),
                      const SizedBox(height: 4),
                      SelectableText('${ApiService.baseUrl.replaceFirst('api/', '')}admin/',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String label, String value, List<Color> colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors,
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 8),
          Text(value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18,
                color: AppTheme.textPrimary(context)),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _navCard(IconData icon, String label, List<Color> colors, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.shadow(context),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors,
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(label,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                    color: AppTheme.textPrimary(context))),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(AuthProvider auth) {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 28, backgroundColor: Colors.white24,
                  child: Icon(Icons.admin_panel_settings_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(height: 12),
                Text(auth.username,
                  style: const TextStyle(color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.bold),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(S.adminDashboard,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _drawerItem(Icons.dashboard_rounded, S.dashboard,
                    () => Navigator.pop(context)),
                _drawerItem(Icons.people_rounded, S.manageUsers, () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AdminUsersScreen()));
                }),
                _drawerItem(Icons.menu_book_rounded, S.manageBooks, () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AdminBooksScreen()));
                }),
                _drawerItem(Icons.workspace_premium_rounded, S.managePlans, () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AdminPlansScreen()));
                }),
                _drawerItem(Icons.pie_chart_rounded, S.royalties, () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AdminRoyaltiesScreen()));
                }),
                const Divider(),
                _drawerItem(Icons.logout_rounded, S.logout, () {
                  auth.logout();
                  Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
                }, color: AppTheme.danger),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    final c = color ?? AppTheme.textPrimary(context);
    return ListTile(
      leading: Icon(icon, color: c),
      title: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}
