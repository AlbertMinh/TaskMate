import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:intl/intl.dart';

import 'TaskDetailScreen.dart';

class TaskListItem extends StatefulWidget {
  final Map task;
  final bool compact;
  const TaskListItem({Key? key, required this.task, this.compact = false}) : super(key: key);

  @override
  State<TaskListItem> createState() => _TaskListItemState();
}

class _TaskListItemState extends State<TaskListItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final title = (task['title'] ?? 'Untitled').toString();
    final desc = (task['description'] ?? '').toString();
    final endDateRaw = task['endDate'];
    String endDateStr = '';
    if (endDateRaw != null) {
      try {
        endDateStr = DateFormat('dd MMM').format(DateTime.parse(endDateRaw));
      } catch (_) {
        endDateStr = endDateRaw.toString();
      }
    }

    final status = (task['status'] ?? 'not started').toString().toLowerCase();
    final statusColor = _statusColor(status);


    final avatarLetter = title.isNotEmpty ? title[0].toUpperCase() : 'T';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: EdgeInsets.only(bottom: widget.compact ? 10 : 14),
      transform: _pressed ? (Matrix4.identity()..scale(0.997)) : Matrix4.identity(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: () {
            setState(() => _pressed = false);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF151516),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 6)),
              ],
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                Container(
                  width: 8,
                  height: widget.compact ? 72 : 90,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),


                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: widget.compact ? 10 : 14),
                    child: Row(
                      children: [
                        // avatar
                        Container(
                          width: widget.compact ? 10.w : 12.w,
                          height: widget.compact ? 10.w : 12.w,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              avatarLetter,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: widget.compact ? 16.sp : 16.sp,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 3.w),


                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: widget.compact ? 16.sp : 16.sp,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 6),
                              Text(
                                desc.isNotEmpty ? desc : 'No description',
                                style: TextStyle(color: Colors.white70, fontSize: widget.compact ? 12.sp : 12.sp),
                                maxLines: widget.compact ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                              ),

                              const SizedBox(height: 8),


                              Row(
                                children: [

                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: statusColor.withOpacity(0.22)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(_statusIcon(status), size: 14, color: statusColor),
                                        SizedBox(width: 6),
                                        Text(
                                          _titleCase(status),
                                          style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 12.sp),
                                        ),
                                      ],
                                    ),
                                  ),


                                ],
                              ),
                            ],
                          ),
                        ),


                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                endDateStr.isNotEmpty ? endDateStr : '-',
                                style: TextStyle(color: Colors.white70, fontSize: 14.sp, fontWeight: FontWeight.w600),
                              ),
                            ),
                            SizedBox(height: 8),
                            Icon(Icons.chevron_right, color: Colors.white24),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'active':
        return Icons.play_arrow;
      case 'completed':
        return Icons.check;
      default:
        return Icons.schedule;
    }
  }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
