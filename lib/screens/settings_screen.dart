// lib/screens/settings_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for Clipboard
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/task_service.dart';

enum ThemeModePref { system, light, dark }
enum SortPref { byDate, byStatus, byPriority }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // storage & helpers
  final _secureStorage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

  // prefs
  ThemeModePref _themeMode = ThemeModePref.system;
  MaterialColor _accentColor = Colors.green;
  bool _notificationsEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);

  SortPref _sortPref = SortPref.byDate;
  bool _showCompleted = true;

  bool _biometricEnabled = false;
  bool _hasBiometrics = false;
  bool _loading = true;

  String _appVersion = '';


  static const _kThemeMode = 'pref_theme_mode';
  static const _kAccentColor = 'pref_accent_color';
  static const _kNotifications = 'pref_notifications_enabled';
  static const _kReminderTime = 'pref_reminder_time';
  static const _kSortPref = 'pref_sort';
  static const _kShowCompleted = 'pref_show_completed';
  static const _kBiometric = 'pref_biometric_enabled';
  static const _kPinKey = 'app_pin';


  final List<MaterialColor> _accentChoices = [
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.red,
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();


      try {
        final tm = prefs.getString(_kThemeMode) ?? 'system';
        _themeMode = ThemeModePref.values.firstWhere((e) => e.toString().split('.').last == tm,
            orElse: () => ThemeModePref.system);
      } catch (_) {
        _themeMode = ThemeModePref.system;
      }


      try {
        final accentStr = prefs.getString(_kAccentColor);
        if (accentStr != null) {
          final v = int.tryParse(accentStr);
          if (v != null) _accentColor = _materialColorFromColor(Color(v));
        }
      } catch (_) {}


      try {
        _notificationsEnabled = prefs.getBool(_kNotifications) ?? false;
        final timeStr = prefs.getString(_kReminderTime);
        if (timeStr != null) {
          final parts = timeStr.split(':');
          if (parts.length == 2) {
            final h = int.tryParse(parts[0]) ?? 9;
            final m = int.tryParse(parts[1]) ?? 0;
            _reminderTime = TimeOfDay(hour: h, minute: m);
          }
        }
      } catch (_) {
        _notificationsEnabled = false;
        _reminderTime = const TimeOfDay(hour: 9, minute: 0);
      }


      try {
        final sp = prefs.getString(_kSortPref) ?? 'byDate';
        _sortPref = SortPref.values.firstWhere((e) => e.toString().split('.').last == sp, orElse: () => SortPref.byDate);
        _showCompleted = prefs.getBool(_kShowCompleted) ?? true;
      } catch (_) {
        _sortPref = SortPref.byDate;
        _showCompleted = true;
      }


      try {
        _biometricEnabled = prefs.getBool(_kBiometric) ?? false;
      } catch (_) {
        _biometricEnabled = false;
      }

      // check device biometrics (plugin call) - wrap in try/catch
      try {
        _hasBiometrics = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      } catch (_) {
        _hasBiometrics = false;
      }

      // app version (plugin call) - wrap in try/catch
      try {
        final info = await PackageInfo.fromPlatform();
        _appVersion = '${info.version}+${info.buildNumber}';
      } catch (_) {
        _appVersion = '';
      }
    } on Exception catch (e) {
      debugPrint('Settings load failed: $e');

      _themeMode = ThemeModePref.system;
      _accentColor = Colors.green;
      _notificationsEnabled = false;
      _reminderTime = const TimeOfDay(hour: 9, minute: 0);
      _sortPref = SortPref.byDate;
      _showCompleted = true;
      _biometricEnabled = false;
      _hasBiometrics = false;
      _appVersion = '';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  Future<void> _saveThemeMode(ThemeModePref t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, t.toString().split('.').last);
    setState(() => _themeMode = t);

  }

  Future<void> _saveAccentColor(MaterialColor c) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccentColor, c.value.toString());
    setState(() => _accentColor = c);

  }

  Future<void> _saveNotifications(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifications, v);
    setState(() => _notificationsEnabled = v);

    if (v) {
      // TODO: schedule notifications based on _reminderTime
    } else {
      // TODO: cancel scheduled notifications
    }
  }

  Future<void> _saveReminderTime(TimeOfDay t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kReminderTime, '${t.hour}:${t.minute}');
    setState(() => _reminderTime = t);
    // TODO: reschedule notifications if enabled
  }

  Future<void> _saveSortPref(SortPref s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSortPref, s.toString().split('.').last);
    setState(() => _sortPref = s);
  }

  Future<void> _saveShowCompleted(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowCompleted, v);
    setState(() => _showCompleted = v);
  }

  Future<void> _toggleBiometric(bool enable) async {
    if (!_hasBiometrics) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biometrics not available on this device')));
      return;
    }

    if (enable) {
      // authenticate to enable
      try {
        final ok = await _localAuth.authenticate(localizedReason: 'Enable biometric authentication for TaskMate');
        if (!ok) return;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Biometric auth failed: $e')));
        return;
      }
    } else {
      // disabling: require current biometric auth as well for safety (optional)
      try {
        final ok = await _localAuth.authenticate(localizedReason: 'Disable biometric authentication');
        if (!ok) return;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Biometric auth failed: $e')));
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBiometric, enable);
    setState(() => _biometricEnabled = enable);
  }

  Future<void> _setPin() async {
    // Ask user to enter a 4-digit PIN (simple flow)
    final pin = await _askForPinDialog();
    if (pin == null || pin.length != 4) {
      if (pin != null) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN must be 4 digits')));
      return;
    }
    await _secureStorage.write(key: _kPinKey, value: pin);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN saved')));
  }

  Future<void> _clearPin() async {
    await _secureStorage.delete(key: _kPinKey);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN removed')));
  }

  Future<String?> _askForPinDialog() async {
    String pin = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Set 4-digit PIN'),
          content: TextField(
            keyboardType: TextInputType.number,
            maxLength: 4,
            onChanged: (v) => pin = v,
            decoration: const InputDecoration(hintText: 'Enter 4-digit PIN'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, pin), child: const Text('Save')),
          ],
        );
      },
    );
  }

  // Data actions
  Future<void> _exportTasksToClipboard() async {
    final taskService = context.read<TaskService>();
    final tasks = taskService.tasks ?? [];
    final jsonStr = const JsonEncoder.withIndent('  ').convert(tasks);
    await Clipboard.setData(ClipboardData(text: jsonStr));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tasks JSON copied to clipboard')));
  }

  Future<void> _clearCompletedTasks() async {
    final svc = context.read<TaskService>();
    final tasks = svc.tasks ?? [];
    final completed = tasks.where((t) => ((t['status'] ?? '').toString().toLowerCase() == 'completed')).toList();
    if (completed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No completed tasks found')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear completed tasks?'),
        content: Text('Delete ${completed.length} completed tasks from the server?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm != true) return;

    bool anyFailed = false;
    for (final t in completed) {
      final id = t['_id'] ?? t['id'] ?? t['taskId'];
      if (id != null) {
        final ok = await svc.deleteTask(id.toString());
        if (!ok) anyFailed = true;
      }
    }

    if (anyFailed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Some deletes failed')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completed tasks cleared')));
    }
  }

  Future<void> _resetAppPrefs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset app settings?'),
        content: const Text('This will clear local preferences (theme, accent, notifications, etc). It will not log you out.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );

    if (confirm != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kThemeMode);
    await prefs.remove(_kAccentColor);
    await prefs.remove(_kNotifications);
    await prefs.remove(_kReminderTime);
    await prefs.remove(_kSortPref);
    await prefs.remove(_kShowCompleted);
    await prefs.remove(_kBiometric);
    await _secureStorage.delete(key: _kPinKey);

    await _loadAll(); // reload defaults
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App settings reset')));
  }

  Future<void> _logout() async {
    final auth = context.read<AuthService>();
    try {
      await auth.logout();
    } catch (_) {}

  }


  MaterialColor _materialColorFromColor(Color c) {

    if (c.value == Colors.blue.value) return Colors.blue;
    if (c.value == Colors.purple.value) return Colors.purple;
    if (c.value == Colors.orange.value) return Colors.orange;
    if (c.value == Colors.teal.value) return Colors.teal;
    if (c.value == Colors.red.value) return Colors.red;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F10),
        elevation: 0,
        title: const Text('Settings'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionCard(
              title: 'Appearance',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _modeChip(ThemeModePref.system, 'System'),
                      _modeChip(ThemeModePref.light, 'Light'),
                      _modeChip(ThemeModePref.dark, 'Dark'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Accent color', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _accentChoices.map((c) => _colorChip(c)).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            _sectionCard(
              title: 'Notifications',
              child: Column(
                children: [
                  SwitchListTile(
                    activeColor: _accentColor,
                    title: const Text('Enable daily reminders'),
                    value: _notificationsEnabled,
                    onChanged: (v) => _saveNotifications(v),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reminder time'),
                    subtitle: Text(_reminderTime.format(context)),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentColor,
                        elevation: 0,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _notificationsEnabled
                          ? () async {
                        final picked = await showTimePicker(context: context, initialTime: _reminderTime);
                        if (picked != null) await _saveReminderTime(picked);
                      }
                          : null,
                      child: const Text('Edit'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            _sectionCard(
              title: 'Preferences',
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Default sorting'),
                    subtitle: Text(_sortPref == SortPref.byDate ? 'By date' : _sortPref == SortPref.byStatus ? 'By status' : 'By priority'),
                    trailing: Icon(Icons.sort, color: Colors.white54),
                    onTap: () async {
                      final chosen = await showDialog<SortPref>(
                        context: context,
                        builder: (ctx) => SimpleDialog(
                          backgroundColor: const Color(0xFF0F0F10),
                          title: const Text('Choose default sorting'),
                          children: [
                            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, SortPref.byDate), child: const Text('By date')),
                            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, SortPref.byStatus), child: const Text('By status')),
                            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, SortPref.byPriority), child: const Text('By priority')),
                          ],
                        ),
                      );
                      if (chosen != null) await _saveSortPref(chosen);
                    },
                  ),
                  SwitchListTile(
                    activeColor: _accentColor,
                    title: const Text('Show completed tasks'),
                    value: _showCompleted,
                    onChanged: (v) => _saveShowCompleted(v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            _sectionCard(
              title: 'Security',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    activeColor: _accentColor,
                    title: const Text('Biometric unlock'),
                    subtitle: Text(_hasBiometrics ? 'Available on this device' : 'Not available'),
                    value: _biometricEnabled,
                    onChanged: (v) => _toggleBiometric(v),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: _accentColor,
                          elevation: 0,
                          foregroundColor: Colors.white,
                        ),

                        icon: const Icon(Icons.pin),
                        label: const Text('Set PIN'),
                        onPressed: _setPin,
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear PIN'),
                        onPressed: _clearPin,
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            _sectionCard(
              title: 'Data',
              child: Column(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Export tasks to clipboard (JSON)'),
                    onPressed: _exportTasksToClipboard,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: _accentColor,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Clear completed tasks (server)'),
                    onPressed: _clearCompletedTasks,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      elevation: 0,

                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset app preferences'),
                    onPressed: _resetAppPrefs,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white10),
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            _sectionCard(
              title: 'About',
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('TaskMate'),
                    subtitle: Text(_appVersion.isNotEmpty ? 'Version: $_appVersion' : 'Version unknown'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Build by Asim Siddiqui'),
                    onTap: () async {
                      final Uri url = Uri.parse('https://asimsidd.vercel.app/');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      } else {

                        throw 'Could not launch $url';
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                elevation: 0,
              ),
              child: const Text('Logout', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }



  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _modeChip(ThemeModePref mode, String label) {
    final selected = _themeMode == mode;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: selected ? Colors.black : Colors.white70)),
      selected: selected,
      onSelected: (sel) {
        if (sel) _saveThemeMode(mode);
      },
      selectedColor: Colors.white,
      backgroundColor: const Color(0xFF1A1A1C),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _colorChip(MaterialColor c) {
    final selected = c.value == _accentColor.value;
    return GestureDetector(
      onTap: () => _saveAccentColor(c),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected ? c.shade200 : const Color(0xFF121213),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? c.shade100 : Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(backgroundColor: c, radius: 10),
            const SizedBox(width: 8),
            if (selected) Text('Selected', style: TextStyle(color: useWhiteForeground(c.shade500) ? Colors.white : Colors.black)) else const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }


  bool useWhiteForeground(Color backgroundColor) {
    final v = (backgroundColor.red * 299 + backgroundColor.green * 587 + backgroundColor.blue * 114) / 1000;
    return v < 128;
  }
}
