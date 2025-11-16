import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import './../../services/task_service.dart';
import 'package:intl/intl.dart';

class TaskDetailScreen extends StatefulWidget {
  final Map task;
  const TaskDetailScreen({Key? key, required this.task}) : super(key: key);

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Map task;

  @override
  void initState() {
    super.initState();
    task = Map<String, dynamic>.from(widget.task);
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.read<TaskService>();
    final title = (task['title'] ?? '').toString();
    final desc = (task['description'] ?? '').toString();
    final startRaw = task['startDate'];
    final endRaw = task['endDate'];
    DateTime? start;
    DateTime? end;
    try {
      if (startRaw != null) start = DateTime.parse(startRaw);
      if (endRaw != null) end = DateTime.parse(endRaw);
    } catch (_) {}
    final status = (task['status'] ?? '').toString().toLowerCase();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151516),
        elevation: 0,
        title: const Text("Task details"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _openEditSheet(context, svc, task),
            tooltip: 'Edit task',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmAndDelete(context, svc),
            tooltip: 'Delete task',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xFF111113), Color(0xFF151516)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 10, offset: Offset(0, 6))],
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: _statusColor(status).withOpacity(0.2)),
                  ),
                  child: Center(
                    child: Icon(_statusIcon(status), color: _statusColor(status), size: 26),
                  ),
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: Text(
                    title.isNotEmpty ? title : 'Untitled task',
                    style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w700),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: _statusColor(status), borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    status.isNotEmpty ? _titleCase(status) : 'Unknown',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 2.h),


          Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: 38.h),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF111113),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 6, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Description",
                  style: TextStyle(color: Colors.white70, fontSize: 16.sp, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    desc.isNotEmpty ? desc : "No description provided.",
                    style: TextStyle(color: Colors.white60, fontSize: 11.sp, height: 1.4),
                  ),
                ),
              ],
            ),
          ),


          SizedBox(height: 2.h),


          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: _infoTile(
                icon: Icons.calendar_today_outlined,
                title: 'Start',
                subtitle: start != null ? DateFormat('dd MMM yyyy').format(start) : '-',
              ),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: _infoTile(
                icon: Icons.calendar_month,
                title: 'End',
                subtitle: end != null ? DateFormat('dd MMM yyyy').format(end) : '-',
              ),
            ),
          ]),

          SizedBox(height: 2.h),


          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Status", style: TextStyle(color: Colors.white54, fontSize: 14.sp)),
              SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: _statusColor(status), borderRadius: BorderRadius.circular(20)),
                child: Text(status.isNotEmpty ? _titleCase(status) : "Unknown", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ]),
            const Spacer(),

            _buildQuickActionButton(svc, status),

            const SizedBox(width: 10),
            _buildDeleteButton(context, svc),
          ]),

          SizedBox(height: 3.h),
        ]),
      ),
    );
  }

  Widget _buildQuickActionButton(TaskService svc, String currentStatus) {
    final id = task['_id'] ?? task['id'] ?? task['taskId'];
    if (id == null) return const SizedBox();

    String buttonText = "";
    String newStatus = "";
    IconData icon = Icons.play_arrow;

    if (currentStatus == "not started") {
      buttonText = "Mark Active";
      newStatus = "active";
      icon = Icons.play_arrow;
    } else if (currentStatus == "active") {
      buttonText = "Mark Completed";
      newStatus = "completed";
      icon = Icons.check;
    } else {
      return const SizedBox();
    }

    return ElevatedButton.icon(
      onPressed: () async {
        final prevStatus = task['status'];

        setState(() => task['status'] = newStatus);

        try {
          final ok = await svc.updateTask(id.toString(), {'status': newStatus});
          if (ok == true) {
            await context.read<TaskService>().fetchTasks();
          } else {
            throw Exception('Update failed');
          }
        } catch (e) {
          // revert & notify
          setState(() => task['status'] = prevStatus);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
        }
      },
      icon: Icon(icon, size: 18),
      label: Text(buttonText),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
      ),
    );
  }

  // Delete button design
  Widget _buildDeleteButton(BuildContext context, TaskService svc) {
    final id = task['_id'] ?? task['id'] ?? task['taskId'];
    if (id == null) return const SizedBox();

    return OutlinedButton.icon(
      onPressed: () => _confirmAndDelete(context, svc),
      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
      label: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.redAccent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
        backgroundColor: Colors.transparent,
      ),
    );
  }

  // confirmation & delete
  Future<void> _confirmAndDelete(BuildContext context, TaskService svc) async {
    final id = task['_id'] ?? task['id'] ?? task['taskId'];
    if (id == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151516),
        title: const Text("Delete task", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to delete this task? This action cannot be undone.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final loader = ScaffoldMessenger.of(context);
      loader.showSnackBar(const SnackBar(content: Text("Deleting...")));
      final success = await svc.deleteTask(id.toString());
      loader.hideCurrentSnackBar();
      if (success == true) {
        await context.read<TaskService>().fetchTasks();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Task deleted")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Delete failed")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Delete error: $e")));
    }
  }

  Widget _infoTile({required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF111113), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: Colors.white70, size: 22)),
        SizedBox(width: 3.w),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: Colors.white54, fontSize: 12.sp, fontWeight: FontWeight.w500)),
          SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold)),
        ])
      ]),
    );
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  IconData _statusIcon(String s) {
    switch (s.toLowerCase()) {
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


  void _openEditSheet(BuildContext context, TaskService svc, Map originalTask) {
    final titleC = TextEditingController(text: (originalTask['title'] ?? '').toString());
    final descC = TextEditingController(text: (originalTask['description'] ?? '').toString());

    DateTime startDate;
    DateTime endDate;
    try {
      startDate = originalTask['startDate'] != null ? DateTime.parse(originalTask['startDate']) : DateTime.now();
    } catch (_) {
      startDate = DateTime.now();
    }
    try {
      endDate = originalTask['endDate'] != null ? DateTime.parse(originalTask['endDate']) : startDate.add(const Duration(days: 1));
    } catch (_) {
      endDate = startDate.add(const Duration(days: 1));
    }


    String status = (originalTask['status'] ?? 'not started').toString();

    bool loading = false;
    bool showStatusToast = false;
    Timer? toastTimer;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx2, setStateDialog) {
          Future<void> pickDate(BuildContext ctxx, bool isStart) async {
            final initial = isStart ? startDate : endDate;
            final first = isStart ? DateTime(2000) : startDate;
            final picked = await showDatePicker(
              context: ctxx,
              initialDate: initial,
              firstDate: first,
              lastDate: DateTime(2100),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.dark(
                      primary: const Color(0xFF1DB954),
                      onPrimary: Colors.white,
                      surface: const Color(0xFF151516),
                      onSurface: Colors.white,
                    ),
                    dialogBackgroundColor: const Color(0xFF151516),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setStateDialog(() {
                if (isStart) {
                  startDate = picked;
                  if (endDate.isBefore(startDate)) endDate = startDate;
                } else {
                  endDate = picked;
                }
              });
            }
          }

          String fmt(DateTime d) => DateFormat('dd MMM yyyy').format(d);

          InputDecoration fieldDecoration(String hint, {Widget? suffix}) {
            return InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF1E1E20),
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              suffixIcon: suffix,
            );
          }


          Widget statusSegment(String value, IconData iconData) {
            final bool active = value == status;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutQuad,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: active ? Colors.white : const Color(0xFF1E1E20),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: active ? [BoxShadow(color: Colors.white24, blurRadius: 8, offset: Offset(0, 4))] : null,
                  border: Border.all(color: active ? Colors.white12 : Colors.white10),
                ),
                child: InkWell(
                  onTap: () {
                    setStateDialog(() {
                      status = value;
                      showStatusToast = true;
                    });
                    toastTimer?.cancel();
                    toastTimer = Timer(const Duration(milliseconds: 1200), () {
                      setStateDialog(() => showStatusToast = false);
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedScale(
                    scale: active ? 1.03 : 1.0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(iconData, color: active ? Colors.black : Colors.white70, size: 16),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _titleCase(value),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: active ? Colors.black : Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 11.sp,
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

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(color: Color(0xFF0F0F10), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 60, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10))),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text("Edit Task", style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {

                          toastTimer?.cancel();
                          Navigator.pop(ctx2);
                        },
                        child: Text("Close", style: TextStyle(color: Colors.white70)),
                      ),
                    ]),
                    SizedBox(height: 8),
                    TextField(controller: titleC, style: const TextStyle(color: Colors.white), decoration: fieldDecoration("Title")),
                    SizedBox(height: 10),
                    TextField(controller: descC, style: const TextStyle(color: Colors.white70), minLines: 3, maxLines: 5, decoration: fieldDecoration("Enter task description")),
                    SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async => pickDate(ctx2, true),
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: fieldDecoration("Start date"),
                            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(fmt(startDate), style: TextStyle(color: Colors.white70)), Icon(Icons.calendar_month, color: Colors.white54)]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () async => pickDate(ctx2, false),
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: fieldDecoration("End date"),
                            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(fmt(endDate), style: TextStyle(color: Colors.white70)), Icon(Icons.calendar_month, color: Colors.white54)]),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),


                    Align(alignment: Alignment.centerLeft, child: Text("Status", style: TextStyle(color: Colors.white70, fontSize: 14.sp))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        statusSegment('not started', Icons.schedule),
                        const SizedBox(width: 6),
                        statusSegment('active', Icons.play_arrow),
                        const SizedBox(width: 6),
                        statusSegment('completed', Icons.check),
                      ],
                    ),

                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: showStatusToast
                          ? Container(
                        key: const ValueKey('status_toast'),
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline, color: Colors.white70, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Status set to ${_titleCase(status)}',
                              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () {

                                setStateDialog(() {
                                  status = (originalTask['status'] ?? 'not started').toString();
                                  showStatusToast = false;
                                });
                                toastTimer?.cancel();
                              },
                              child: Text('Undo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      )
                          : const SizedBox(height: 0),
                    ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: loading
                            ? null
                            : () async {
                          if (titleC.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter title")));
                            return;
                          }
                          setStateDialog(() => loading = true);
                          try {
                            final id = (originalTask['_id'] ?? originalTask['id'] ?? originalTask['taskId'])?.toString();
                            if (id == null) throw Exception("Missing id");
                            final updates = <String, dynamic>{
                              'title': titleC.text.trim(),
                              'description': descC.text.trim(),
                              'startDate': startDate.toIso8601String(),
                              'endDate': endDate.toIso8601String(),
                              'status': status,
                            };
                            final ok = await svc.updateTask(id.toString(), updates);
                            if (ok == true) {
                              setState(() {
                                task['title'] = updates['title'];
                                task['description'] = updates['description'];
                                task['startDate'] = updates['startDate'];
                                task['endDate'] = updates['endDate'];
                                task['status'] = updates['status'];
                              });
                              await context.read<TaskService>().fetchTasks();
                              toastTimer?.cancel();
                              Navigator.pop(ctx2);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Task updated")));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Update failed")));
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                          } finally {
                            setStateDialog(() => loading = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          );
        });
      },
    ).whenComplete(() {

    });
  }
}
