import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TaskCard extends StatelessWidget {
  final Map task;
  final bool compact;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleStatus; // toggle between completed / not started / active

  const TaskCard({
    Key? key,
    required this.task,
    this.compact = false,
    this.onEdit,
    this.onDelete,
    this.onToggleStatus,
  }) : super(key: key);

  Color _statusColor(String s) {
    final k = s.toLowerCase();
    if (k == 'completed') return Colors.green;
    if (k == 'active') return Colors.orange.shade600;
    // 'not started' or unknown
    return Colors.grey;
  }

  String _statusLabel(String s) {
    // Make label: NOT STARTED, ACTIVE, COMPLETED
    return s.toUpperCase();
  }

  DateTime _parseDate(String? raw) {
    if (raw == null) return DateTime.now();
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (task['title'] ?? 'Untitled').toString();
    final desc = (task['description'] ?? '').toString();

    // status may be "not started" | "active" | "completed"
    final status = (task['status'] ?? 'not started').toString();

    // Prefer endDate (deadline) -> startDate -> date -> now
    final endRaw = task['endDate'] ?? task['deadline'];
    final startRaw = task['startDate'] ?? task['date'];
    final date = endRaw != null ? _parseDate(endRaw.toString()) : _parseDate(startRaw?.toString());

    return Card(
      color: Color(0xFF131313),
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 14),
        child: Row(
          children: [
            // status bar
            Container(
              width: 8,
              height: 48,
              decoration: BoxDecoration(
                color: _statusColor(status),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            SizedBox(width: 12),
            // content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  if (!compact) SizedBox(height: 6),
                  if (!compact)
                    Text(desc, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                  SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          DateFormat('EEE, MMM d • h:mm a').format(date),
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(_statusLabel(status.replaceAll('_', ' ')),
                          style: TextStyle(color: Colors.grey[300], fontSize: 12)),
                    ],
                  )
                ],
              ),
            ),
            SizedBox(width: 8),

            // popup menu
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'toggle') {
                  // let parent handle toggle; fallback: try to toggle locally via onToggleStatus
                  if (onToggleStatus != null) {
                    onToggleStatus!();
                  } else {
                    // no-op
                  }
                } else if (v == 'edit') {
                  if (onEdit != null) onEdit!();
                } else if (v == 'delete') {
                  if (onDelete != null) onDelete!();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'toggle', child: Text('Toggle Status')),
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
