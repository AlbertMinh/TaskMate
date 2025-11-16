import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
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

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>(create: (_) => AuthService()..init()),

            // TaskService depends on auth for tokens; proxy provider allows update when auth changes.
            ChangeNotifierProxyProvider<AuthService, TaskService>(
              create: (_) => TaskService(),
              update: (_, auth, taskService) {
                taskService ??= TaskService();
                return taskService;
              },
            ),

            ChangeNotifierProvider<AppSettings>(create: (_) => AppSettings()..load()),

            // NotificationService is a singleton; you can still provide it if needed:
            Provider<NotificationService>(create: (_) => NotificationService()),
          ],
          child: Consumer<AppSettings>(
            builder: (context, settings, _) {
              final theme = settings.currentThemeData;
              return MaterialApp(
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ⬇️ If the user is not logged in, show WELCOME SCREEN instead of Login
    return auth.loggedIn ? HomeScreen() : WelcomeScreen();
  }
}

