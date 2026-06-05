import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/book_provider.dart';
import '../widgets/book_card.dart';
import 'book_detail_screen.dart';
import 'my_library_screen.dart';
import 'subscription_screen.dart';
import 'wallet_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Pakia vitabu pindi skrini inapofunguliwa
    Future.microtask(() {
      if (!mounted) return;
      context.read<BookProvider>().fetchBooks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookProv = context.watch<BookProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Maktaba"),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.card_membership),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyLibraryScreen())),
          ),
        ],
      ),
      body: bookProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : bookProv.books.isEmpty
              ? const Center(child: Text("Hakuna vitabu bado."))
              : ListView.builder(
                  itemCount: bookProv.books.length,
                  itemBuilder: (ctx, i) {
                    final book = bookProv.books[i];
                    return BookCard(
                      book: book,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookDetailScreen(bookId: book.id),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}