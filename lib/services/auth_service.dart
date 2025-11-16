// lib/services/auth_service.dart
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class AuthService extends ChangeNotifier {
  final storage = const FlutterSecureStorage();
  final String baseUrl = AppConfig.baseUrl; // ensure this is correct

  // public state
  bool initializing = true; // true while init() runs
  bool _loggedIn = false;
  bool get loggedIn => _loggedIn;

  String? accessToken;
  String? refreshToken;
  Map<String, dynamic>? me; // optional profile object if backend provides /auth/me

  // network timeout
  Duration _timeout = const Duration(seconds: 30); // increased for reliability

  AuthService();

  /// Initialize AuthService: load tokens from secure storage and validate (optional)
  Future<void> init() async {
    initializing = true;
    notifyListeners();

    try {
      accessToken = await storage.read(key: "access");
      refreshToken = await storage.read(key: "refresh");

      if (accessToken != null) {
        // Optionally verify token by fetching profile; if it fails try refresh
        final ok = await tryFetchProfile();
        if (!ok) {
          // attempt refresh if profile fetch failed
          final refreshed = await _refreshToken();
          if (refreshed) {
            await tryFetchProfile();
          } else {
            // tokens invalid, clear
            await _clearTokensLocal();
            _loggedIn = false;
          }
        } else {
          _loggedIn = true;
        }
      } else if (refreshToken != null) {
        // we have only refresh token — try to exchange for access
        final refreshed = await _refreshToken();
        if (refreshed) {
          final ok = await tryFetchProfile();
          _loggedIn = ok;
        } else {
          _loggedIn = false;
        }
      } else {
        _loggedIn = false;
      }
    } catch (e) {
      // defensive: if anything goes wrong, mark not logged in
      debugPrint('[AuthService] init error: $e');
      _loggedIn = false;
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  /// Attempt to fetch profile from backend (/auth/me). Returns true on success.
  Future<bool> tryFetchProfile() async {
    if (accessToken == null) return false;
    try {
      final res = await http.get(Uri.parse("$baseUrl/auth/me"),
          headers: {
            "Authorization": "Bearer $accessToken",
            "Content-Type": "application/json"
          }).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map) {
          me = Map<String, dynamic>.from(data);
        }
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('[AuthService] tryFetchProfile error: $e');
      return false;
    }
  }

  /// Exchange refresh token for a new access token. Returns true if refreshed.
  Future<bool> _refreshToken() async {
    final refresh = refreshToken ?? await storage.read(key: "refresh");
    if (refresh == null) return false;

    try {
      final res = await http
          .post(Uri.parse("$baseUrl/auth/refresh"),
          headers: {"Content-Type": "application/json"}, body: jsonEncode({"refreshToken": refresh}))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final newAccess = data["accessToken"] ?? data["access"];
        final newRefresh = data["refreshToken"] ?? data["refresh"];
        if (newAccess != null) {
          accessToken = newAccess.toString();
          await storage.write(key: "access", value: accessToken);
        }
        if (newRefresh != null) {
          refreshToken = newRefresh.toString();
          await storage.write(key: "refresh", value: refreshToken);
        }
        notifyListeners();
        return true;
      } else {
        // refresh failed; clear tokens
        await _clearTokensLocal();
        notifyListeners();
        return false;
      }
    } on TimeoutException {
      debugPrint('[AuthService] refresh token timed out');
      return false;
    } on SocketException catch (e) {
      debugPrint('[AuthService] refresh token network error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[AuthService] refresh token error: $e');
      return false;
    }
  }

  /// Public: get access token (reads from memory first)
  Future<String?> getAccessToken() async => accessToken ?? await storage.read(key: "access");

  Future<String?> getRefreshToken() async => refreshToken ?? await storage.read(key: "refresh");

  /// Login with email/password. Returns true on success.
  Future<bool> login(String email, String password) async {
    final url = Uri.parse("$baseUrl/auth/login");
    debugPrint("[AuthService] LOGIN URL: $url");
    try {
      final res = await http
          .post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      )
          .timeout(_timeout);

      debugPrint("LOGIN: status=${res.statusCode}, body=${res.body}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final a = data["accessToken"] ?? data["access"];
        final r = data["refreshToken"] ?? data["refresh"];

        if (a != null) {
          accessToken = a.toString();
          await storage.write(key: "access", value: accessToken);
        }
        if (r != null) {
          refreshToken = r.toString();
          await storage.write(key: "refresh", value: refreshToken);
        }

        _loggedIn = true;
        // try to fetch profile, but don't fail login if profile isn't available
        await tryFetchProfile();
        notifyListeners();
        return true;
      }

      // helpful: include server message if present
      try {
        final parsed = jsonDecode(res.body);
        if (parsed is Map && parsed["message"] != null) {
          throw Exception("Login failed: ${parsed["message"]}");
        }
      } catch (_) {}

      throw Exception("Login failed: HTTP ${res.statusCode}");
    } on TimeoutException {
      throw Exception("Login request timed out after ${_timeout.inSeconds}s");
    } on SocketException catch (e) {
      throw Exception("Network error during login: ${e.message}");
    } catch (e) {
      throw Exception("Login error: $e");
    }
  }

  /// Register then login. Returns true on success.
  /// Register then login. Returns true on success.
  /// Improved error parsing and diagnostics.
  Future<bool> register(String email, String password) async {
    final url = Uri.parse("$baseUrl/auth/register");
    debugPrint("[AuthService] REGISTER URL: $url");
    try {
      final res = await http
          .post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      )
          .timeout(_timeout);

      debugPrint("REGISTER: status=${res.statusCode}, body=${res.body}");

      if (res.statusCode == 201 || res.statusCode == 200) {
        // If backend registers but doesn't auto-login, attempt login as before.
        final loginOk = await login(email, password);
        if (!loginOk) throw Exception("Registered but unable to log in.");
        return true;
      }

      // parse error message(s) from response (many backend formats supported)
      final parsedMsg = _parseErrorFromResponse(res);
      throw Exception(parsedMsg);
    } on TimeoutException {
      // optional: one retry
      debugPrint("Registration timed out; retrying once...");
      try {
        final res = await http
            .post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"email": email, "password": password}),
        )
            .timeout(_timeout);
        debugPrint("REGISTER (retry): status=${res.statusCode}, body=${res.body}");
        if (res.statusCode == 201 || res.statusCode == 200) {
          final loginOk = await login(email, password);
          if (!loginOk) throw Exception("Registered but unable to log in.");
          return true;
        }
        final parsedMsg = _parseErrorFromResponse(res);
        throw Exception(parsedMsg);
      } on TimeoutException {
        throw Exception("Registration request timed out after ${_timeout.inSeconds}s (retry failed)");
      } on SocketException catch (e) {
        throw Exception("Network error during registration (retry): ${e.message}");
      } catch (e) {
        throw Exception("Registration error (retry): $e");
      }
    } on SocketException catch (e) {
      throw Exception("Network error during registration: ${e.message}");
    } catch (e) {
      throw Exception("Registration error: $e");
    }
  }

  /// Helper: parse error text from http.Response.
  ///
  /// Tries common shapes:
  /// - { "message": "..." }
  /// - { "error": "..." }
  /// - { "errors": ["a","b"] } or { "errors": { "email": ["..."], "password": ["..."] } }
  /// - raw text fallback
  String _parseErrorFromResponse(http.Response res) {
    try {
      if (res.body.isEmpty) return "Registration failed (empty response, HTTP ${res.statusCode})";

      final parsed = jsonDecode(res.body);

      if (parsed is String && parsed.isNotEmpty) return parsed;

      if (parsed is Map) {
        // common keys
        if (parsed.containsKey("message") && parsed["message"] != null) {
          return parsed["message"].toString();
        }
        if (parsed.containsKey("error") && parsed["error"] != null) {
          final err = parsed["error"];
          if (err is String) return err;
          return err.toString();
        }

        if (parsed.containsKey("errors") && parsed["errors"] != null) {
          final errs = parsed["errors"];
          // errors: array
          if (errs is List) {
            return errs.map((e) => e.toString()).join("; ");
          }
          // errors: map of field -> [messages]
          if (errs is Map) {
            final parts = <String>[];
            errs.forEach((k, v) {
              if (v is List) {
                parts.add("$k: ${v.map((e) => e.toString()).join(', ')}");
              } else {
                parts.add("$k: ${v.toString()}");
              }
            });
            if (parts.isNotEmpty) return parts.join(" • ");
          }
        }

        // sometimes backend returns validation like { "email": ["msg"] }
        final validationParts = <String>[];
        for (final entry in parsed.entries) {
          final key = entry.key.toString();
          final val = entry.value;
          if (val is List) {
            validationParts.add("$key: ${val.map((e) => e.toString()).join(', ')}");
          } else if (val is String && val.isNotEmpty) {
            validationParts.add("$key: $val");
          }
        }
        if (validationParts.isNotEmpty) return validationParts.join(" • ");
      }

      // fallback: raw body
      return "Registration failed: ${res.body}";
    } catch (e) {
      debugPrint("[AuthService] parse error response failed: $e -- raw: ${res.body}");
      return "Registration failed (HTTP ${res.statusCode})";
    }
  }


  /// Logout: optional server call to revoke refresh, then clear local tokens.
  Future<void> logout() async {
    final refresh = await storage.read(key: "refresh");

    try {
      if (refresh != null) {
        await http
            .post(
          Uri.parse("$baseUrl/auth/logout"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"refreshToken": refresh}),
        )
            .timeout(const Duration(seconds: 8));
      }
    } catch (_) {
      // ignore network/logout errors — we'll clear tokens locally anyway
    }

    await _clearTokensLocal();

    _loggedIn = false;
    me = null;
    notifyListeners();
  }

  /// Clear tokens from memory & storage (local only)
  Future<void> _clearTokensLocal() async {
    accessToken = null;
    refreshToken = null;
    try {
      await storage.delete(key: "access");
      await storage.delete(key: "refresh");
    } catch (e) {
      debugPrint('[AuthService] failed to clear tokens: $e');
    }
  }

  /// Helper used by other services: returns an access token and attempts refresh on 401 if needed.
  /// Example usage in your TaskService: call auth.getAccessToken() before requests.
  Future<String?> ensureAccessToken() async {
    if (accessToken != null) return accessToken;
    final stored = await storage.read(key: "access");
    if (stored != null) {
      accessToken = stored;
      return accessToken;
    }
    // attempt refresh if refresh token exists
    final refreshed = await _refreshToken();
    if (refreshed) return accessToken;
    return null;
  }
}
