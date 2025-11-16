import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import './../../services/task_service.dart';
import 'package:intl/intl.dart';

class AddTaskSheet extends StatefulWidget {
  const AddTaskSheet({Key? key}) : super(key: key);

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}
class _AddTaskSheetState extends State<AddTaskSheet> {
  final titleC = TextEditingController();
  final descC = TextEditingController();
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now().add(const Duration(days: 1));
  String status = 'not started';
  bool loading = false;

  @override
  void dispose() {
    titleC.dispose();
    descC.dispose();
    super.dispose();
  }

  Future<void> pickDate(BuildContext ctx, bool isStart) async {
    final initial = isStart ? startDate : endDate;
    final first = isStart ? DateTime(2000) : startDate;
    final picked = await showDatePicker(
      context: ctx,
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
      setState(() {
        if (isStart) {
          startDate = picked;
          if (endDate.isBefore(startDate)) endDate = startDate;
        } else {
          endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.read<TaskService>();
    String fmt(DateTime d) => DateFormat('dd MMM yyyy').format(d);

    InputDecoration fieldDecoration(String hint, {Widget? suffix}) {
      return InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Color(0xFF1E1E20),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        suffixIcon: suffix,
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F10),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 60, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10))),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text("New Task", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton(onPressed: () => Navigator.pop(context), child: Text("Done", style: TextStyle(color: Colors.white70)))
              ]),
              const SizedBox(height: 8),
              TextField(controller: titleC, style: const TextStyle(color: Colors.white), decoration: fieldDecoration("Title")),
              const SizedBox(height: 10),
              TextField(
                controller: descC,
                style: const TextStyle(color: Colors.white70),
                minLines: 3,
                maxLines: 5,
                decoration: fieldDecoration("Enter task description"),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: InkWell(
                    onTap: () => pickDate(context, true),
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
                    onTap: () => pickDate(context, false),
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: fieldDecoration("End date"),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(fmt(endDate), style: TextStyle(color: Colors.white70)), Icon(Icons.calendar_month, color: Colors.white54)]),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              // Status segmented
              Align(alignment: Alignment.centerLeft, child: Text("Status", style: TextStyle(color: Colors.white70, fontSize: 12))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _statusButton("Not started", 'not started')),
                const SizedBox(width: 8),
                Expanded(child: _statusButton("Active", 'active')),
                const SizedBox(width: 8),
                Expanded(child: _statusButton("Completed", 'completed')),
              ]),
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
                    setState(() => loading = true);
                    try {
                      await svc.addTask(titleC.text.trim(), descC.text.trim(), startDate, endDate, status);
                      Navigator.pop(context);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                    } finally {
                      setState(() => loading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Create", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusButton(String label, String value) {
    final bool active = value == status;
    return GestureDetector(
      onTap: () => setState(() => status = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: active ? Colors.white : const Color(0xFF1E1E20), borderRadius: BorderRadius.circular(10)),
        child: Center(child: Text(label, style: TextStyle(color: active ? Colors.black : Colors.white70))),
      ),
    );
  }
}