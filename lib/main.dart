import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/supabase_config.dart';
import 'core/notifications/notification_service.dart';
import 'core/storage/progress_storage_service.dart';
import 'features/shell/presentation/screens/main_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Supabase so Supabase.instance is safe throughout the app
  try {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
    debugPrint('[main] Supabase initialized.');
  } catch (e) {
    debugPrint('[main] Supabase init fallback note: $e');
  }

  // 2. Initialize Persistent Progress & Discipline Statistics Storage
  try {
    await ProgressStorageService().init();
    debugPrint('[main] Progress storage initialized.');
  } catch (e) {
    debugPrint('[main] Progress storage init note: $e');
  }

  // 3. Initialize Cross-Platform Daily Reminder Service (Android alarms & Web notification bridge)
  try {
    final notificationService = CrossPlatformNotificationService();
    await notificationService.initialize();
  } catch (e) {
    debugPrint('[main] Notification service init exception: $e');
  }

  runApp(
    const ProviderScope(
      child: DailyleApp(),
    ),
  );
}

class DailyleApp extends StatelessWidget {
  const DailyleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dailyle - Luyện Phát Âm AI & Kỷ Luật',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB), // Deep Royal Blue
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
      ),
      themeMode: ThemeMode.system,
      home: const MainScaffold(),
    );
  }
}
