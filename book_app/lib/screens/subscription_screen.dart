import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/language_toggle.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  int? _subscribing;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<SubscriptionProvider>().fetchPlans();
    });
  }

  void _subscribe(int planId) async {
    setState(() => _subscribing = planId);
    try {
      await context.read<SubscriptionProvider>().subscribe(planId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white),
          const SizedBox(width: 8),
          Text(S.subSuccess),
        ]),
        backgroundColor: AppTheme.success,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppTheme.danger,
      ));
    } finally {
      if (mounted) setState(() => _subscribing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); // rebuild on lang change
    final prov = context.watch<SubscriptionProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(S.subPlans),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
        actions: const [LanguageDropdown(), SizedBox(width: 8)],
      ),
      body: prov.isLoading
          ? const Center(child: CircularProgressIndicator())
          : prov.plans.isEmpty
              ? _emptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _headerBanner(),
                      const SizedBox(height: 24),
                      ...List.generate(prov.plans.length,
                        (i) => _planCard(prov.plans[i], i)),
                      const SizedBox(height: 20),
                      _benefitsSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _headerBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S.readUnlimited,
                  style: const TextStyle(color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(S.choosePlan,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 48),
        ],
      ),
    );
  }

  Widget _planCard(dynamic plan, int index) {
    final planId     = plan['id'] as int;
    final level      = (plan['level'] as int?) ?? 0;
    final isFree     = level == 0;
    final price      = double.tryParse('${plan['price']}') ?? 0;
    // Plan iliyo "maarufu" ni ile yenye level ya kati (Pro), siyo Free.
    final isPopular  = level == 2;
    final isLoading  = _subscribing == planId;
    final features   = (plan['features'] as List?)?.cast<dynamic>() ?? [];
    final colors     = [
      [const Color(0xFF94A3B8), const Color(0xFFCBD5E1)], // Free - kijivu
      [const Color(0xFF6366F1), const Color(0xFF818CF8)], // Basic
      [const Color(0xFF7C3AED), const Color(0xFFA78BFA)], // Pro
      [const Color(0xFF0EA5E9), const Color(0xFF38BDF8)], // Premium
    ];
    final colorPair = level < colors.length ? colors[level] : colors[1];
    final gradient = LinearGradient(
      colors: colorPair,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.card(context),
              borderRadius: BorderRadius.circular(20),
              border: isPopular
                  ? Border.all(color: AppTheme.primary, width: 2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          gradient: gradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          isFree
                              ? Icons.card_giftcard_rounded
                              : Icons.star_rounded,
                          color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_planName(plan['name']?.toString() ?? ''),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16,
                                  color: AppTheme.textPrimary(context))),
                            const SizedBox(height: 4),
                            isFree || price == 0
                                ? Text(S.free,
                                    style: const TextStyle(
                                        fontSize: 20, fontWeight: FontWeight.bold,
                                        color: AppTheme.primary))
                                : RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: 'TZS ${plan['price']}',
                                          style: const TextStyle(
                                            fontSize: 20, fontWeight: FontWeight.bold,
                                            color: AppTheme.primary)),
                                        TextSpan(
                                          text: ' / ${S.perDays} ${plan['duration_days']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary(context))),
                                      ],
                                    ),
                                  ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 90,
                        height: 38,
                        child: isLoading
                            ? const Center(child: SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)))
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  backgroundColor: isFree
                                      ? AppTheme.textSecondary(context)
                                      : null,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => _subscribe(planId),
                                child: Text(S.choose,
                                    style: const TextStyle(fontSize: 12)),
                              ),
                      ),
                    ],
                  ),
                  if (features.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    ...features.map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  size: 16, color: colorPair[0]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_featureText(f),
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        color: AppTheme.textPrimary(context))),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ),
          if (isFree)
            Positioned(
              top: -1, left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(10)),
                ),
                child: Text(S.freePlanBadge,
                  style: const TextStyle(color: Colors.white, fontSize: 10,
                      fontWeight: FontWeight.bold)),
              ),
            ),
          if (isPopular)
            Positioned(
              top: -1, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(10)),
                ),
                child: Text(S.popular,
                  style: const TextStyle(color: Colors.white, fontSize: 10,
                      fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _benefitsSection() {
    final benefits = [
      [Icons.all_inclusive_rounded,
        S.benefitAllBooks, S.benefitAllBooksDesc],
      [Icons.offline_bolt_rounded,
        S.benefitOffline, S.benefitOfflineDesc],
      [Icons.cancel_rounded,
        S.benefitCancel, S.benefitCancelDesc],
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.whatYouGet,
            style: TextStyle(fontWeight: FontWeight.bold,
                fontSize: 15, color: AppTheme.textPrimary(context))),
          const SizedBox(height: 14),
          ...benefits.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(b[0] as IconData,
                      color: AppTheme.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b[1] as String,
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13,
                          color: AppTheme.textPrimary(context))),
                    Text(b[2] as String,
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary(context))),
                  ],
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  /// Tafsiri jina la mpango kulingana na lugha ya sasa.
  String _planName(String name) {
    if (name == 'Free') return S.free;
    return name;
  }

  /// Onyesha faida ya mpango kulingana na lugha ya sasa.
  /// Inakubali "string" za zamani na "map" mpya {sw:..., en:...}.
  String _featureText(dynamic f) {
    if (f is Map) {
      return (S.isSwahili ? f['sw'] : f['en'])?.toString() ?? '$f';
    }
    return '$f';
  }

  Widget _emptyState() {
    return Center(
      child: Text(S.noPlans,
          style: TextStyle(color: AppTheme.textSecondary(context))));
  }
}
