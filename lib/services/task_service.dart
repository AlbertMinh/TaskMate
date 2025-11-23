// lib/services/task_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import 'auth_service.dart';

class TaskService extends ChangeNotifier {
  final String baseUrl = AppConfig.baseUrl; // configurable

  AuthService? _auth; // injected
  List<dynamic> tasks = [];
  bool isLoading = false;

  void updateAuth(AuthService auth) {
    _auth = auth;
    if (_auth?.loggedIn == true) {
      fetchTasks();
    } else {
      tasks = [];
      notifyListeners();
    }
  }

  Future<String?> _getValidAccessToken() async {
    if (_auth == null) return null;
    try {
      final token = await _auth!.ensureAccessToken();
      return token;
    } catch (e) {
      debugPrint('[TaskService] _getValidAccessToken error: $e');
      return null;
    }
  }

  Future<void> fetchTasks() async {
    isLoading = true;
    notifyListeners();

    final token = await _getValidAccessToken();
    if (token == null) {
      isLoading = false;
      notifyListeners();
      await _auth?.logout();
      throw Exception('Not authenticated');
    }

    http.Response res;
    try {
      res = await http
          .get(Uri.parse("$baseUrl/tasks"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json"
          })
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      isLoading = false;
      notifyListeners();
      throw Exception('Request timed out');
    } catch (e) {
      isLoading = false;
      notifyListeners();
      rethrow;
    }

    if (res.statusCode == 401) {
      final newToken = await _getValidAccessToken();
      if (newToken != null && newToken != token) {
        return fetchTasks();
      } else {
        isLoading = false;
        notifyListeners();
        await _auth?.logout();
        throw Exception('Authorization failed');
      }
    }

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data is List) {
        tasks = data;
        try {
          tasks.sort((a, b) {
            final aDate = a['endDate'];
            final bDate = b['endDate'];
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            final da = DateTime.tryParse(aDate.toString()) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final db = DateTime.tryParse(bDate.toString()) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return da.compareTo(db);
          });
        } catch (_) {}
      } else {
        tasks = [];
      }
      isLoading = false;
      notifyListeners();
      return;
    }

    isLoading = false;
    notifyListeners();
    throw Exception('Failed to load tasks (HTTP ${res.statusCode})');
  }

  Future<bool> addTask(String title, String description, DateTime startDate,
      DateTime endDate, String status) async {
    final token = await _getValidAccessToken();
    if (token == null) {
      await _auth?.logout();
      return false;
    }

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
        final refreshedToken = await _getValidAccessToken();
        if (refreshedToken != null && refreshedToken != token) {
          return addTask(title, description, startDate, endDate, status);
        }
        await _auth?.logout();
        return false;
      }

      if (res.statusCode == 201 || res.statusCode == 200) {
        await fetchTasks();
        return true;
      }

      debugPrint('[TaskService] addTask failed status=${res.statusCode} body=${res.body}');
      return false;
    } catch (e) {
      debugPrint('[TaskService] addTask error: $e');
      return false;
    }
  }

  Future<bool> updateTask(String id, Map<String, dynamic> updates) async {
    final token = await _getValidAccessToken();
    if (token == null) {
      await _auth?.logout();
      return false;
    }

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
        final refreshedToken = await _getValidAccessToken();
        if (refreshedToken != null && refreshedToken != token) {
          return updateTask(id, updates);
        }
        await _auth?.logout();
        return false;
      }

      if (res.statusCode == 200) {
        await fetchTasks();
        return true;
      }
      debugPrint('[TaskService] updateTask failed status=${res.statusCode} body=${res.body}');
      return false;
    } catch (e) {
      debugPrint('[TaskService] updateTask error: $e');
      return false;
    }
  }

  Future<bool> updateTaskStatus(String id, String status) async {
    return updateTask(id, {"status": status});
  }

  Future<bool> deleteTask(String id) async {
    final token = await _getValidAccessToken();
    if (token == null) {
      await _auth?.logout();
      return false;
    }

    try {
      final res = await http
          .delete(Uri.parse("$baseUrl/tasks/$id"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json"
          })
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 401) {
        final refreshedToken = await _getValidAccessToken();
        if (refreshedToken != null && refreshedToken != token) {
          return deleteTask(id);
        }
        await _auth?.logout();
        return false;
      }

      if (res.statusCode == 200) {
        await fetchTasks();
        return true;
      }
      debugPrint('[TaskService] deleteTask failed status=${res.statusCode} body=${res.body}');
      return false;
    } catch (e) {
      debugPrint('[TaskService] deleteTask error: $e');
      return false;
    }
  }

  // ---------------------------
  // Collaborator APIs
  // ---------------------------

  /// Share a task by userId or email with a role (editor/commenter/viewer).
  Future<bool> shareTask(String taskId, {String? userId, String? email, required String role}) async {
    final token = await _getValidAccessToken();
    if (token == null) return false;

    final payload = <String, dynamic>{'role': role};
    if (userId != null) payload['userId'] = userId;
    if (email != null) payload['email'] = email;

    try {
      final res = await http
          .post(Uri.parse("$baseUrl/tasks/$taskId/share"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json"
          },
          body: jsonEncode(payload))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        await fetchTasks();
        return true;
      }
      debugPrint('[TaskService] shareTask failed status=${res.statusCode} body=${res.body}');
      return false;
    } catch (e) {
      debugPrint('[TaskService] shareTask error: $e');
      return false;
    }
  }

  /// Get list of collaborators for a task. Returns list of collaborator objects.
  Future<List<dynamic>> listCollaborators(String taskId) async {
    final token = await _getValidAccessToken();
    if (token == null) return [];
    try {
      final res = await http
          .get(Uri.parse("$baseUrl/tasks/$taskId/collaborators"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json"
          })
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return data;
      }
      debugPrint('[TaskService] listCollaborators failed status=${res.statusCode} body=${res.body}');
      return [];
    } catch (e) {
      debugPrint('[TaskService] listCollaborators error: $e');
      return [];
    }
  }

  /// Remove collaborator by collaborator doc _id.
  Future<bool> removeCollaborator(String taskId, String collabId) async {
    final token = await _getValidAccessToken();
    if (token == null) return false;
    try {
      final res = await http
          .delete(Uri.parse("$baseUrl/tasks/$taskId/collaborators/$collabId"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json"
          })
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        await fetchTasks();
        return true;
      }
      debugPrint('[TaskService] removeCollaborator failed status=${res.statusCode} body=${res.body}');
      return false;
    } catch (e) {
      debugPrint('[TaskService] removeCollaborator error: $e');
      return false;
    }
  }
}
