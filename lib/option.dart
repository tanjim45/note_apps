import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddEditNoteScreen extends StatefulWidget {
  final String? noteId;
  final String? title;
  final String? content;

  const AddEditNoteScreen({
    super.key,
    this.noteId,
    this.title,
    this.content,
  });

  @override
  State<AddEditNoteScreen> createState() => _AddEditNoteScreenState();
}

class _AddEditNoteScreenState extends State<AddEditNoteScreen> {
  late final TextEditingController titleController;
  late final TextEditingController contentController;

  bool isSaving = false;
  bool isPinned = false;
  int selectedColor = 0;

  final List<Color> noteColors = const [
    Color(0xFFFFF0C2),
    Color(0xFFDDF5E3),
    Color(0xFFE6E1FF),
    Color(0xFFFFE2E2),
    Color(0xFFDDF1FF),
    Color(0xFFF5E4F4),
  ];

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(
      text: widget.title ?? '',
    );
    contentController = TextEditingController(
      text: widget.content ?? '',
    );

    _loadExistingNote();
  }

  Future<void> _loadExistingNote() async {
    if (widget.noteId == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notes')
          .doc(widget.noteId)
          .get();

      if (!doc.exists || !mounted) return;

      final data = doc.data()!;

      setState(() {
        isPinned = data['isPinned'] == true;

        final savedColor = data['colorIndex'];
        if (savedColor is int &&
            savedColor >= 0 &&
            savedColor < noteColors.length) {
          selectedColor = savedColor;
        }
      });
    } catch (e) {
      debugPrint('Could not load note settings: $e');
    }
  }

  Future<void> saveNote() async {
    final title = titleController.text.trim();
    final content = contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write a title or note content.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first.')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final notesRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notes');

      if (widget.noteId == null) {
        await notesRef.add({
          'title': title,
          'content': content,
          'isPinned': isPinned,
          'colorIndex': selectedColor,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await notesRef.doc(widget.noteId).update({
          'title': title,
          'content': content,
          'isPinned': isPinned,
          'colorIndex': selectedColor,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note saved successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save note: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark
    ? theme.colorScheme.surface
    : Color.lerp(
        noteColors[selectedColor],
        Colors.white,
        0.25,
      )!;
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.noteId == null ? 'Create Note' : 'Edit Note',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: isPinned ? 'Unpin note' : 'Pin note',
            onPressed: () {
              setState(() => isPinned = !isPinned);
            },
            icon: Icon(
              isPinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
              color: isPinned ? theme.colorScheme.primary : null,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.colorScheme.surfaceContainerHigh
                          : Colors.white.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPinned
                              ? Icons.push_pin_rounded
                              : Icons.edit_note_rounded,
                          size: 17,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          isPinned ? 'PINNED NOTE' : 'YOUR THOUGHTS',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: titleController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 120,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                    
                              decoration: InputDecoration(
                                hintText: 'Give your note a title...',
                                hintStyle: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                                counterText: '',
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),

                  ),

                  Divider(
                    color: theme.colorScheme.outlineVariant,
                  ),

                  const SizedBox(height: 10),

                  Expanded(
                    child: TextField(
                      controller: contentController,
                      expands: true,
                      minLines: null,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.7,
                      ),
                      decoration: const InputDecoration(
                        hintText:
                            'Start writing your thoughts here...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'NOTE COLOR',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: List.generate(
                      noteColors.length,
                      (index) {
                        final selected = selectedColor == index;

                        return InkWell(
                          onTap: () {
                            setState(() => selectedColor = index);
                          },
                          customBorder: const CircleBorder(),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: noteColors[index],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? theme.colorScheme.primary
                                    : Colors.black12,
                                width: selected ? 3 : 1,
                              ),
                            ),
                            child: selected
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Color(0xFF353047),
                                    size: 20,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 22),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: isSaving ? null : saveNote,
                      icon: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_done_rounded),
                      label: Text(
                        isSaving ? 'Saving...' : 'Save Note',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
