import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/book_provider.dart';
import 'reader_screen.dart';
import 'comments_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final int bookId;
  const BookDetailScreen({super.key, required this.bookId});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  Map<String, dynamic>? _detail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final data =
          await context.read<BookProvider>().fetchBookDetail(widget.bookId);
      setState(() {
        _detail = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Hitilafu: $e")));
    }
  }

  void _purchase() async {
    try {
      await context.read<BookProvider>().purchaseBook(widget.bookId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Umefanikiwa kununua!")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
          appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    if (_detail == null) {
      return Scaffold(
          appBar: AppBar(), body: const Center(child: Text("Hakuna maelezo.")));
    }

    final isFree = _detail!['is_free'] ?? false;
    final price = _detail!['price'] ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(_detail!['title'] ?? 'Kitabu')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_detail!['cover_image'] != null)
              Center(
                  child: Image.network(_detail!['cover_image'], height: 200)),
            const SizedBox(height: 12),
            Text(_detail!['title'] ?? '',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Na: ${_detail!['author_name'] ?? 'Mwandishi'}"),
            const SizedBox(height: 12),
            Text(isFree ? 'Bure' : 'Bei: TZS $price',
                style: const TextStyle(fontSize: 18, color: Colors.green)),
            const SizedBox(height: 20),
            Text(_detail!['description'] ?? 'Hakuna maelezo.',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 30),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.book),
                  label: const Text("Soma Sasa"),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ReaderScreen(bookId: widget.bookId)),
                  ),
                ),
                const SizedBox(width: 12),
                if (!isFree)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.shopping_cart),
                    label: const Text("Nunua"),
                    onPressed: _purchase,
                  ),
              ],
            ),
            TextButton.icon(
              icon: const Icon(Icons.comment),
              label: const Text("Maoni"),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CommentsScreen(bookId: widget.bookId)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
