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

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _handleIncomingLinks();
  }

  void _handleIncomingLinks() async {
    print('Starting _handleIncomingLinks');
    try {
      final initialUri = await _appLinks.getInitialAppLink();
      print('Initial URI: $initialUri');
      if (initialUri != null) {
        print('Initial URI Scheme: ${initialUri.scheme}');
        print('Initial URI Path: ${initialUri.path}');
        print('Initial URI Query: ${initialUri.query}');
        if (initialUri.path == '/signup-complete') {
          print(
            'Navigating to /signup-complete with code: ${initialUri.queryParameters['code']}',
          );
          Navigator.pushNamed(context, '/signup-complete')
              .then((_) {
                print('Navigation completed');
              })
              .catchError((error) {
                print('Navigation error: $error');
              });
        } else {
          print('Initial URI path does not match /signup-complete');
        }
      } else {
        print('Initial URI is null');
      }
    } catch (e) {
      print('Error getting initial link: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri? uri) {
        print('Stream URI received: $uri');
        if (uri != null) {
          print('Stream URI Scheme: ${uri.scheme}');
          print('Stream URI Path: ${uri.path}');
          print('Stream URI Query: ${uri.query}');
          if (uri.path == '/signup-complete') {
            print(
              'Navigating to /signup-complete (Stream) with code: ${uri.queryParameters['code']}',
            );
            Navigator.pushNamed(context, '/signup-complete')
                .then((_) {
                  print('Stream navigation completed');
                })
                .catchError((error) {
                  print('Stream navigation error: $error');
                });
          } else {
            print('Stream URI path does not match /signup-complete');
          }
        } else {
          print('Stream URI is null');
        }
      },
      onError: (err) {
        print('Error in app_links: $err');
        print('Error details: ${err.toString()}');
      },
    );
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
        '/signup-complete': (context) => const SignupCompletePage(),
        '/login': (context) => const Placeholder(),
      },
    );
  }
}
