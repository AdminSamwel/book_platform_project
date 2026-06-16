import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/language_toggle.dart';
import 'home_screen.dart';
import 'author_dashboard_screen.dart';
import 'admin_dashboard_screen.dart';
import 'register_screen.dart';
import 'otp_verify_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  bool  _obscure      = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSession());
  }

  Future<void> _checkSession() async {
    final auth = context.read<AuthProvider>();
    await auth.checkAuthStatus();
    if (!mounted || !auth.isLoggedIn) return;
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => auth.isAdmin
          ? const AdminDashboardScreen()
          : auth.isAuthor
              ? const AuthorDashboardScreen()
              : const HomeScreen(),
    ));
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final auth = context.read<AuthProvider>();
      await auth.login(_usernameCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => auth.isAdmin
            ? const AdminDashboardScreen()
            : auth.isAuthor
                ? const AuthorDashboardScreen()
                : const HomeScreen(),
      ));
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.danger,
      ));
      // Akaunti mpya isiyothibitishwa - mpeleke kuthibitisha OTP
      if (msg.contains('haijathibitishwa') || msg.toLowerCase().contains('not verified')) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => OtpVerifyScreen(identifier: _usernameCtrl.text.trim()),
        ));
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    try {
      final auth = context.read<AuthProvider>();
      await auth.loginWithGoogle();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => auth.isAdmin
            ? const AdminDashboardScreen()
            : auth.isAuthor
                ? const AuthorDashboardScreen()
                : const HomeScreen(),
      ));
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
    context.watch<LanguageProvider>(); // rebuild on lang change
    final auth   = context.watch<AuthProvider>();
    final isWide = !Responsive.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [
          LanguageDropdown(),
          SizedBox(width: 12),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: isWide ? _wideLayout(auth) : _mobileLayout(auth),
    );
  }

  Widget _wideLayout(AuthProvider auth) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      color: Colors.white, size: 72),
                ),
                const SizedBox(height: 28),
                Text(S.appName,
                    style: const TextStyle(color: Colors.white, fontSize: 30,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(S.learnGrow,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 16)),
                const SizedBox(height: 40),
                _statRow(),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: _formContent(auth),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _statItem('1000+', S.books),
        const SizedBox(width: 40),
        _statItem('500+', S.t('Wasomaji', 'Readers')),
        const SizedBox(width: 40),
        _statItem('50+', S.t('Waandishi', 'Authors')),
      ],
    );
  }

  Widget _statItem(String num, String label) => Column(
    children: [
      Text(num, style: const TextStyle(color: Colors.white,
          fontSize: 22, fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
    ],
  );

  Widget _mobileLayout(AuthProvider auth) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppTheme.headerGradient,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: const Icon(Icons.menu_book_rounded,
                  color: Colors.white, size: 48),
            ),
            const SizedBox(height: 20),
            Text(S.appName,
                style: TextStyle(fontSize: 24,
                    fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
            const SizedBox(height: 6),
            Text(S.loginTo,
                style: TextStyle(color: AppTheme.textSecondary(context))),
            const SizedBox(height: 36),
            _formContent(auth),
          ],
        ),
      ),
    );
  }

  Widget _formContent(AuthProvider auth) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!Responsive.isMobile(context)) ...[
            Text(S.welcomeBack,
                style: TextStyle(fontSize: 26,
                    fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
            const SizedBox(height: 6),
            Text(S.enterDetails,
                style: TextStyle(color: AppTheme.textSecondary(context))),
            const SizedBox(height: 32),
          ],
          TextFormField(
            controller: _usernameCtrl,
            decoration: InputDecoration(
              labelText: S.usernameOrContact,
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
            validator: (v) => v == null || v.trim().isEmpty
                ? S.usernameReq : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: S.password,
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscure
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                    color: AppTheme.textSecondary(context)),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) => v == null || v.isEmpty ? S.passwordReq : null,
            onFieldSubmitted: (_) => _login(),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: auth.isLoading
                ? const Center(child: CircularProgressIndicator(
                    color: AppTheme.primary))
                : ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(S.login,
                        style: const TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(S.orContinueWith,
                    style: TextStyle(color: AppTheme.textSecondary(context))),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: auth.isLoading ? null : _loginWithGoogle,
              icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
              label: Text(S.continueWithGoogle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(S.noAccount,
                  style: TextStyle(color: AppTheme.textSecondary(context))),
              TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: Text(S.register,
                    style: const TextStyle(fontWeight: FontWeight.bold,
                        color: AppTheme.primary)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
