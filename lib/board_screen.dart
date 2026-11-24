import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'board_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final _controller = TextEditingController();
  final _boardService = BoardService();
  String _displayName = '';
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _loadDisplayName();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final isValid = _controller.text.trim().isNotEmpty;
    if (isValid != _isValid) {
      setState(() => _isValid = isValid);
    }
  }

  Future<void> _loadDisplayName() async {
    final user = AuthService().currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data == null) return;
    final firstName = data['firstName'] as String? ?? '';
    final lastName = data['lastName'] as String? ?? '';
    if (!mounted) return;
    setState(() {
      _displayName = '$firstName $lastName'.trim();
    });
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final user = AuthService().currentUser!;
    try {
      await _boardService.postMessage(
        authorUid: user.uid,
        authorName: _displayName,
        text: text,
      );
      _controller.clear();
    } on Exception catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not post message.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _boardService.messageBoard(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Could not load messages.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('No messages yet — be the first!'));
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) => _MessageTile(doc: docs[i], boardService: _boardService),
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
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'Write a message...'),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isValid ? _submit : null,
                  child: const Text('Post'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.doc, required this.boardService});
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final BoardService boardService;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final isMine = data['authorUid'] == AuthService().currentUser?.uid;
    final edited = data['editedAt'] != null;

    return ListTile(
      title: Text(data['text'] as String? ?? ''),
      subtitle: Text(
        '${data['authorName'] ?? 'Unknown'}'
        '${edited ? ' (edited)' : ''}',
      ),
      trailing: isMine
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editDialog(context, data['text'] as String? ?? ''),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _delete(context),
                ),
              ],
            )
          : null,
    );
  }

  Future<void> _editDialog(BuildContext context, String currentText) async {
    final controller = TextEditingController(text: currentText);
    final newText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newText == null || newText.isEmpty) return;
    await _runGuarded(context, () => boardService.editMessage(messageId: doc.id, newText: newText));
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runGuarded(context, () => boardService.deleteMessage(messageId: doc.id));
  }

  Future<void> _runGuarded(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can only edit/delete your own messages.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: ${e.message}')),
        );
      }
    }
  }
}