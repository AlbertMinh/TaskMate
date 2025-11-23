// lib/widgets/collaborators_list.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/task_service.dart';

class CollaboratorsList extends StatefulWidget {
  final String taskId;
  final bool isOwner;
  const CollaboratorsList({Key? key, required this.taskId, required this.isOwner}) : super(key: key);

  @override
  State<CollaboratorsList> createState() => _CollaboratorsListState();
}

class _CollaboratorsListState extends State<CollaboratorsList> {
  List<dynamic> _collabs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final svc = context.read<TaskService>();
      final list = await svc.listCollaborators(widget.taskId);
      if (mounted) {
        setState(() {
        _collabs = list ?? [];
        _loading = false;
      });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
        _collabs = [];
        _loading = false;
        _error = e.toString();
      });
      }
    }
  }

  Future<void> _remove(String collabId) async {
    final svc = context.read<TaskService>();
    final ok = await svc.removeCollaborator(widget.taskId, collabId);
    if (ok) {
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed collaborator')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to remove')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text('Error loading collaborators: $_error', style: const TextStyle(color: Colors.white70)));
    }
    if (_collabs.isEmpty) return const Center(child: Text('No collaborators', style: TextStyle(color: Colors.white70)));

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _collabs.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white10),
      itemBuilder: (ctx, idx) {
        final c = _collabs[idx];

        // Support both shapes:
        // A) normalized collaborator: { id, username, email, role, collabId, addedAt }
        // B) older shape: { userId: { _id, username, email }, role, _id }
        String? username;
        String? email;
        String role;
        String? collabId;

        // Try direct fields first (normalized shape)
        if (c is Map && c['username'] != null) {
          username = (c['username'] as dynamic).toString();
          email = c['email']?.toString();
          role = (c['role'] ?? 'editor').toString();
          collabId = c['collabId']?.toString() ?? c['_id']?.toString() ?? c['id']?.toString();
        } else {
          // Fallback to userId object shape
          final userObj = (c is Map) ? (c['userId'] ?? {}) : {};
          if (userObj is Map) {
            username = (userObj['username'] != null) ? userObj['username'].toString() : null;
            email = (userObj['email'] != null) ? userObj['email'].toString() : null;
          } else if (userObj is String) {
            // sometimes userId may be just an id string; username unknown
            username = null;
            email = null;
          }
          role = (c is Map && c['role'] != null) ? c['role'].toString() : 'editor';
          collabId = (c is Map) ? (c['_id']?.toString() ?? c['id']?.toString()) : null;
        }

        // Derive display name preferring username -> email -> Unknown
        final displayName = (username != null && username.trim().isNotEmpty)
            ? username
            : (email != null && email.trim().isNotEmpty)
            ? email
            : 'Unknown';

        // Safe initial for avatar
        String avatarLetter = 'U';
        try {
          if (displayName.isNotEmpty) {
            avatarLetter = displayName.trim()[0].toUpperCase();
            if (avatarLetter == '@' && displayName.length > 1) avatarLetter = displayName.trim()[1].toUpperCase();
          }
        } catch (_) {
          avatarLetter = 'U';
        }

        final roleLabel = role[0].toUpperCase() + (role.length > 1 ? role.substring(1) : '');

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: CircleAvatar(
            child: Text(avatarLetter, style: const TextStyle(fontWeight: FontWeight.w700)),
            backgroundColor: Colors.white12,
            foregroundColor: Colors.white,
          ),
          title: Text(displayName, style: const TextStyle(color: Colors.white)),
          subtitle: Text(roleLabel, style: const TextStyle(color: Colors.white70)),
          trailing: widget.isOwner
              ? IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
            onPressed: () {
              if (collabId == null || collabId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot remove: missing id')));
                return;
              }
              _confirmRemove(collabId);
            },
          )
              : null,
        );
      },
    );
  }

  void _confirmRemove(String collabId) {
    showDialog(context: context, builder: (_) {
      return AlertDialog(
        backgroundColor: const Color(0xFF0C0C0C),
        title: const Text('Remove collaborator', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to remove this collaborator?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () { Navigator.pop(context); _remove(collabId); }, child: const Text('Remove', style: TextStyle(color: Colors.redAccent))),
        ],
      );
    });
  }
}
