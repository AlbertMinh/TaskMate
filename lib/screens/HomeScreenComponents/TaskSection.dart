import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
class TaskSection extends StatelessWidget {
  final String title;
  final String emptyMessage;
  final List<Widget> children;
  const TaskSection({Key? key, required this.title, required this.emptyMessage, required this.children})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.white)),
        SizedBox(height: 1.h),
        if (children.isEmpty)
          Center(child: Text(emptyMessage, style: TextStyle(color: Colors.grey, fontSize: 12.sp)))
        else
          ...children,
      ],
    );
  }
}