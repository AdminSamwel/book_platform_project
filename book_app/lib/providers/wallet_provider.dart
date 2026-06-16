import 'package:flutter/material.dart';
import '../services/api_service.dart';

class WalletProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  double _balance = 0.0;
  List<dynamic> _transactions = [];
  bool _isLoading = false;

  double get balance => _balance;
  List<dynamic> get transactions => _transactions;
  bool get isLoading => _isLoading;

  Future<void> fetchWallet() async {
    _isLoading = true; notifyListeners();
    try {
      final data = await _api.fetchWallet();
      _balance = double.parse(data['balance'].toString());
      _transactions = data['transactions'] ?? [];
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      _isLoading = false; notifyListeners();
    }
  }

  Future<void> topUp(double amount) async {
    final res = await _api.topUpWallet(amount);
    if (res.statusCode == 200) {
      await fetchWallet();
    } else {
      throw Exception('Imeshindwa kuongeza pesa');
    }
  }
}

