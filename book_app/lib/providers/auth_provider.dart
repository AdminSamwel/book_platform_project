import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/google_config.dart';
import '../services/api_service.dart';
import 'dart:convert';

class AuthProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool   _isLoggedIn = false;
  bool   _isLoading  = false;
  String _role       = 'reader';
  String _username   = '';
  String? _avatarUrl;
  bool   _isAdmin    = false;
  int?   _userId;

  bool   get isLoggedIn => _isLoggedIn;
  bool   get isLoading  => _isLoading;
  String get role       => _role;
  String get username   => _username;
  String? get avatarUrl => _avatarUrl;
  bool   get isAuthor   => _role == 'author';
  bool   get isAdmin    => _isAdmin;
  int?   get userId     => _userId;

  /// Sasisha picha ya profaili (avatar) ya mtumiaji aliyeingia kote
  /// kwenye programu (Nyumbani, Dashibodi, Maoni/Ujumbe, n.k.)
  Future<void> setAvatarUrl(String? url) async {
    _avatarUrl = url;
    if (url != null) {
      await _storage.write(key: 'avatar_url', value: url);
    } else {
      await _storage.delete(key: 'avatar_url');
    }
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    _isLoading = true; notifyListeners();
    try {
      // 1. Pata JWT tokens
      final res = await _api.login(username, password);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await _storage.write(key: 'access_token',  value: data['access']);
        await _storage.write(key: 'refresh_token', value: data['refresh']);

        // 2. Pata profile ili kujua role mara moja
        final profile = await _api.fetchProfile();
        _role      = profile['role'] ?? 'reader';
        _username  = profile['username'] ?? username;
        _avatarUrl = profile['avatar'];
        _isAdmin   = profile['is_staff'] == true || profile['is_superuser'] == true;
        _userId    = (profile['id'] as num?)?.toInt();

        // 3. Hifadhi role kwenye storage kwa matumizi ya baadaye
        await _storage.write(key: 'user_role', value: _role);
        await _storage.write(key: 'username',  value: _username);
        await _storage.write(key: 'is_admin',  value: _isAdmin.toString());
        if (_userId != null) {
          await _storage.write(key: 'user_id', value: _userId.toString());
        }
        if (_avatarUrl != null) {
          await _storage.write(key: 'avatar_url', value: _avatarUrl!);
        }

        _isLoggedIn = true;
        notifyListeners();
      } else {
        final body = jsonDecode(res.body);
        throw Exception(body['detail'] ?? 'Jina au nywila si sahihi');
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false; notifyListeners();
    }
  }

  /// Usajili mpya kwa email/simu (`identifier`). Akaunti inaundwa bila
  /// kuingia moja kwa moja - lazima kwanza ithibitishwe kwa OTP
  /// (tazama [verifyOtp]). Inarudisha `{'user_id':..., 'identifier':...}`.
  Future<Map<String, dynamic>> register(
      String identifier, String password, String role,
      {List<int>? categoryIds, String? dateOfBirth, int? referredByBookId}) async {
    _isLoading = true; notifyListeners();
    try {
      final res = await _api.register(identifier, password, role,
          categoryIds: categoryIds, dateOfBirth: dateOfBirth,
          referredByBookId: referredByBookId);
      final body = jsonDecode(res.body);
      if (res.statusCode == 201) {
        return body;
      } else {
        // Angalia aina zote za makosa kutoka Django
        String msg = body['detail'] ??
            body['identifier']?[0] ??
            body['password']?[0] ??
            'Usajili umeshindikana';
        throw Exception(msg);
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false; notifyListeners();
    }
  }

  /// Hifadhi JWT tokens na taarifa za profaili kutoka kwenye response ya
  /// uthibitisho (verify-otp / google-auth), kisha weka mtumiaji kuwa
  /// ameingia.
  Future<void> _applyAuthData(Map<String, dynamic> data,
      {String fallbackUsername = ''}) async {
    await _storage.write(key: 'access_token',  value: data['access']);
    await _storage.write(key: 'refresh_token', value: data['refresh']);

    final user = data['user'] ?? {};
    _role      = user['role'] ?? 'reader';
    _username  = user['username'] ?? fallbackUsername;
    _avatarUrl = user['avatar'];
    _isAdmin   = user['is_staff'] == true || user['is_superuser'] == true;
    _userId    = (user['id'] as num?)?.toInt();

    await _storage.write(key: 'user_role', value: _role);
    await _storage.write(key: 'username',  value: _username);
    await _storage.write(key: 'is_admin',  value: _isAdmin.toString());
    if (_userId != null) {
      await _storage.write(key: 'user_id', value: _userId.toString());
    }
    if (_avatarUrl != null) {
      await _storage.write(key: 'avatar_url', value: _avatarUrl!);
    }

    _isLoggedIn = true;
    notifyListeners();
  }

  /// Thibitisha akaunti mpya kwa nambari ya OTP, kisha ingia kiotomatiki.
  Future<void> verifyOtp(String identifier, String code) async {
    _isLoading = true; notifyListeners();
    try {
      final res = await _api.verifyOtp(identifier, code);
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        await _applyAuthData(data, fallbackUsername: identifier);
      } else {
        String msg = data['detail'] ??
            (data['non_field_errors'] is List ? data['non_field_errors'][0] : null) ??
            'Nambari ya OTP si sahihi au imeisha muda wake.';
        throw Exception(msg);
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false; notifyListeners();
    }
  }

  /// Rudisha true kama platform inasaidia Google Sign-In.
  /// google_sign_in ^6 inasaidia: Android, iOS, macOS, Web.
  /// Haifanyi kazi: Windows, Linux.
  static bool get isGoogleSignInSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// Rudisha true kama Google OAuth Client ID imewekwa vizuri.
  static bool get isGoogleConfigured =>
      googleWebClientId.isNotEmpty &&
      !googleWebClientId.startsWith('WEKA_') &&
      googleWebClientId.contains('.apps.googleusercontent.com');

  /// Ingia/Jisajili kwa akaunti ya Google. [referredByBookId] (hiari) -
  /// kitabu kilichoshirikiwa (share) ambacho kilimleta mtumiaji huyu.
  Future<void> loginWithGoogle({int? referredByBookId}) async {
    _isLoading = true; notifyListeners();
    try {
      if (!isGoogleSignInSupported) {
        throw Exception(
          'Google Sign-In haisaidiwi kwenye kifaa hiki. '
          'Tafadhali tumia jina la mtumiaji na nywila.');
      }
      if (!isGoogleConfigured) {
        throw Exception(
          'Google Sign-In haijasanidiwa bado. '
          'Wasiliana na msimamizi kuweka Google Client ID.');
      }
      final googleSignIn = GoogleSignIn(serverClientId: googleWebClientId);
      final account = await googleSignIn.signIn();
      if (account == null) throw Exception('Imeghairiwa.');
      final googleAuth = await account.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw Exception('Imeshindwa kupata token ya Google.');
      }
      final res = await _api.googleAuth(idToken, referredByBookId: referredByBookId);
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        await _applyAuthData(data, fallbackUsername: account.email);
      } else {
        String msg = data['detail'] ??
            (data['non_field_errors'] is List ? data['non_field_errors'][0] : null) ??
            (data['id_token'] is List ? data['id_token'][0] : null) ??
            'Imeshindwa kuingia kwa Google.';
        throw Exception(msg);
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false; notifyListeners();
    }
  }

  /// Tuma tena nambari ya OTP kwa akaunti isiyothibitishwa bado.
  Future<void> resendOtp(String identifier) async {
    final res = await _api.resendOtp(identifier);
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      String msg = data['detail'] ??
          (data['non_field_errors'] is List ? data['non_field_errors'][0] : null) ??
          'Imeshindwa kutuma OTP. Jaribu tena.';
      throw Exception(msg);
    }
  }

  // Angalia kama mtumiaji bado ameingia (app restart)
  Future<void> checkAuthStatus() async {
    final token       = await _storage.read(key: 'access_token');
    final savedRole   = await _storage.read(key: 'user_role');
    final savedUser   = await _storage.read(key: 'username');
    final savedAvatar = await _storage.read(key: 'avatar_url');
    final savedAdmin  = await _storage.read(key: 'is_admin');
    final savedUserId = await _storage.read(key: 'user_id');
    if (token != null) {
      _role       = savedRole ?? 'reader';
      _username   = savedUser ?? '';
      _avatarUrl  = savedAvatar;
      _isAdmin    = savedAdmin == 'true';
      _userId     = savedUserId != null ? int.tryParse(savedUserId) : null;
      _isLoggedIn = true;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    _isLoggedIn = false;
    _role       = 'reader';
    _username   = '';
    _avatarUrl  = null;
    _isAdmin    = false;
    _userId     = null;
    notifyListeners();
  }
}

