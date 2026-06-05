import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<WalletProvider>().fetchWallet();
    });
  }

  void _showTopUpDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Weka Pesa Mkononi'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Kiasi (TZS)',
            prefixIcon: Icon(Icons.attach_money),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ghairi')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(ctrl.text.trim());
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingiza kiasi sahihi')));
                return;
              }
              Navigator.pop(context);
              try {
                await context.read<WalletProvider>().topUp(amount);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('TZS ${amount.toStringAsFixed(0)} imeongezwa!')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
                }
              }
            },
            child: const Text('Weka'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<WalletProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mkoba Wangu'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: prov.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => context.read<WalletProvider>().fetchWallet(),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      color: Colors.indigo,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Text('Salio Lako', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            const SizedBox(height: 8),
                            Text(
                              'TZS ${prov.balance.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Weka Pesa'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.indigo,
                              ),
                              onPressed: _showTopUpDialog,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Historia ya Shughuli',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: prov.transactions.isEmpty
                          ? const Center(child: Text('Hakuna shughuli bado.'))
                          : ListView.separated(
                              itemCount: prov.transactions.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final txn = prov.transactions[i];
                                final isCredit = txn['transaction_type'] == 'credit';
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isCredit ? Colors.green.shade100 : Colors.red.shade100,
                                    child: Icon(
                                      isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                                      color: isCredit ? Colors.green : Colors.red,
                                    ),
                                  ),
                                  title: Text(txn['description'] ?? ''),
                                  subtitle: Text(txn['created_at'].toString().substring(0, 10)),
                                  trailing: Text(
                                    '${isCredit ? '+' : '-'} TZS ${txn['amount']}',
                                    style: TextStyle(
                                      color: isCredit ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
