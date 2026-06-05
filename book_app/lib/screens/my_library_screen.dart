import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/book_provider.dart';
import '../widgets/book_card.dart';
import 'reader_screen.dart';

class MyLibraryScreen extends StatefulWidget {
  const MyLibraryScreen({super.key});

  @override
  State<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _MyLibraryScreenState extends State<MyLibraryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<BookProvider>().fetchMyLibrary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<BookProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text("Maktaba Yangu")),
      body: prov.isLoading
          ? const Center(child: CircularProgressIndicator())
          : prov.myLibrary.isEmpty
              ? const Center(child: Text("Huna vitabu bado."))
              : ListView.builder(
                  itemCount: prov.myLibrary.length,
                  itemBuilder: (ctx, i) {
                    final book = prov.myLibrary[i];
                    return BookCard(
                      book: book,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ReaderScreen(bookId: book.id)),
                      ),
                    );
                  },
                ),
    );
  }
}
