// lib/screens/notes_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/voice_service.dart';
import '../services/note_service.dart';
import '../services/auth_service.dart';
import '../widgets/add_note_sheet.dart';
import '../widgets/listening_overlay.dart';
import '../widgets/note_card.dart';
import 'package:flutter/cupertino.dart';
class NotesScreen extends StatefulWidget {
  const NotesScreen({Key? key}) : super(key: key);

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> with SingleTickerProviderStateMixin {
  late final TextEditingController _searchC;
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _searchC = TextEditingController();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    // fetch initial notes when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final svc = context.read<NoteService>();
      svc.fetchNotes();
    });
  }
  Future<void> _startVoiceNote() async {
    final voice = context.read<VoiceService>();
    final noteSvc = context.read<NoteService>();

    if (!voice.available) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone not available')));
      return;
    }

    // open overlay and run capture in parallel. The overlay will allow user to Stop/Cancel.
    // We will call captureNoteInteractive but ensure the overlay controls stop when user requests cancel.
    final overlayResultFuture = showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ListeningOverlay(titleText: 'Record note'),
    );

    // start capture (this will call listenOnce internally)
    final captureFuture = voice.captureNoteInteractive(
      speakPrompts: true,
      onPrompt: (p) {
        debugPrint('[NotesScreen] voice prompt: $p');
        // optionally show toast or small UI here
      },
    );

    // Wait for either overlay to be closed by user (Stop/Cancel) OR capture finishes.
    // If overlay closed first (user cancelled), stopCurrentListen() will be called and captureFuture will resolve.
    final captureResult = await captureFuture; // returns {title, description}

    // overlayResultFuture resolves with true (Stop) or false (Cancel) or null (unexpected)
    final overlayResult = await overlayResultFuture;

    // Ensure overlay is closed if still open
    try {
      if (Navigator.of(context, rootNavigator: true).canPop()) Navigator.of(context, rootNavigator: true).pop();
    } catch (_) {}

    // Now decide what to do
    final title = (captureResult['title'] ?? '').trim();
    final description = (captureResult['description'] ?? '').trim();

    if (overlayResult == false) {
      // user explicitly cancelled via overlay -> don't save
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note cancelled')));
      return;
    }

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No title captured — note cancelled')));
      return;
    }

    // Save note (allow empty description)
    try {
      await noteSvc.createNote(title: title, content: description);
      await noteSvc.fetchNotes();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note saved')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  @override
  void dispose() {
    _searchC.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _openAddSheet({Map<String, dynamic>? note}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddNoteSheet(existingNote: note),
    ).then((r) {
      if (r == true) {
        // refresh handled inside NoteService after create/update, but re-fetch for safety
        context.read<NoteService>().fetchNotes();
      }
    });
  }

  int _columnsForWidth(double width) {
    // simple responsive breakpoints
    if (width >= 1100) return 4; // large tablets / desktops
    if (width >= 800) return 3;  // tablets / landscape
    return 2;                    // phones
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<NoteService>();
    final auth = context.watch<AuthService>();
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = _columnsForWidth(screenWidth);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: AnimatedIcon(
              icon: AnimatedIcons.search_ellipsis,
              progress: _animCtrl,
              color: Colors.white70,
            ),
            onPressed: () {
              if (_searchC.text.isEmpty) {
                _animCtrl.forward();
                FocusScope.of(context).requestFocus(FocusNode());
              } else {
                _searchC.clear();
                svc.setSearch('');
                _animCtrl.reverse();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.mic, color: Colors.white),
            onPressed: _startVoiceNote,
          ),

          IconButton(
            icon: Icon(svc.onlyPinned ? Icons.push_pin : Icons.push_pin_outlined, color: svc.onlyPinned ? Colors.amberAccent : Colors.white70),
            onPressed: () {
              svc.togglePinnedFilter();
            },
          ),
          PopupMenuButton<String>(
            color: const Color(0xFF121212),
            onSelected: (v) {
              if (v == 'logout') {
                auth.logout();
              } else if (v == 'refresh') {
                svc.fetchNotes();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'refresh', child: Text('Refresh')),
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          )
        ],
        bottom: PreferredSize(
          preferredSize: _animCtrl.value > 0 ? const Size.fromHeight(56) : const Size.fromHeight(0),
          child: SizeTransition(
            sizeFactor: CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
            axisAlignment: -1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
              child: _buildSearchField(svc),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => svc.fetchNotes(),
          color: Colors.white,
          backgroundColor: const Color(0xFF0F0F10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12),
            child: Column(
              children: [
                // Quick header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Your notes', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 6),
                          Text('${svc.filtered.length} notes', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.filter_list, color: Colors.white70),
                      onPressed: () {
                        // optional: show filter modal
                      },
                    )
                  ],
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: Builder(builder: (_) {
                    if (svc.loading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final list = svc.filtered;
                    if (list.isEmpty) {
                      return _emptyState();
                    }

                    // Responsive grid
                    return GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: list.length,
                      itemBuilder: (_, idx) {
                        final note = list[idx];
                        return GestureDetector(
                          onTap: () => _openAddSheet(note: note), // edit
                          child: NoteCard(note: note),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(),
        label: const Text('New Note'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.note_alt_outlined, size: 64, color: Colors.white12),
          const SizedBox(height: 12),
          const Text('No notes yet', style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 6),
          const Text('Tap the + button to create your first note', style: TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSearchField(NoteService svc) {
    return TextField(
      controller: _searchC,
      onChanged: (v) => svc.setSearch(v),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search notes, tags or content',
        hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF121212),
        prefixIcon: const Icon(Icons.search, color: Colors.white54),
        suffixIcon: _searchC.text.isNotEmpty
            ? IconButton(
          icon: const Icon(Icons.clear, color: Colors.white54),
          onPressed: () {
            _searchC.clear();
            svc.setSearch('');
          },
        )
            : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
