import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<SubscriptionProvider>().fetchPlans();
    });
  }

  void _subscribe(int planId) async {
    try {
      await context.read<SubscriptionProvider>().subscribe(planId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Umefanikiwa kujisajili!")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<SubscriptionProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text("Mipango ya Usajili")),
      body: prov.isLoading
          ? const Center(child: CircularProgressIndicator())
          : prov.plans.isEmpty
              ? const Center(child: Text("Hakuna mipango bado."))
              : ListView.builder(
                  itemCount: prov.plans.length,
                  itemBuilder: (ctx, i) {
                    final plan = prov.plans[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(plan['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            "TZS ${plan['price']} / siku ${plan['duration_days']}"),
                        trailing: ElevatedButton(
                          onPressed: () => _subscribe(plan['id']),
                          child: const Text("Jisajili"),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
