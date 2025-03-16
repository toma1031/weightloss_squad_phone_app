import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/signup_page.dart';
import 'screens/signup_complete_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load();
  
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  Uri? _initialUri;
  Uri? _latestUri;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    // 初期リンクの取得を非同期で開始
    _initializeAppLinks();
  }
  
Future<void> _initializeAppLinks() async {
  print('Initializing app links');
  try {
    final initialUri = await _appLinks.getInitialAppLink();
    print('Initial URI: $initialUri');
        // ここに追加（初期URI用）
    print('=== Initial URI Debug Info ===');
    print('Received URI: ${initialUri?.toString()}');
    print('Scheme: ${initialUri?.scheme}');
    print('Host: ${initialUri?.host}');
    print('Path: ${initialUri?.path}');
    print('Query Parameters: ${initialUri?.queryParameters}');
    print('===========================');
    if (initialUri != null) {
      setState(() {
        _initialUri = initialUri;
        _latestUri = initialUri;
      });
      
      // 初期URIがある場合は即座にナビゲーション
      if (!mounted) return;
      if (initialUri.host == 'signup-complete') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushNamed(
            '/signup-complete',
            arguments: initialUri.queryParameters['code'],
          );
        });
      }
    }
  } catch (e) {
    print('Error getting initial link: $e');
  }
  
  // ストリームでのリンク受信を設定
  _linkSubscription = _appLinks.uriLinkStream.listen(
    (Uri? uri) {
            // ここに追加（ストリームURI用）
      print('=== Stream URI Debug Info ===');
      print('Received URI: ${uri?.toString()}');
      print('Scheme: ${uri?.scheme}');
      print('Host: ${uri?.host}');
      print('Path: ${uri?.path}');
      print('Query Parameters: ${uri?.queryParameters}');
      print('=========================');
      print('Stream URI received: $uri');
      if (uri != null && uri.host == 'signup-complete') {
        if (!mounted) return;
        Navigator.of(context).pushNamed(
          '/signup-complete',
          arguments: uri.queryParameters['code'],
        );
      }
    },
    onError: (err) {
      print('Error in app_links: $err');
    },
  );
  
  setState(() {
    _isLoading = false;
  });
}
  
  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }
  
@override
Widget build(BuildContext context) {
  return MaterialApp(
    title: 'Weightloss Squad Phone App',
    theme: ThemeData(primarySwatch: Colors.blue),
    initialRoute: '/signup',
    routes: {
      '/signup': (context) => const SignupPage(),
      '/signup-complete': (context) => SignupCompletePage(
        code: ModalRoute.of(context)?.settings.arguments as String?,
      ),
      '/login': (context) => const Placeholder(),
    },
  );
}

}