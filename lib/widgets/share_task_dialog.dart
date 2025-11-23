// lib/widgets/share_task_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/task_service.dart';

class ShareTaskDialog extends StatefulWidget {
  final String taskId;
  const ShareTaskDialog({Key? key, required this.taskId}) : super(key: key);

  @override
  State<ShareTaskDialog> createState() => _ShareTaskDialogState();
}

class _ShareTaskDialogState extends State<ShareTaskDialog> {
  final _email = TextEditingController();
  String _role = 'editor';
  bool _loading = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _message = 'Enter an email');
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    final svc = context.read<TaskService>();
    final ok = await svc.shareTask(widget.taskId, email: email, role: _role);

    setState(() => _loading = false);
    if (ok) {
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() => _message = 'Failed to share — check email/permissions');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0C0C0C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(
            children: [
              const Expanded(child: Text('Share Task', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
              IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Collaborator email',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF151516),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.email_outlined, color: Colors.white54),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            const Text('Role:', style: TextStyle(color: Colors.white70)),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: _role,
              dropdownColor: const Color(0xFF121212),
              items: const [
                DropdownMenuItem(value: 'editor', child: Text('Editor')),
                DropdownMenuItem(value: 'commenter', child: Text('Commenter')),
                DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'editor'),
            )
          ]),
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(_message!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading ? null : _share,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                  child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Share'),
                ),
              )
            ],
          ),
        ]),
      ),
    );
  }
}
