import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';

class TaskService extends ChangeNotifier {
  final storage = const FlutterSecureStorage();
  final String baseUrl = AppConfig.baseUrl; // <- configurable

  /// Raw tasks as returned by the backend (List of Map<String, dynamic>)
  List tasks = [];
  bool isLoading = false;

  Future<String?> _getAccessToken() => storage.read(key: "access");
  Future<String?> _getRefreshToken() => storage.read(key: "refresh");

  /// Request a new access token using refresh token. Returns true if refreshed.
  Future<bool> _refreshToken() async {
    final refresh = await _getRefreshToken();
    if (refresh == null) return false;
    try {
      final res = await http
          .post(Uri.parse("$baseUrl/auth/refresh"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"refreshToken": refresh}))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await storage.write(key: "access", value: data["accessToken"]);
        await storage.write(key: "refresh", value: data["refreshToken"]);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Fetch tasks from backend and store in `tasks`.
  Future<void> fetchTasks() async {
    isLoading = true;
    notifyListeners();

    final token = await _getAccessToken();
    http.Response res;
    try {
      res = await http.get(Uri.parse("$baseUrl/tasks"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json"
          }).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      isLoading = false;
      notifyListeners();
      throw 'Request timed out';
    }

    if (res.statusCode == 401) {
      final ok = await _refreshToken();
      if (ok) {
        return fetchTasks();
      } else {
        isLoading = false;
        notifyListeners();
        throw 'Authorization failed';
      }
    }

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      // Ensure tasks is a list; backend expected to return List<Map>
      if (data is List) {
        tasks = data;
        // optional: sort by endDate (earliest first) to help UI show due tasks at top
        try {
          tasks.sort((a, b) {
            final aDate = a['endDate'] ?? a['deadline'] ?? a['date'];
            final bDate = b['endDate'] ?? b['deadline'] ?? b['date'];
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            final da = DateTime.tryParse(aDate) ?? DateTime.fromMillisecondsSinceEpoch(0);
            final db = DateTime.tryParse(bDate) ?? DateTime.fromMillisecondsSinceEpoch(0);
            return da.compareTo(db);
          });
        } catch (_) {
          // ignore sorting errors
        }
      } else {
        tasks = [];
      }

      isLoading = false;
      notifyListeners();
      return;
    }

    isLoading = false;
    notifyListeners();
    throw 'Failed to load tasks';
  }

  /// Add a task. New signature supports startDate, endDate (deadline) and status.
  ///
  /// Expects backend to accept fields:
  ///  - title (string)
  ///  - description (string)
  ///  - startDate (ISO string)
  ///  - endDate (ISO string)
  ///  - status (string: "not started" | "active" | "completed")
  Future<bool> addTask(
      String title,
      String description,
      DateTime startDate,
      DateTime endDate,
      String status,
      ) async {
    final token = await _getAccessToken();
    final payload = {
      "title": title,
      "description": description,
      "startDate": startDate.toIso8601String(),
      "endDate": endDate.toIso8601String(),
      "status": status,
    };

    try {
      final res = await http
          .post(Uri.parse("$baseUrl/tasks"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json"
          },
          body: jsonEncode(payload))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 401) {
        if (await _refreshToken()) return addTask(title, description, startDate, endDate, status);
        return false;
      }

      if (res.statusCode == 201 || res.statusCode == 200) {
        await fetchTasks();
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Update task by id with arbitrary updates map.
  Future<bool> updateTask(String id, Map<String, dynamic> updates) async {
    final token = await _getAccessToken();
    try {
      final res = await http
          .put(Uri.parse("$baseUrl/tasks/$id"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json"
          },
          body: jsonEncode(updates))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 401) {
        if (await _refreshToken()) return updateTask(id, updates);
        return false;
      }
      if (res.statusCode == 200) {
        await fetchTasks();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Helper: update only status field of a task
  Future<bool> updateTaskStatus(String id, String status) async {
    return updateTask(id, {"status": status});
  }

  /// Delete a task by id.
  Future<bool> deleteTask(String id) async {
    final token = await _getAccessToken();
    try {
      final res = await http
          .delete(Uri.parse("$baseUrl/tasks/$id"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json"
          })
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 401) {
        if (await _refreshToken()) return deleteTask(id);
        return false;
      }
      if (res.statusCode == 200) {
        await fetchTasks();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
