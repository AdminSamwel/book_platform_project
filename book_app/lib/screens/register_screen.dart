import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameCtrl = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  String _role        = 'reader';
  bool _obscure       = true;

  void _register() async {
    if (_formKey.currentState!.validate()) {
      try {
        await context.read<AuthProvider>().register(
          _usernameCtrl.text.trim(), _passCtrl.text, _role);
        if (!mounted) return;
        Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppTheme.danger,
        ));
      }
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Header ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 36),
                decoration: const BoxDecoration(
                  gradient: AppTheme.headerGradient,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_add_rounded, size: 48, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text('Jisajili',
                      style: TextStyle(color: Colors.white, fontSize: 26,
                          fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Tengeneza akaunti mpya',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
                  ],
                ),
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
                      const Text('Chagua aina ya akaunti',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                            color: AppTheme.textDark)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _roleCard('reader', Icons.auto_stories_rounded, 'Msomaji',
                            'Soma vitabu'),
                          const SizedBox(width: 12),
                          _roleCard('author', Icons.edit_rounded, 'Mwandishi',
                            'Chapisha vitabu'),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Username
                      TextFormField(
                        controller: _usernameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Jina la Mtumiaji',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Jina linahitajika' : null,
                      ),
                      const SizedBox(height: 14),

                      // Password
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Nywila',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => v == null || v.length < 6
                            ? 'Nywila lazima iwe herufi 6+' : null,
                      ),
                      const SizedBox(height: 28),

                      // Button
                      SizedBox(
                        height: 52,
                        child: auth.isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(
                                onPressed: _register,
                                child: const Text('Tengeneza Akaunti'),
                              ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Una akaunti tayari? ',
                            style: TextStyle(color: AppTheme.textMuted)),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Ingia Hapa',
                              style: TextStyle(fontWeight: FontWeight.bold,
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

  Widget _roleCard(String value, IconData icon, String title, String subtitle) {
    final selected = _role == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _role = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppTheme.primary : const Color(0xFFE5E7EB),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                color: selected ? AppTheme.primary : AppTheme.textMuted, size: 28),
              const SizedBox(height: 8),
              Text(title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? AppTheme.primary : AppTheme.textDark,
                )),
              Text(subtitle,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
