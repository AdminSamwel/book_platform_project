import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/api_service.dart';

class SubscriptionProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  List<dynamic> _plans = [];
  bool _isLoading = false;

  List<dynamic> get plans => _plans;
  bool get isLoading => _isLoading;

  Future<void> fetchPlans() async {
    _isLoading = true; notifyListeners();
    try {
      _plans = await _api.fetchPlans();
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      _isLoading = false; notifyListeners();
    }
  }

  Future<void> subscribe(int planId) async {
    final res = await _api.subscribe(planId);
    if (res.statusCode != 201) {
      final body = jsonDecode(res.body);
      throw Exception(body['detail'] ?? 'Imeshindwa kujisajili');
    }
  }
}