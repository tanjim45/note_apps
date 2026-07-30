import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddEditNoteScreen extends StatefulWidget {
  final String? noteId;
  final String? title;
  final String? content;

  const AddEditNoteScreen({super.key, this.noteId, this.title, this.content});

  @override
  State<AddEditNoteScreen> createState() => _AddEditNoteScreenState();
}

class _AddEditNoteScreenState extends State<AddEditNoteScreen> {
  late TextEditingController titleController;
  late TextEditingController contentController;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.title ?? '');
    contentController = TextEditingController(text: widget.content ?? '');
  }

  Future<void> saveNote() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final notesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notes');

    if (widget.noteId == null) {
      // Add Note
      await notesRef.add({
        'title': titleController.text.trim(),
        'content': contentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Edit Note
      await notesRef.doc(widget.noteId).update({
        'title': titleController.text.trim(),
        'content': contentController.text.trim(),
      });
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.noteId == null ? 'Add Note' : 'Edit Note'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: contentController,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Content'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: saveNote, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}