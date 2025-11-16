import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class TopBar extends StatelessWidget {
  final VoidCallback onAdd;
  final String name;

  const TopBar({Key? key, required this.onAdd, this.name = "There"}) : super(key: key);

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return "Good Morning";
    } else if (hour >= 12 && hour < 17) {
      return "Good Afternoon";
    } else if (hour >= 17 && hour < 21) {
      return "Good Evening";
    } else {
      return "Good Night";
    }
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _timeGreeting();

    return Row(
      children: [
        CircleAvatar(
          radius: 5.5.w,
          backgroundColor: const Color(0xFF222222),
          child: Icon(Icons.person, size: 8.w, color: Colors.white),
        ),
        SizedBox(width: 4.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hi, $name",
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 0.4.h),
              Text(
                greeting,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 13.sp,
                ),
              ),
            ],
          ),
        ),


        ElevatedButton.icon(
          onPressed: onAdd,
          icon: Icon(Icons.add, size: 14.sp, color: Colors.black),
          label: Text(
            "Add",
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.2.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }
}
