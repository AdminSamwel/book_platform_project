import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/language_toggle.dart';
import 'admin_dashboard_screen.dart';
import 'author_dashboard_screen.dart';
import 'home_screen.dart';
import 'otp_verify_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

/// Sahihisha kama [value] ni email sahihi au namba ya simu sahihi
/// (sawa na `identify_contact()` ya backend - `users/serializers.py`).
bool _isValidEmailOrPhone(String value) {
  final emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  final phoneRe = RegExp(r'^\+?\d{9,15}$');
  return emailRe.hasMatch(value) || phoneRe.hasMatch(value);
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _identifierCtrl = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  final ApiService _api = ApiService();
  String _role        = 'reader';
  bool _obscure       = true;
  DateTime? _dateOfBirth;

  List<dynamic> _categories = [];
  final Set<int> _selectedCategoryIds = {};

  static const int _maxCategories = 3;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _api.fetchCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {}
  }

  void _toggleCategory(int id) {
    setState(() {
      if (_selectedCategoryIds.contains(id)) {
        _selectedCategoryIds.remove(id);
      } else {
        if (_selectedCategoryIds.length >= _maxCategories) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(S.categoriesMaxReached),
            backgroundColor: AppTheme.warning,
          ));
          return;
        }
        _selectedCategoryIds.add(id);
      }
    });
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _register() async {
    if (_formKey.currentState!.validate()) {
      try {
        final auth = context.read<AuthProvider>();
        final identifier = _identifierCtrl.text.trim();
        await auth.register(identifier, _passCtrl.text, _role,
            categoryIds: _role == 'reader' ? _selectedCategoryIds.toList() : null,
            dateOfBirth: _dateOfBirth != null ? _formatDate(_dateOfBirth!) : null);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(S.registrationOtpSent),
          backgroundColor: AppTheme.success,
        ));
        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => OtpVerifyScreen(identifier: identifier)));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppTheme.danger,
        ));
      }
    }
  }

  Future<void> _registerWithGoogle() async {
    try {
      final auth = context.read<AuthProvider>();
      await auth.loginWithGoogle();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
        builder: (_) => auth.isAdmin
            ? const AdminDashboardScreen()
            : auth.isAuthor
                ? const AuthorDashboardScreen()
                : const HomeScreen(),
      ), (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppTheme.danger,
      ));
    }
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); // rebuild on lang change
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Header ──
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 48, 24, 36),
                    decoration: const BoxDecoration(
                      gradient: AppTheme.headerGradient,
                      borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(32)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_add_rounded,
                              size: 48, color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        Text(S.register,
                          style: const TextStyle(color: Colors.white,
                              fontSize: 26, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(S.createAccountSub,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 14)),
                      ],
                    ),
                  ),
                  const Positioned(
                    top: 8,
                    right: 12,
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        children: [LanguageDropdown()],
                      ),
                    ),
                  ),
                ],
              ),

              // ── Form ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Role selector
                      Text(S.chooseAccountType,
                        style: TextStyle(fontWeight: FontWeight.w600,
                            fontSize: 14, color: AppTheme.textPrimary(context))),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _roleTile('reader', Icons.auto_stories_rounded,
                              S.reader, S.readerDesc),
                          const SizedBox(width: 12),
                          _roleTile('author', Icons.edit_rounded,
                              S.author, S.t('Chapisha vitabu', 'Publish books')),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Favorite categories (reader only)
                      if (_role == 'reader' && _categories.isNotEmpty) ...[
                        Text(S.chooseFavCategories,
                          style: TextStyle(fontWeight: FontWeight.w600,
                              fontSize: 14, color: AppTheme.textPrimary(context))),
                        const SizedBox(height: 4),
                        Text(S.chooseFavCategoriesHint,
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context))),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _categories.map((cat) {
                            final id = cat['id'] as int;
                            final name = cat['name']?.toString() ?? '';
                            final selected = _selectedCategoryIds.contains(id);
                            return ChoiceChip(
                              label: Text(name),
                              selected: selected,
                              selectedColor: AppTheme.primary.withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                  color: selected ? AppTheme.primary : AppTheme.textPrimary(context),
                                  fontWeight: selected ? FontWeight.bold : FontWeight.normal),
                              side: BorderSide(
                                  color: selected ? AppTheme.primary : AppTheme.borderColor(context)),
                              onSelected: (_) => _toggleCategory(id),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Email au Namba ya Simu
                      TextFormField(
                        controller: _identifierCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: S.emailOrPhone,
                          prefixIcon: const Icon(Icons.alternate_email_rounded),
                        ),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) return S.emailOrPhoneReq;
                          if (!_isValidEmailOrPhone(value)) return S.invalidEmailOrPhone;
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Password
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: S.password,
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility_off : Icons.visibility),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => v == null || v.length < 6
                            ? S.passwordMinReq : null,
                      ),
                      const SizedBox(height: 14),

                      // Date of birth
                      InkWell(
                        onTap: _pickDateOfBirth,
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: S.dateOfBirthOptional,
                            prefixIcon: const Icon(Icons.cake_outlined),
                            helperText: S.dateOfBirthHint,
                            helperMaxLines: 2,
                          ),
                          child: Text(
                            _dateOfBirth != null
                                ? _formatDate(_dateOfBirth!)
                                : S.selectDate,
                            style: TextStyle(
                                color: _dateOfBirth != null
                                    ? AppTheme.textPrimary(context)
                                    : AppTheme.textSecondary(context)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Button
                      SizedBox(
                        height: 52,
                        child: auth.isLoading
                            ? const Center(
                                child: CircularProgressIndicator())
                            : ElevatedButton(
                                onPressed: _register,
                                child: Text(S.createAccount),
                              ),
                      ),
                      const SizedBox(height: 20),

                      if (AuthProvider.isGoogleSignInSupported) ...[
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
                            onPressed: auth.isLoading ? null : _registerWithGoogle,
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
                      ],

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(S.hasAccount,
                            style: TextStyle(
                                color: AppTheme.textSecondary(context))),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(S.loginHere,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleTile(String value, IconData icon, String title,
      String subtitle) {
    final selected = _role == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _role = value),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.08)
                : AppTheme.card(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.borderColor(context),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? AppTheme.primary : AppTheme.textSecondary(context),
                  size: 28),
              const SizedBox(height: 8),
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppTheme.primary : AppTheme.textPrimary(context))),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary(context))),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: selected
                          ? AppTheme.primary : Colors.grey.shade400,
                      width: 2),
                  color: selected
                      ? AppTheme.primary : Colors.transparent,
                ),
                child: selected
                    ? const Icon(Icons.check, color: Colors.white, size: 12)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
