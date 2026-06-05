import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import 'dart:convert';

class AuthProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _isLoggedIn = false;
  bool _isLoading = false;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;

  Future<void> login(String username, String password) async {
    _isLoading = true; notifyListeners();
    try {
      final res = await _api.login(username, password);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await _storage.write(key: 'access_token', value: data['access']);
        await _storage.write(key: 'refresh_token', value: data['refresh']);
        _isLoggedIn = true;
        notifyListeners();
      } else {
        throw Exception(jsonDecode(res.body)['detail'] ?? 'Imeshindwa kuingia');
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false; notifyListeners();
    }
  }

  Future<void> register(String username, String password, String role) async {
    _isLoading = true; notifyListeners();
    try {
      final res = await _api.register(username, password, role);
      if (res.statusCode == 201) {
        await login(username, password);
      } else {
        throw Exception(jsonDecode(res.body)['detail'] ?? 'Usajili umeshindikana');
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false; notifyListeners();
    }
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    _isLoggedIn = false;
    notifyListeners();
  }
}