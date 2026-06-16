import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

const Color _kPillBorder = Color(0x294F46E5); // AppTheme.primary @ 16%
final List<BoxShadow> _kPillShadow = [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.12),
    blurRadius: 8,
    offset: const Offset(0, 2),
  ),
];

/// Kitufe kidogo cha kubadilisha Dark Mode / Light Mode haraka.
/// Kinapatikana kwenye kila ukurasa (kando ya kitufe cha lugha).
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.isDark;

    return Tooltip(
      message: isDark ? 'Badilisha kwenda Mwanga' : 'Badilisha kwenda Giza',
      child: GestureDetector(
        onTap: () => settings.toggleDarkMode(!isDark),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            shape: BoxShape.circle,
            border: Border.all(color: _kPillBorder, width: 1),
            boxShadow: _kPillShadow,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) =>
                RotationTransition(turns: anim, child: child),
            child: Icon(
              isDark
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
              key: ValueKey(isDark),
              color: AppTheme.primary,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}
