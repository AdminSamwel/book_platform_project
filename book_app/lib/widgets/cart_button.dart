import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../screens/cart_screen.dart';

/// Kitufe cha "kikapu" chenye alama (badge) ya idadi ya vitabu vilivyomo
/// kwenye kikapu cha mnunuzi. Hujipakia lenyewe na kujiongeza upya kila
/// baada ya sekunde 30.
class CartButton extends StatefulWidget {
  const CartButton({super.key});

  @override
  State<CartButton> createState() => _CartButtonState();
}

class _CartButtonState extends State<CartButton> {
  final ApiService _api = ApiService();
  int _count = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  Future<void> _load() async {
    try {
      final data = await _api.fetchCart();
      final count = (data['count'] as num?)?.toInt() ?? 0;
      if (mounted) setState(() => _count = count);
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.shopping_cart_rounded),
          onPressed: () async {
            await Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CartScreen()));
            _load();
          },
        ),
        if (_count > 0)
          Positioned(
            right: 6, top: 6,
            child: Container(
              padding: const EdgeInsets.all(3),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: AppTheme.secondary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                _count > 9 ? '9+' : '$_count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}
