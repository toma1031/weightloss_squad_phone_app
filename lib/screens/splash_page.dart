import 'package:flutter/material.dart';
import '../main.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool isLoading = true;
  String statusMessage = "スプラッシュページが読み込まれました";

  @override
  void initState() {
    super.initState();
    _redirect();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'スプラッシュ画面',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              statusMessage,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            if (isLoading) const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Future<void> _redirect() async {
    try {
      // 状態を更新して画面に表示
      setState(() {
        statusMessage = "認証状態を確認中...";
      });
      
      // デバッグ用に少し遅延を追加
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) {
        return;
      }

      final session = supabase.auth.currentSession;
      setState(() {
        statusMessage = session != null 
            ? "ログイン済み、リダイレクト中..." 
            : "未ログイン、リダイレクト中...";
      });
      
      // さらに少し遅延を追加して状態メッセージを確認できるようにする
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      
      if (session != null) {
        Navigator.of(context).pushReplacementNamed('/login-after');
      } else {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        statusMessage = "エラーが発生しました: $e";
        isLoading = false;
      });
    }
  }
}