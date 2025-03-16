import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupCompletePage extends StatefulWidget {
  final String? code;

  const SignupCompletePage({Key? key, this.code}) : super(key: key);

  @override
  _SignupCompletePageState createState() => _SignupCompletePageState();
}

class _SignupCompletePageState extends State<SignupCompletePage> {
  bool _isVerifying = false;
  bool _isVerified = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _verifyEmailWithCode();
  }

  Future<void> _verifyEmailWithCode() async {
    if (widget.code == null) {
      setState(() {
        _errorMessage = '確認コードが見つかりませんでした。';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      // Supabaseでコードを確認
      final response = await Supabase.instance.client.auth.verifyOTP(
        token: widget.code!,
        type: OtpType.signup,
      );

      if (response.session != null) {
        setState(() {
          _isVerified = true;
          _isVerifying = false;
        });
      } else {
        setState(() {
          _errorMessage = '確認に失敗しました。リンクが無効か期限切れの可能性があります。';
          _isVerifying = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '確認中にエラーが発生しました: ${e.toString()}';
        _isVerifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('アカウント確認')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isVerifying) const CircularProgressIndicator(),
              if (_isVerified)
                const Column(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 80),
                    SizedBox(height: 20),
                    Text(
                      'メールアドレスが確認されました！',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text('アカウントの設定が完了しました。アプリを使い始めることができます。'),
                  ],
                ),
              if (_errorMessage != null)
                Column(
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 80),
                    SizedBox(height: 20),
                    Text(
                      'エラーが発生しました',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(_errorMessage!),
                  ],
                ),
              if (_isVerified || _errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed(
                        _isVerified ? '/login' : '/signup',
                      );
                    },
                    child: Text(_isVerified ? 'ログインへ進む' : '登録画面に戻る'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
