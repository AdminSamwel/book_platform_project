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
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      drawer: _buildDrawer(auth),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primary,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: topInset + kToolbarHeight + 110,
              backgroundColor: const Color(0xFF1E1B4B),
              foregroundColor: Colors.white,
              leading: Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Colors.white),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
              actions: [
                const LanguageDropdown(),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1E1B4B), Color(0xFF4C1D95),
                              Color(0xFF4F46E5)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    Positioned(top: -20, right: -20, child: _bokeh(150, 0.14)),
                    Positioned(bottom: 10, right: 90, child: _bokeh(70, 0.11)),
                    Positioned(top: 50, left: -25, child: _bokeh(100, 0.09)),
                    Padding(
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
                            child: Row(mainAxisSize: MainAxisSize.min,
                                children: [
                              const Icon(Icons.shield_rounded,
                                  color: Colors.white70, size: 12),
                              const SizedBox(width: 5),
                              Text(S.adminDashboard,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 11)),
                            ]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            auth.username.isEmpty
                                ? '${S.greeting}!'
                                : '${S.greeting}, ${auth.username}!',
                            style: const TextStyle(color: Colors.white,
                                fontSize: 22, fontWeight: FontWeight.w800),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
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
          _sectionLabel(S.overview),
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
          _sectionLabel(S.dashboard),
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
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF4C1D95), Color(0xFF4F46E5)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(top: -10, right: -10, child: _bokeh(80, 0.12)),
                Positioned(bottom: 0, right: 55, child: _bokeh(50, 0.09)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4), width: 2),
                      ),
                      child: const CircleAvatar(
                        radius: 28, backgroundColor: Colors.white24,
                        child: Icon(Icons.admin_panel_settings_rounded,
                            color: Colors.white, size: 30),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(auth.username,
                      style: const TextStyle(color: Colors.white, fontSize: 18,
                          fontWeight: FontWeight.bold),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(S.adminDashboard,
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
                const Divider(height: 24),
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
            colors: [Color(0xFF4C1D95), Color(0xFF4F46E5)],
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
