import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../theme/app_theme.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white),
          SizedBox(width: 8),
          Text('Umefanikiwa kujisajili!'),
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
    final prov = context.watch<SubscriptionProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mipango ya Usajili'),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
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
                const Text('Soma bila Mipaka',
                  style: TextStyle(color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Chagua mpango unaokufaa na ufurahie vitabu vyote',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85),
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
    final isPopular  = index == 1;
    final isLoading  = _subscribing == planId;
    final colors     = [
      [const Color(0xFF6366F1), const Color(0xFF818CF8)],
      [const Color(0xFF7C3AED), const Color(0xFFA78BFA)],
      [const Color(0xFF0EA5E9), const Color(0xFF38BDF8)],
    ];
    final gradient = LinearGradient(
      colors: index < colors.length ? colors[index] : colors[0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
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
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.star_rounded,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 16),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plan['name'],
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16,
                              color: AppTheme.textDark)),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'TZS ${plan['price']}',
                                style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold,
                                  color: AppTheme.primary)),
                              TextSpan(
                                text: ' / siku ${plan['duration_days']}',
                                style: const TextStyle(
                                  fontSize: 12, color: AppTheme.textMuted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Button
                  SizedBox(
                    width: 90,
                    height: 38,
                    child: isLoading
                        ? const Center(child: SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)))
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _subscribe(planId),
                            child: const Text('Chagua',
                                style: TextStyle(fontSize: 12)),
                          ),
                  ),
                ],
              ),
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
                child: const Text('MAARUFU',
                  style: TextStyle(color: Colors.white, fontSize: 10,
                      fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _benefitsSection() {
    final benefits = [
      [Icons.all_inclusive_rounded, 'Vitabu Vyote', 'Soma vitabu yote bila kikwazo'],
      [Icons.offline_bolt_rounded, 'Soma Offline', 'Pakua na soma bila internet'],
      [Icons.cancel_rounded, 'Futa Wakati Wowote', 'Hakuna mkataba wa lazima'],
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Unachopata',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15,
                color: AppTheme.textDark)),
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
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13,
                          color: AppTheme.textDark)),
                    Text(b[2] as String,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Text('Hakuna mipango bado.',
          style: TextStyle(color: AppTheme.textMuted)));
  }
}
