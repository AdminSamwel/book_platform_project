import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CommentsScreen extends StatefulWidget {
  final int bookId;
  const CommentsScreen({super.key, required this.bookId});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _comments = [];
  final _textCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final data = await _api.fetchComments(widget.bookId);
      setState(() {
        _comments = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _postComment() async {
    if (_textCtrl.text.trim().isEmpty) return;
    try {
      await _api.postComment(widget.bookId, _textCtrl.text.trim());
      _textCtrl.clear();
      _loadComments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Hitilafu: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Maoni")),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(child: Text("Hakuna maoni bado."))
                    : ListView.builder(
                        itemCount: _comments.length,
                        itemBuilder: (ctx, i) {
                          final comment = _comments[i];
                          return ListTile(
                            title: Text(comment['text'] ?? ''),
                            subtitle: Text(
                                "Na: ${comment['username']} - ${comment['created_at'].toString().substring(0, 10)}"),
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    decoration:
                        const InputDecoration(hintText: 'Andika maoni yako...'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _postComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
