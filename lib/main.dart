import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/signup_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://mujcjzbysyssgycjfxju.supabase.co', // 正しいSupabaseプロジェクトURL
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im11amNqemJ5c3lzc2d5Y2pmeGp1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDAyODI3MTcsImV4cCI6MjA1NTg1ODcxN30.MKU_SY1xX9vGhX26vxwrdi0Ew-VhU8tE0SCqZ8DbVJw', // 正しいanon key
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supabase Signup Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SignupPage(),
    );
  }
}
