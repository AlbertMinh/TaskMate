// lib/services/note_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import 'auth_service.dart';

class NoteService extends ChangeNotifier {
  final String baseUrl = AppConfig.baseUrl;

  AuthService? _auth;
  List<dynamic> notes = [];
  bool loading = false;
  String search = '';
  bool onlyPinned = false;

  void updateAuth(AuthService auth) {
    _auth = auth;
    if (_auth?.loggedIn == true) {
      fetchNotes();
    } else {
      notes = [];
      notifyListeners();
    }
  }

  Future<String?> _getValidAccessToken() async {
    if (_auth == null) return null;
    try {
      final token = await _auth!.ensureAccessToken();
      return token;
    } catch (e) {
      debugPrint('[NoteService] _getValidAccessToken error: $e');
      return null;
    }
  }

  Future<void> fetchNotes() async {
    final token = await _auth?.ensureAccessToken();
    if (token == null) return;
    try {
      loading = true;
      notifyListeners();
      final res = await http.get(Uri.parse('$baseUrl/notes'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) notes = data;
      }
    } catch (e) {
      debugPrint('[NoteService] fetchNotes error: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> createNote({required String title, String? content, bool pinned = false, List<String>? tags}) async {
    final token = await _auth?.ensureAccessToken();
    if (token == null) return false;
    try {
      final res = await http.post(Uri.parse('$baseUrl/notes'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'title': title, 'content': content ?? '', 'pinned': pinned, 'tags': tags ?? []}),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 201 || res.statusCode == 200) {
        // optionally parse and push locally
        await fetchNotes();
        return true;
      }
      debugPrint('[NoteService] createNote failed status=${res.statusCode} body=${res.body}');
      return false;
    } catch (e) {
      debugPrint('[NoteService] createNote error: $e');
      return false;
    }
  }

  Future<bool> updateNote(String id, Map<String, dynamic> updates) async {
    final token = await _getValidAccessToken();
    if (token == null) return false;
    try {
      final res = await http
          .put(Uri.parse("$baseUrl/notes/$id"),
          headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"},
          body: jsonEncode(updates))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        await fetchNotes();
        return true;
      }
      debugPrint('[NoteService] updateNote failed status=${res.statusCode} body=${res.body}');
      return false;
    } catch (e) {
      debugPrint('[NoteService] updateNote error: $e');
      return false;
    }
  }

  Future<bool> deleteNote(String id) async {
    final token = await _getValidAccessToken();
    if (token == null) return false;
    try {
      final res = await http
          .delete(Uri.parse("$baseUrl/notes/$id"),
          headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"})
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        await fetchNotes();
        return true;
      }
      debugPrint('[NoteService] deleteNote failed status=${res.statusCode} body=${res.body}');
      return false;
    } catch (e) {
      debugPrint('[NoteService] deleteNote error: $e');
      return false;
    }
  }

  // collaborators for notes

  Future<bool> shareNote(String noteId, {String? userId, String? email, required String role}) async {
    final token = await _getValidAccessToken();
    if (token == null) return false;

    final payload = <String, dynamic>{'role': role};
    if (userId != null) payload['userId'] = userId;
    if (email != null) payload['email'] = email;

    try {
      final res = await http
          .post(Uri.parse("$baseUrl/notes/$noteId/share"),
          headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"},
          body: jsonEncode(payload))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        await fetchNotes();
        return true;
      }
      debugPrint('[NoteService] shareNote failed status=${res.statusCode} body=${res.body}');
      return false;
    } catch (e) {
      debugPrint('[NoteService] shareNote error: $e');
      return false;
    }
  }

  Future<List<dynamic>> listCollaborators(String noteId) async {
    final token = await _getValidAccessToken();
    if (token == null) return [];
    try {
      final res = await http
          .get(Uri.parse("$baseUrl/notes/$noteId/collaborators"),
          headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"})
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return data;
      }
      debugPrint('[NoteService] listCollaborators failed status=${res.statusCode} body=${res.body}');
      return [];
    } catch (e) {
      debugPrint('[NoteService] listCollaborators error: $e');
      return [];
    }
  }

  Future<bool> removeCollaborator(String noteId, String collabId) async {
    final token = await _getValidAccessToken();
    if (token == null) return false;
    try {
      final res = await http
          .delete(Uri.parse("$baseUrl/notes/$noteId/collaborators/$collabId"),
          headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"})
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        await fetchNotes();
        return true;
      }
      debugPrint('[NoteService] removeCollaborator failed status=${res.statusCode} body=${res.body}');
      return false;
    } catch (e) {
      debugPrint('[NoteService] removeCollaborator error: $e');
      return false;
    }
  }

  // helpers
  void setSearch(String q) {
    search = q;
    notifyListeners();
  }

  List<dynamic> get filtered {
    var list = notes;
    if (onlyPinned) list = list.where((n) => n['pinned'] == true).toList();
    if (search.isNotEmpty) {
      final q = search.toLowerCase();
      list = list.where((n) {
        final t = (n['title'] ?? '').toString().toLowerCase();
        final c = (n['content'] ?? '').toString().toLowerCase();
        final tagsL = (n['tags'] ?? []).map((e) => e.toString().toLowerCase()).toList();
        return t.contains(q) || c.contains(q) || tagsL.any((tag) => tag.contains(q));
      }).toList();
    }
    return list;
  }

  void togglePinnedFilter() {
    onlyPinned = !onlyPinned;
    notifyListeners();
  }
}
