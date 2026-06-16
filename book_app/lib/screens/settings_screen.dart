import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/settings_provider.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/language_toggle.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); // rebuild on lang change
    final settings = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(S.settings),
        flexibleSpace: Container(
            decoration: const BoxDecoration(
                gradient: AppTheme.headerGradient)),
        actions: const [LanguageDropdown(), SizedBox(width: 8)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Mwonekano (Theme) ──
            _SectionCard(
              icon: Icons.brightness_6_rounded,
              title: S.appearance,
              subtitle: S.appearanceHint,
              isDark: isDark,
              child: Column(
                children: [
                  _ThemeOptionTile(
                    icon: Icons.light_mode_rounded,
                    label: S.themeLight,
                    selected: settings.themeMode == ThemeMode.light,
                    isDark: isDark,
                    onTap: () =>
                        settings.setThemeMode(ThemeMode.light),
                  ),
                  const SizedBox(height: 8),
                  _ThemeOptionTile(
                    icon: Icons.dark_mode_rounded,
                    label: S.themeDark,
                    selected: settings.themeMode == ThemeMode.dark,
                    isDark: isDark,
                    onTap: () =>
                        settings.setThemeMode(ThemeMode.dark),
                  ),
                  const SizedBox(height: 8),
                  _ThemeOptionTile(
                    icon: Icons.settings_suggest_rounded,
                    label: S.themeSystem,
                    selected: settings.themeMode == ThemeMode.system,
                    isDark: isDark,
                    onTap: () =>
                        settings.setThemeMode(ThemeMode.system),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Ukubwa wa Maandishi (Text Size) ──
            _SectionCard(
              icon: Icons.text_fields_rounded,
              title: S.textSize,
              subtitle: S.textSizeHint,
              isDark: isDark,
              child: Column(
                children: [
                  // Live preview
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkSurface
                          : AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppTheme.darkBorder
                            : AppTheme.border,
                      ),
                    ),
                    child: Text(
                      S.textPreview,
                      style: TextStyle(
                        fontSize: 16 * settings.textScale,
                        color: isDark
                            ? AppTheme.darkTextHi
                            : AppTheme.textDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _RoundIconButton(
                        icon: Icons.text_decrease_rounded,
                        isDark: isDark,
                        enabled: settings.textScale >
                            SettingsProvider.minScale + 0.001,
                        onTap: settings.decreaseTextSize,
                      ),
                      Expanded(
                        child: Slider(
                          value: settings.textScale,
                          min: SettingsProvider.minScale,
                          max: SettingsProvider.maxScale,
                          divisions: ((SettingsProvider.maxScale -
                                      SettingsProvider.minScale) /
                                  SettingsProvider.stepScale)
                              .round(),
                          activeColor: AppTheme.primary,
                          label:
                              '${(settings.textScale * 100).round()}%',
                          onChanged: (v) => settings.setTextScale(v),
                        ),
                      ),
                      _RoundIconButton(
                        icon: Icons.text_increase_rounded,
                        isDark: isDark,
                        enabled: settings.textScale <
                            SettingsProvider.maxScale - 0.001,
                        onTap: settings.increaseTextSize,
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      '${(settings.textScale * 100).round()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppTheme.darkTextMut
                            : AppTheme.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: settings.resetTextSize,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(S.resetTextSize),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final bool isDark;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark ? null : AppTheme.cardShadow,
        border: isDark
            ? Border.all(color: AppTheme.darkBorder)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppTheme.darkTextHi
                            : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark
                            ? AppTheme.darkTextMut
                            : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: isDark ? 0.25 : 0.1)
              : (isDark ? AppTheme.darkSurface : AppTheme.surface),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppTheme.primary
                : (isDark ? AppTheme.darkBorder : AppTheme.border),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected
                    ? AppTheme.primary
                    : (isDark
                        ? AppTheme.darkTextMut
                        : AppTheme.textMuted)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                  color: selected
                      ? AppTheme.primary
                      : (isDark
                          ? AppTheme.darkTextHi
                          : AppTheme.textDark),
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.primary),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final bool enabled;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.isDark,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.border,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled
              ? AppTheme.primary
              : (isDark ? AppTheme.darkBorder : AppTheme.border),
        ),
      ),
    );
  }
}
