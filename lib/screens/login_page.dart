import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz; // ここ変更（タイムゾーン）
import 'package:timezone/data/latest.dart' as tz; // ここ変更（タイムゾーン）

import '../main.dart';
import 'my_text_field.dart';

typedef FutureCallback<T> = Future<T> Function();

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  var _redirecting = false;
  var _isLoading = false;
  late final StreamSubscription<AuthState> _authStateSubscription;
  StreamSubscription? _deepLinkSubscription; // ディープリンク用のサブスクリプション

  final _magicLinkEmailController = TextEditingController(text: '');

  get linkStream => null;

  @override
  void initState() {
    super.initState();

    // タイムゾーンの初期化
    tz.initializeTimeZones();

    // ディープリンクの初期化
    _initDeepLink();

    // 認証状態の変更を監視
    _authStateSubscription = supabase.auth.onAuthStateChange.listen((
      event,
    ) async {
      debugPrint('Auth state changed: ${event.event.toString()}');
      if (_redirecting) {
        return;
      }
      final session = event.session;
      if (session != null) {
        _redirecting = true;

        // サインアップ/ログイン後に users レコードを作成
        final userId = session.user.id;
        await _createUserRecord(userId);

        Navigator.of(context).pushReplacementNamed('/login-after');
      }
    });
  }

  // ディープリンクの初期化
  Future<void> _initDeepLink() async {
    // 初回起動時にディープリンクをチェック
    try {
      final initialLink = await getInitialLink();
      if (initialLink != null) {
        debugPrint('Initial deep link: $initialLink');
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      debugPrint('Error getting initial deep link: $e');
    }

    // アプリがフォアグラウンドにあるときにディープリンクを監視
    _deepLinkSubscription = linkStream.listen(
      (String? link) {
        if (link != null) {
          debugPrint('Deep link received: $link');
          _handleDeepLink(link);
        }
      },
      onError: (err) {
        debugPrint('Error in deep link stream: $err');
      },
    );
  }

  // ディープリンクを処理
  void _handleDeepLink(String link) {
    // Supabase がリダイレクトしてきたリンクを処理
    if (link.contains('io.supabase.weightlosssquad://login-callback')) {
      // 認証状態が更新されるのを待つ
      // `onAuthStateChange` イベントが発火するはずなので、ここでは特に処理を追加しない
    }
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    _deepLinkSubscription?.cancel();
    _magicLinkEmailController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> getUserPair() async {
    try {
      // ユーザーの BAN 状態を確認
      final userData =
          await supabase
              .from('users')
              .select('is_banned, banned_until')
              .eq('id', supabase.auth.currentUser!.id)
              .single();

      if (userData['is_banned'] == true &&
          DateTime.parse(userData['banned_until']).isAfter(DateTime.now())) {
        throw Exception('あなたはBANされています。ペアを表示できません。');
      }

      // ペアデータを取得
      final pairData =
          await supabase
              .from('pairs')
              .select()
              .or(
                'user1_id.eq.${supabase.auth.currentUser!.id},user2_id.eq.${supabase.auth.currentUser!.id}',
              )
              .maybeSingle();

      return pairData;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ペアの取得に失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  Future<void> _createUserRecord(String userId) async {
    try {
      debugPrint('Creating user record for userId: $userId');

      // すでにレコードが存在するか確認
      final existingUser =
          await supabase
              .from('users')
              .select('id')
              .eq('id', userId)
              .maybeSingle();

      if (existingUser == null) {
        debugPrint('No existing user record found, inserting new record...');

        // ユーザーのタイムゾーンを取得 // ここ変更（タイムゾーン）
        final String userTimezone = tz.local.name; // 例: "Asia/Tokyo"
        debugPrint('Detected timezone from tz.local.name: $userTimezone');
        // バリデーション（有効なタイムゾーンか確認） // ここ変更（タイムゾーン）
        bool isValidTimezone(String timezone) {
          try {
            tz.getLocation(timezone);
            return true;
          } catch (e) {
            return false;
          }
        }

        final String timezoneToSave =
            isValidTimezone(userTimezone) ? userTimezone : 'UTC';
            debugPrint('Timezone to save: $timezoneToSave'); // ログ追加
        // ユーザーデータを挿入
        await supabase.from('users').insert({
          'id': userId,
          'user_name':
              'user_${DateTime.now().millisecondsSinceEpoch}', // デフォルトのユーザー名を設定
          'email':
              supabase.auth.currentUser?.email ??
              'unknown@example.com', // メールアドレスを設定
          'is_banned': false, // デフォルトでBANされていない状態
          'banned_until': null, // BAN期限は初期値としてnull
          'created_at': DateTime.now().toIso8601String(),
          'timezone': timezoneToSave, // タイムゾーンを保存
        });

        // 挿入後のレコードを確認
        final insertedUser =
            await supabase.from('users').select().eq('id', userId).single();

        debugPrint('User record created successfully: $insertedUser');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('ユーザーデータを登録しました'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      } else {
        debugPrint('User record already exists: $existingUser');
      }
    } catch (e, stackTrace) {
      debugPrint('Failed to create user record: $e\nStackTrace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('ユーザーデータの登録に失敗しました。再度お試しください。'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Weightloss Squad',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                Text(
                  'Sign in with magic link',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  decoration: const InputDecoration(
                    label: Text('email for magic link'),
                    hintText: 'Input your Email Address',
                  ),
                  controller: _magicLinkEmailController,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _signInMagicLink,
                  child: Text(
                    _isLoading ? 'Loading' : 'Sign in with magic link',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signInMagicLink() async {
    try {
      setState(() {
        _isLoading = true;
      });

      await supabase.auth.signInWithOtp(
        email: _magicLinkEmailController.text,
        shouldCreateUser: true,
        emailRedirectTo: 'io.supabase.weightlosssquad://login-callback/',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please check your email and log in!'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error has occurred: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  getInitialLink() {}
}
