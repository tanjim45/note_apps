import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:noteapp/login.dart';
import 'package:noteapp/option.dart';
import 'package:noteapp/theme_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  String _searchQuery = '';
  bool _showPinnedOnly = false;

  final List<Color> _noteColors = const [
    Color(0xFFFFF0C2),
    Color(0xFFDDF5E3),
    Color(0xFFE6E1FF),
    Color(0xFFFFE2E2),
    Color(0xFFDDF1FF),
    Color(0xFFF5E4F4),
  ];

  CollectionReference<Map<String, dynamic>> get _notesCollection {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notes');
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  Future<void> _deleteNote(String noteId) async {
    try {
      await _notesCollection.doc(noteId).delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note deleted successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete note. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _togglePin(
    String noteId,
    bool currentPinStatus,
  ) async {
    try {
      await _notesCollection.doc(noteId).update({
        'isPinned': !currentPinStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentPinStatus
                ? 'Note unpinned'
                : 'Note pinned to the top',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update pin status'),
        ),
      );
    }
  }

  void _openEditor({
    String? noteId,
    String? title,
    String? content,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditNoteScreen(
          noteId: noteId,
          title: title,
          content: content,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String noteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: const Text('Delete this note?'),
        content: const Text(
          'This note will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteNote(noteId);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please login to view your notes.'),
        ),
      );
    }

    final displayName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : (user.email?.split('@').first ?? 'User');

    final firstName = displayName.split(' ').first;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.sticky_note_2_rounded,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'NoteSpace',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
          ],
        ),
        actions: [
        
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeController.mode,
                builder: (context, currentMode, child) {
                  final isDark = currentMode == ThemeMode.dark;

                  return IconButton(
                    tooltip: isDark ? 'Light Mode' : 'Dark Mode',
                    onPressed: () {
                      ThemeController.toggle();
                    },
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: 'Logout',
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded),
              ),
              const SizedBox(width: 8),
            ],

      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _notesCollection.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load notes: ${snapshot.error}'),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final allNotes = snapshot.data!.docs.toList();

            // Pinned notes first; remaining notes sorted by creation date.
            allNotes.sort((a, b) {
              final aPinned = a.data()['isPinned'] == true;
              final bPinned = b.data()['isPinned'] == true;

              if (aPinned != bPinned) {
                return aPinned ? -1 : 1;
              }

              final aTime = a.data()['createdAt'];
              final bTime = b.data()['createdAt'];

              final aDate = aTime is Timestamp
                  ? aTime.toDate()
                  : DateTime.fromMillisecondsSinceEpoch(0);

              final bDate = bTime is Timestamp
                  ? bTime.toDate()
                  : DateTime.fromMillisecondsSinceEpoch(0);

              return bDate.compareTo(aDate);
            });

            final filteredNotes = allNotes.where((note) {
              final data = note.data();

              final title = (data['title'] ?? '')
                  .toString()
                  .toLowerCase();

              final content = (data['content'] ?? '')
                  .toString()
                  .toLowerCase();

              final matchesSearch =
                  title.contains(_searchQuery) ||
                  content.contains(_searchQuery);

              final isPinned = data['isPinned'] == true;

              return matchesSearch &&
                  (!_showPinnedOnly || isPinned);
            }).toList();

            final pinnedCount = allNotes.where(
              (note) => note.data()['isPinned'] == true,
            ).length;

            final width = MediaQuery.sizeOf(context).width;
            final columns = width >= 1100
                ? 4
                : width >= 700
                    ? 3
                    : width >= 440
                        ? 2
                        : 1;

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR PERSONAL SPACE',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Hello, $firstName 👋',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Capture your thoughts, one note at a time.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),

                        TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.trim().toLowerCase();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search your notes...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  )
                                : null,
                            filled: true,
                            fillColor:
                                theme.colorScheme.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'My Notes',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              '${allNotes.length} notes',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              selected: !_showPinnedOnly,
                              avatar: const Icon(
                                Icons.grid_view_rounded,
                                size: 18,
                              ),
                              label: const Text('All Notes'),
                              onSelected: (_) {
                                setState(() => _showPinnedOnly = false);
                              },
                            ),
                            FilterChip(
                              selected: _showPinnedOnly,
                              avatar: const Icon(
                                Icons.push_pin_rounded,
                                size: 18,
                              ),
                              label: Text('Pinned ($pinnedCount)'),
                              onSelected: (_) {
                                setState(() => _showPinnedOnly = true);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                if (filteredNotes.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty
                                  ? Icons.search_off_rounded
                                  : Icons.note_add_rounded,
                              size: 64,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _showPinnedOnly
                                  ? 'No pinned notes yet'
                                  : _searchQuery.isNotEmpty
                                      ? 'No matching notes'
                                      : 'Your space is waiting!',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Create a note to get started.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                    sliver: SliverGrid(
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        mainAxisExtent: 215,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final note = filteredNotes[index];
                          final data = note.data();

                          final title = (data['title'] ?? '').toString();
                          final content =
                              (data['content'] ?? '').toString();

                          final rawColorIndex = data['colorIndex'];
                          final colorIndex = rawColorIndex is int &&
                                  rawColorIndex >= 0 &&
                                  rawColorIndex < _noteColors.length
                              ? rawColorIndex
                              : note.id.hashCode.abs() % _noteColors.length;

                          final pinned = data['isPinned'] == true;

                          return _NoteCard(
                            title: title,
                            content: content,
                            color: _noteColors[colorIndex],
                            isPinned: pinned,
                            onTap: () => _openEditor(
                              noteId: note.id,
                              title: title,
                              content: content,
                            ),
                            onPin: () => _togglePin(note.id, pinned),
                            onDelete: () => _confirmDelete(note.id),
                          );
                        },
                        childCount: filteredNotes.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New Note',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final String title;
  final String content;
  final Color color;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.title,
    required this.content,
    required this.color,
    required this.isPinned,
    required this.onTap,
    required this.onPin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardColor = isDark
        ? Color.lerp(
            theme.colorScheme.surfaceContainerHigh,
            color,
            0.18,
          )!
        : color;

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 35,
                    width: 35,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      size: 19,
                      color: Color(0xFF44445A),
                    ),
                  ),
                  const Spacer(),
                  if (isPinned)
                    const Padding(
                      padding: EdgeInsets.only(right: 2),
                      child: Icon(
                        Icons.push_pin_rounded,
                        size: 17,
                        color: Color(0xFF6750A4),
                      ),
                    ),
                  IconButton(
                    tooltip: isPinned ? 'Unpin note' : 'Pin note',
                    visualDensity: VisualDensity.compact,
                    onPressed: onPin,
                    icon: Icon(
                      isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      size: 20,
                      color: const Color(0xFF514B62),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete note',
                    visualDensity: VisualDensity.compact,
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: Color(0xFF6A5B60),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title.isEmpty ? 'Untitled Note' : title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  color: isDark
                      ? theme.colorScheme.onSurface
                      : const Color(0xFF25243A),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  content.isEmpty ? 'No content yet...' : content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.5,
                    color: isDark
                        ? theme.colorScheme.onSurfaceVariant
                        : const Color(0xFF555366),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    size: 15,
                    color: isDark
                        ? theme.colorScheme.onSurfaceVariant
                        : const Color(0xFF666176),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Tap to edit',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark
                          ? theme.colorScheme.onSurfaceVariant
                          : const Color(0xFF666176),
                    ),
                  ),
                  const Spacer(),
                  if (isPinned)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Text(
                        'PINNED',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: Color(0xFF6750A4),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
