import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './screens/login_after_page.dart';
import './screens/login_page.dart';
import './screens/splash_page.dart';
import 'screens/meal_upload_page.dart';

Future<void> main() async {
  await dotenv.load(); // This will load .env by default

  final supabaseUrl = dotenv.get('SUPABASE_URL', fallback: '');
  final anonKey = dotenv.get('SUPABASE_ANONKEY', fallback: '');
  debugPrint('SUPABASE_URL: $supabaseUrl');
  debugPrint('ANON_KEY: $anonKey');

  await Supabase.initialize(url: supabaseUrl, anonKey: anonKey);
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supabase Authentication Login Sample',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: <String, WidgetBuilder>{
        '/': (_) => const SplashPage(),
        '/login': (_) => const LoginPage(),
        '/upload': (_) => const UploadPage(),
        '/login-after': (_) => const LoginAfterPage(),
      },
    );
  }
}
