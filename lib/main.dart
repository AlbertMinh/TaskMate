// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:task_mate/services/note_service.dart';
import 'package:task_mate/widgets/listening_overlay.dart';
import 'services/voice_service.dart';
import 'services/auth_service.dart';
import 'services/task_service.dart';
import 'services/notification_service.dart';
import 'providers/app_settings.dart';
import 'screens/home_screen.dart';
import 'screens/WelcomeScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // initialize notification plugin early
  await NotificationService().init();

  // Create and initialize AuthService BEFORE runApp so app knows login state immediately
  final authService = AuthService();
  await authService.init(); // loads token / user data from secure storage
  debugPrint('[main] AuthService init done: loggedIn=${authService.loggedIn}');

  runApp(
    MyApp(authService: authService),
  );
}

class MyApp extends StatefulWidget {
  final AuthService authService;
  const MyApp({Key? key, required this.authService}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  bool _wakeHandlerSetup = false;

  @override
  void initState() {
    super.initState();
    // nothing here; wait for providers to be available after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeSetupWakeHandler());
  }

  Future<void> _maybeSetupWakeHandler() async {
    // avoid multiple calls
    if (_wakeHandlerSetup) return;

    try {
      // ensure provider tree is built
      final ctx = navigatorKey.currentContext;
      if (ctx == null) {
        debugPrint('[MyApp] navigatorKey.context is null; wake handler postponed');
        // try again shortly
        Future.delayed(const Duration(milliseconds: 300), _maybeSetupWakeHandler);
        return;
      }

      final voice = Provider.of<VoiceService>(ctx, listen: false);
      final noteSvc = Provider.of<NoteService>(ctx, listen: false);

      // set wake callback
      voice.setOnWakeDetected(() async {
        debugPrint('[MyApp] wake phrase detected -> opening overlay and capturing note');
        // show listening overlay (non-dismissible)
        showDialog(
          context: navigatorKey.currentContext!,
          barrierDismissible: false,
          builder: (_) => const ListeningOverlay(titleText: 'Listening for note...'),
        );

        // capture; overlay reads live transcript from provider
        final result = await voice.captureNoteInteractive(speakPrompts: true, onPrompt: (p) {
          debugPrint('[Voice] prompt: $p');
        });

        // close overlay if still open
        try {
          navigatorKey.currentState?.pop();
        } catch (_) {}

        if (result['title'] != null && result['title']!.isNotEmpty) {
          try {
            await noteSvc.createNote(title: result['title']!, content: result['description'] ?? '');
            final ctx2 = navigatorKey.currentContext!;
            ScaffoldMessenger.of(ctx2).showSnackBar(const SnackBar(content: Text('Note saved')));
          } catch (e) {
            final ctx2 = navigatorKey.currentContext!;
            ScaffoldMessenger.of(ctx2).showSnackBar(SnackBar(content: Text('Saved locally but failed to persist: $e')));
          }
        } else {
          final ctx2 = navigatorKey.currentContext!;
          ScaffoldMessenger.of(ctx2).showSnackBar(const SnackBar(content: Text('Note cancelled')));
        }

        // restart wake listening after brief pause
        await Future.delayed(const Duration(milliseconds: 400));
        try {
          await voice.startWakeForeground();
        } catch (e) {
          debugPrint('[MyApp] restart wake foreground failed: $e');
        }
      });

      // start wake listening
      await voice.startWakeForeground();
      _wakeHandlerSetup = true;
      debugPrint('[MyApp] wake handler setup complete');
    } catch (e) {
      debugPrint('[MyApp] setupWakeHandler failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: widget.authService),
            ChangeNotifierProvider<VoiceService>(create: (_) => VoiceService()),
            ChangeNotifierProxyProvider<AuthService, TaskService>(
              create: (_) => TaskService(),
              update: (_, auth, taskService) {
                taskService ??= TaskService();
                taskService.updateAuth(auth);
                return taskService;
              },
            ),
            ChangeNotifierProxyProvider<AuthService, NoteService>(
              create: (_) => NoteService(),
              update: (_, auth, noteService) {
                noteService ??= NoteService();
                noteService.updateAuth(auth);
                return noteService;
              },
            ),
            ChangeNotifierProvider<AppSettings>(create: (_) => AppSettings()..load()),
            Provider<NotificationService>(create: (_) => NotificationService()),
          ],
          child: Consumer<AppSettings>(
            builder: (context, settings, _) {
              final theme = settings.currentThemeData;
              return MaterialApp(
                navigatorKey: navigatorKey,
                debugShowCheckedModeBanner: false,
                title: 'TaskMate',
                theme: theme,
                home: RootDecider(),
              );
            },
          ),
        );
      },
    );
  }
}

class RootDecider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (auth.initializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return auth.loggedIn ? HomeScreen() : WelcomeScreen();
  }
}
