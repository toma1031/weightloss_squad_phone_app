import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';  // 追加

import '../main.dart';

class LoginAfterPage extends StatefulWidget {
  const LoginAfterPage({super.key});

  @override
  State<LoginAfterPage> createState() => _LoginAfterPageState();
}

class _LoginAfterPageState extends State<LoginAfterPage> {
  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentSession!.user;
    final userMetadata = user.userMetadata;
    final avatarUrl = userMetadata?['avatar_url'] as String?;
    final userName = userMetadata?['user_name'] as String? ?? 'unknown name';
    // final userMetadataKeys =['email', 'email_verified', 'iss', 'full_name', 'provider_id', 'sub' , 'user_name'];

    return Scaffold(
      appBar: AppBar(title: const Text('Login After')),
      body: ListView(
        children: [
          // ここ変更
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'ログイン成功！',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // ここ変更ここまで
          SizedBox(
            height: 64,
            width: 64,
            child:
                avatarUrl != null
                    ? Image.network(avatarUrl)
                    : const Icon(Icons.no_photography),
          ),
          Text('user.name: $userName'),
          if (userName == 'unknown name')
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _showUpdateUserNameDialog,
            ),
          const Gap(18),
          Text('Email: ${user.email}'), // 変更箇所
          const Gap(18),
          Text('user: $user'),
          const Gap(18),
          ElevatedButton(onPressed: _signOut, child: const Text('Sign out')),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    // setState(() {
    //   _loading = true;
    // });

    try {
      await supabase.auth.signOut();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unexpected Error. $error')));
      }
    } finally {
      if (mounted) {
        // setState(() {
        //   _loading = false;
        // });
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  // ユーザーネームアップデート箇所
  final _userNameController = TextEditingController();

  Future<void> _updateUserName() async {
    try {
      await supabase.auth.updateUser(
        UserAttributes(  // ここを修正
          data: {'user_name': _userNameController.text},
        ),
      );
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ユーザー名を更新しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showUpdateUserNameDialog() async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ユーザー名を設定'),
          content: TextField(
            controller: _userNameController,
            decoration: const InputDecoration(
              labelText: '新しいユーザー名',
              hintText: 'ユーザー名を入力してください',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _updateUserName();
              },
              child: const Text('更新'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _userNameController.dispose();
    super.dispose();
  }

  // ユーザーネームアップデート箇所ここまで
}
