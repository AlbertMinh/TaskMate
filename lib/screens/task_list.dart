import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import '../services/task_service.dart';
import 'HomeScreenComponents/TaskListItem.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({Key? key}) : super(key: key);

  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  DateTime? selectedDate;
  final int _windowSize = 15;
  final ScrollController _dateScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    Future.microtask(() => context.read<TaskService>().fetchTasks());
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerSelectedDate());
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  Future<void> _centerSelectedDate({int? targetIndex, bool animate = true}) async {
    if (!_dateScrollController.hasClients) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final leftPad = screenWidth * 0.04;
    final tileWidth = screenWidth * 0.20;
    final margin = screenWidth * 0.02;
    final itemExtent = tileWidth + (margin * 2);

    final index = targetIndex ?? (_windowSize ~/ 2);
    final desiredOffset = leftPad + (index * itemExtent) + (tileWidth / 2) - (screenWidth / 2);

    final maxScroll = _dateScrollController.position.maxScrollExtent;
    final offset = desiredOffset.clamp(0.0, maxScroll);

    if (animate) {
      await _dateScrollController.animateTo(offset, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    } else {
      _dateScrollController.jumpTo(offset);
    }
  }

  List _applyDateFilter(List raw) {
    if (selectedDate == null) return raw;
    final sel = DateFormat('yyyy-MM-dd').format(selectedDate!);

    return raw.where((t) {
      final rawDate = t['endDate'];
      if (rawDate == null) return false;
      try {
        final d = DateTime.parse(rawDate.toString());
        return DateFormat('yyyy-MM-dd').format(d) == sel;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _centerDate() => selectedDate ?? DateTime.now();

  List<DateTime> _dateWindow(DateTime center) {
    final half = (_windowSize ~/ 2);
    return List.generate(_windowSize, (i) => center.add(Duration(days: i - half)));
  }

  @override
  Widget build(BuildContext context) {
    final raw = context.watch<TaskService>().tasks;
    final tasks = (raw is List) ? raw : <dynamic>[];
    final filtered = _applyDateFilter(tasks);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0C),
      appBar: AppBar(
        title: Text("Tasks", style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0B0B0C),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_month, size: 20.sp),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: Color(0xFF1DB954),
                      surface: Color(0xFF1A1A1C),
                    ),
                  ),
                  child: child!,
                ),
              );

              if (picked != null) {
                setState(() => selectedDate = DateTime(picked.year, picked.month, picked.day));
                WidgetsBinding.instance.addPostFrameCallback((_) => _centerSelectedDate());
              }
            },
          ),
          if (selectedDate != null)
            IconButton(
              icon: Icon(Icons.close, size: 20.sp),
              onPressed: () {
                setState(() => selectedDate = null);
                WidgetsBinding.instance.addPostFrameCallback((_) => _centerSelectedDate());
              },
            ),
        ],
      ),

      body: LayoutBuilder(
        builder: (context, constraints) {
          final dateStripHeight = math.min(16.h, constraints.maxHeight * 0.16);
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          final center = _centerDate();
          final dateWindow = _dateWindow(center);

          final screenWidth = MediaQuery.of(context).size.width;
          final tileWidth = screenWidth * 0.20;

          return Column(
            children: [

              SizedBox(
                height: dateStripHeight,
                child: ListView.builder(
                  controller: _dateScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  itemCount: dateWindow.length,
                  itemBuilder: (_, i) {
                    final d = dateWindow[i];
                    final selected = selectedDate != null
                        ? _isSameDay(d, selectedDate!)
                        : _isSameDay(d, DateTime.now());

                    return GestureDetector(
                      onTap: () {
                        final tap = DateTime(d.year, d.month, d.day);
                        setState(() {
                          if (selectedDate != null && _isSameDay(tap, selectedDate!)) {
                            selectedDate = null;
                          } else {
                            selectedDate = tap;
                          }
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) => _centerSelectedDate(targetIndex: i));
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: dateStripHeight * 0.8,
                        width: tileWidth,
                        margin: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.6.h),
                        decoration: BoxDecoration(
                          color: selected ? Colors.white : const Color(0xFF1A1A1C),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: selected ? Colors.white : Colors.white10),
                          boxShadow: [
                            if (selected)
                              BoxShadow(
                                color: Colors.white24,
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('E').format(d),
                              style: TextStyle(
                                color: selected ? Colors.black87 : Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 10.sp,
                              ),
                            ),
                            SizedBox(height: 0.5.h),
                            Text(
                              "${d.day}",
                              style: TextStyle(
                                color: selected ? Colors.black87 : Colors.white,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 0.3.h),
                            Text(
                              DateFormat('MMM').format(d),
                              style: TextStyle(
                                fontSize: 9.sp,
                                color: selected ? Colors.black54 : Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),


              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                child: Row(
                  children: [
                    Text(
                      selectedDate != null
                          ? "Tasks on ${DateFormat('dd MMM yyyy').format(selectedDate!)}"
                          : "All Tasks",
                      style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),


              Expanded(
                child: filtered.isEmpty
                    ? Center(
                  child: Text(
                    "No tasks",
                    style: TextStyle(color: Colors.white60, fontSize: 13.sp),
                  ),
                )
                    : RefreshIndicator(
                  onRefresh: () async => context.read<TaskService>().fetchTasks(),
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 2.h + bottomInset),
                    itemCount: filtered.length,
                    itemBuilder: (_, idx) {
                      final t = filtered[idx] as Map;
                      return TaskListItem(
                        task: t,
                        compact: false,
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
