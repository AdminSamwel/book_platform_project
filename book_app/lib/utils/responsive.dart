import 'package:flutter/material.dart';

class Responsive {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1024;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;

  // Grid columns kulingana na ukubwa wa screen
  static int categoryColumns(BuildContext context) {
    final w = width(context);
    if (w >= 1200) return 4;
    if (w >= 900)  return 3;
    if (w >= 600)  return 3;
    return 2;
  }

  static int bookColumns(BuildContext context) {
    final w = width(context);
    if (w >= 1400) return 6;
    if (w >= 1100) return 5;
    if (w >= 800)  return 4;
    if (w >= 600)  return 3;
    return 2;
  }

  // Padding inayobadilika
  static double pagePadding(BuildContext context) {
    final w = width(context);
    if (w >= 1024) return 40;
    if (w >= 600)  return 24;
    return 16;
  }

  // Max width kwa content (kuweka center kwenye screen kubwa)
  static double maxContentWidth(BuildContext context) {
    final w = width(context);
    if (w >= 1400) return 1200;
    if (w >= 1024) return 900;
    return w;
  }

  // Font sizes
  static double titleSize(BuildContext context) =>
      isMobile(context) ? 20 : isTablet(context) ? 24 : 28;

  static double subtitleSize(BuildContext context) =>
      isMobile(context) ? 14 : 16;

  static double bodySize(BuildContext context) =>
      isMobile(context) ? 13 : 15;

  // Book card aspect ratio
  static double bookCardRatio(BuildContext context) =>
      isMobile(context) ? 0.58 : isTablet(context) ? 0.62 : 0.65;

  // Category card aspect ratio
  static double categoryCardRatio(BuildContext context) {
    final w = width(context);
    if (w >= 1024) return 2.0;
    if (w >= 600)  return 1.8;
    return 1.55;
  }
}

// Widget inayoweka content katikati kwenye screen kubwa
class CenteredContent extends StatelessWidget {
  final Widget child;
  const CenteredContent({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: Responsive.maxContentWidth(context),
        ),
        child: child,
      ),
    );
  }
}

// Responsive layout widget
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (Responsive.isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (Responsive.isTablet(context)) return tablet ?? mobile;
    return mobile;
  }
}
