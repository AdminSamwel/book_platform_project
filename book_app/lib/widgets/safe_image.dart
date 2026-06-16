import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Inaonyesha picha salama — haiingii assertion error hata URL ikiwa tupu/null
Widget safeNetworkImage(
  String? url, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget? placeholder,
}) {
  final ph = placeholder ??
      Container(
        width: width,
        height: height,
        color: AppTheme.primary.withValues(alpha: 0.08),
        child: const Center(
          child: Icon(Icons.menu_book_rounded,
              color: AppTheme.primary, size: 36),
        ),
      );

  // URL lazima iwe na thamani halisi
  if (url == null || url.trim().isEmpty || !url.startsWith('http')) {
    return ph;
  }

  return Image.network(
    url,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (_, __, ___) => ph,
    loadingBuilder: (_, child, progress) {
      if (progress == null) return child;
      return Container(
        width: width,
        height: height,
        color: AppTheme.primary.withValues(alpha: 0.05),
        child: const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppTheme.primary)),
      );
    },
  );
}
