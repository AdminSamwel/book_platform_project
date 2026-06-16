import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/settings_provider.dart';
import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/language_toggle.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;
  final _bioCtrl = TextEditingController();

  Uint8List? _newAvatarBytes;
  String? _newAvatarFileName;

  DateTime? _dateOfBirth;
  bool _savingDob = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await _api.fetchProfile();
      setState(() {
        _profile = data;
        _bioCtrl.text = data['bio'] ?? '';
        final dob = data['date_of_birth']?.toString();
        _dateOfBirth = (dob != null && dob.isNotEmpty) ? DateTime.tryParse(dob) : null;
        _loading = false;
      });
      // Sasisha avatar kote kwenye programu (Nyumbani, Dashibodi, Ujumbe...)
      if (mounted) {
        await context.read<AuthProvider>().setAvatarUrl(data['avatar']);
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      final res = await _api.updateProfile(bio: _bioCtrl.text.trim());
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.profileSaved)));
        }
      } else {
        throw Exception(S.failedSave);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar() async {
    final r = await FilePicker.platform.pickFiles(
        type: FileType.image, withData: true);
    if (r == null || r.files.first.bytes == null) return;
    setState(() {
      _newAvatarBytes    = r.files.first.bytes;
      _newAvatarFileName = r.files.first.name;
    });
    await _uploadAvatar();
  }

  Future<void> _uploadAvatar() async {
    if (_newAvatarBytes == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final res = await _api.updateProfileMultipart(
        avatarBytes: _newAvatarBytes,
        avatarFileName: _newAvatarFileName,
      );
      if (res.statusCode == 200) {
        await _loadProfile();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(S.photoUpdated)));
        }
      } else {
        throw Exception(S.failedPhoto);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingPhoto  = false;
          _newAvatarBytes  = null;
        });
      }
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _savingDob = true);
    try {
      final res = await _api.updateDateOfBirth(_formatDate(picked));
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() => _dateOfBirth = picked);
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(S.dateOfBirthSaved)));
        }
      } else {
        throw Exception(S.failedSave);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _savingDob = false);
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscure = true;
    bool submitting = false;
    String? errorText;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(S.changePassword),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: S.oldPassword,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: S.newPassword,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: S.confirmPassword,
                    border: const OutlineInputBorder(),
                  ),
                ),
                Row(
                  children: [
                    Checkbox(
                      value: !obscure,
                      onChanged: (v) =>
                          setDialogState(() => obscure = !(v ?? false)),
                    ),
                    Text(S.t('Onyesha manenosiri', 'Show passwords')),
                  ],
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 4),
                  Text(errorText!,
                      style: const TextStyle(color: AppTheme.danger)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: Text(S.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: submitting
                  ? null
                  : () async {
                      final oldP = oldCtrl.text;
                      final newP = newCtrl.text;
                      final confirmP = confirmCtrl.text;
                      if (oldP.isEmpty || newP.isEmpty || confirmP.isEmpty) {
                        setDialogState(() => errorText = S.fillAllFields);
                        return;
                      }
                      if (newP.length < 6) {
                        setDialogState(() => errorText = S.passwordTooShort);
                        return;
                      }
                      if (newP != confirmP) {
                        setDialogState(() => errorText = S.passwordsNoMatch);
                        return;
                      }
                      setDialogState(() {
                        submitting = true;
                        errorText  = null;
                      });
                      try {
                        final res = await _api.changePassword(
                            oldPassword: oldP, newPassword: newP);
                        if (res.statusCode == 200) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(S.passwordChanged)));
                          }
                        } else {
                          final body = jsonDecodeSafe(res.body);
                          final msg = body?['old_password']?[0] ??
                              body?['new_password']?[0] ??
                              body?['detail'] ??
                              S.failedSave;
                          setDialogState(() {
                            submitting = false;
                            errorText  = msg.toString();
                          });
                        }
                      } catch (e) {
                        setDialogState(() {
                          submitting = false;
                          errorText  = e.toString().replaceAll('Exception: ', '');
                        });
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(S.save),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); // rebuild on lang change
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: Text(S.profile),
        flexibleSpace: Container(
            decoration: const BoxDecoration(
                gradient: AppTheme.headerGradient)),
        actions: const [LanguageDropdown(), SizedBox(width: 8)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? Center(child: Text(S.failedProfile,
                  style: TextStyle(color: AppTheme.textSecondary(context))))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── Quick Dark/Light mode toggle ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.card(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppTheme.borderColor(context)),
                          boxShadow: AppTheme.shadow(context),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              settings.isDark
                                  ? Icons.dark_mode_rounded
                                  : Icons.light_mode_rounded,
                              color: AppTheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                settings.isDark
                                    ? S.themeDark
                                    : S.themeLight,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                            ),
                            Switch(
                              value: settings.isDark,
                              activeThumbColor: AppTheme.primary,
                              onChanged: (v) =>
                                  settings.toggleDarkMode(v),
                            ),
                            IconButton(
                              icon: Icon(Icons.tune_rounded,
                                  color: AppTheme.textSecondary(context)),
                              tooltip: S.settings,
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const SettingsScreen())),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _uploadingPhoto ? null : _pickAvatar,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: AppTheme.primary.withValues(
                                  alpha: 0.15),
                              backgroundImage: _newAvatarBytes != null
                                  ? MemoryImage(_newAvatarBytes!)
                                      as ImageProvider
                                  : (_profile!['avatar'] != null
                                      ? NetworkImage(_profile!['avatar'])
                                          as ImageProvider
                                      : null),
                              child: _newAvatarBytes == null &&
                                      _profile!['avatar'] == null
                                  ? const Icon(Icons.person,
                                      size: 50, color: AppTheme.primary)
                                  : null,
                            ),
                            if (_uploadingPhoto)
                              Container(
                                width: 100, height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.35),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5),
                                ),
                              ),
                            Positioned(
                              right: 0, bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppTheme.bg(context), width: 2),
                                ),
                                child: const Icon(Icons.camera_alt_rounded,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(S.changePhoto,
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary(context))),
                      const SizedBox(height: 16),
                      Text(
                        _profile!['username'] ?? '',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _profile!['role'] == 'author'
                              ? S.author : S.reader,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(S.personalBio,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _bioCtrl,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: S.bioHint,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                          ),
                          onPressed: _saving ? null : _saveProfile,
                          child: _saving
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : Text(S.saveBio),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(S.dateOfBirth,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(S.dateOfBirthHint,
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary(context))),
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: _savingDob ? null : _pickDateOfBirth,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.card(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.borderColor(context)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.cake_outlined,
                                  color: AppTheme.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _dateOfBirth != null
                                      ? _formatDate(_dateOfBirth!)
                                      : S.notSet,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary(context)),
                                ),
                              ),
                              if (_savingDob)
                                const SizedBox(width: 18, height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                              else
                                Icon(Icons.edit_rounded,
                                    size: 18, color: AppTheme.textSecondary(context)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(S.t('Usalama wa Akaunti', 'Account Security'),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: const BorderSide(color: AppTheme.primary),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _showChangePasswordDialog,
                          icon: const Icon(Icons.lock_reset_rounded),
                          label: Text(S.changePassword),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

/// Jaribu kufungua JSON ya jibu la server bila kutupa hitilafu
/// (server inaweza kurudisha ujumbe usio JSON wakati wa hitilafu).
Map<String, dynamic>? jsonDecodeSafe(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {}
  return null;
}
