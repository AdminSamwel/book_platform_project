import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/language_toggle.dart';
import 'home_screen.dart';
import 'admin_dashboard_screen.dart';
import 'author_dashboard_screen.dart';

/// Ukurasa wa kuthibitisha akaunti mpya kwa nambari ya OTP iliyotumwa
/// kwa email/simu ya mtumiaji wakati wa usajili.
class OtpVerifyScreen extends StatefulWidget {
  final String identifier;

  const OtpVerifyScreen({super.key, required this.identifier});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _codeCtrl = TextEditingController();
  final _formKey  = GlobalKey<FormState>();

  Timer? _timer;
  int _secondsLeft = 60;
  bool _resending  = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _secondsLeft = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final auth = context.read<AuthProvider>();
      await auth.verifyOtp(widget.identifier, _codeCtrl.text.trim());
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => auth.isAdmin
              ? const AdminDashboardScreen()
              : auth.isAuthor
                  ? const AuthorDashboardScreen()
                  : const HomeScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppTheme.danger,
      ));
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      final auth = context.read<AuthProvider>();
      await auth.resendOtp(widget.identifier);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(S.otpResent),
        backgroundColor: AppTheme.success,
      ));
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppTheme.danger,
      ));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
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
                          child: const Icon(Icons.mark_email_read_rounded,
                              size: 48, color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        Text(S.otpTitle,
                          style: const TextStyle(color: Colors.white,
                              fontSize: 26, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('${S.otpSentTo} ${widget.identifier}',
                          textAlign: TextAlign.center,
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

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _codeCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                        decoration: InputDecoration(
                          labelText: S.enterOtpCode,
                          prefixIcon: const Icon(Icons.pin_outlined),
                          counterText: '',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? S.otpCodeReq : null,
                      ),
                      const SizedBox(height: 28),

                      SizedBox(
                        height: 52,
                        child: auth.isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(
                                onPressed: _verify,
                                child: Text(S.verifyOtpBtn),
                              ),
                      ),
                      const SizedBox(height: 20),

                      Center(
                        child: _secondsLeft > 0
                            ? Text('${S.resendIn} $_secondsLeft s',
                                style: TextStyle(color: AppTheme.textSecondary(context)))
                            : _resending
                                ? const CircularProgressIndicator()
                                : TextButton(
                                    onPressed: _resend,
                                    child: Text(S.resendOtpBtn,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primary)),
                                  ),
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
}
