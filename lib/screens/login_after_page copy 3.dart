import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';

class LoginAfterPage extends StatefulWidget {
  const LoginAfterPage({super.key});

  @override
  State<LoginAfterPage> createState() => _LoginAfterPageState();
}

class _LoginAfterPageState extends State<LoginAfterPage> {
  String? partnerId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPairStatus();
  }

  Future<void> _checkPairStatus() async {
    setState(() => isLoading = true);
    try {
      // セッションをリフレッシュ
      await supabase.auth.refreshSession();
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User is not authenticated');
      }
      final userId = user.id;
      print('Current user ID: $userId');

      print('Fetching pair data...');
      final pairData =
          await supabase
              .from('pairs')
              .select('user1_id, user2_id')
              .or('user1_id.eq.$userId,user2_id.eq.$userId')
              .maybeSingle();
      print('Pair data: $pairData');

      if (pairData == null) {
        print('Invoking random-match-user Edge Function...');
        final pairResponse = await supabase.functions.invoke(
          'random-match-user',
          body: {'userId': userId},
        );
        print('Pair response: ${pairResponse.data}');

        if (pairResponse.status != 200) {
          throw Exception('Failed to pair user: ${pairResponse.data}');
        }

        final responseData = pairResponse.data as Map<String, dynamic>;
        final message = responseData['message'];

        if (message == 'No unpaired users available') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('マッチする相手がいません（順番待ち）'),
              backgroundColor: Colors.orange,
            ),
          );
        } else if (message == 'Pair created') {
          final newPartnerId = responseData['partnerId'] as String;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('誰かとマッチしました！パートナー: $newPartnerId'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            partnerId = newPartnerId;
          });
        }
      } else {
        final existingPartnerId =
            pairData['user1_id'] == userId
                ? pairData['user2_id']
                : pairData['user1_id'];

        // 相手のユーザー情報を取得
        final partnerData =
            await supabase
                .from('users')
                .select('user_name')
                .eq('id', existingPartnerId)
                .maybeSingle();

        final partnerUserName =
            partnerData?['user_name'] as String? ?? 'Unknown';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('既に誰かとマッチ済みです。パートナー: $partnerUserName'),
            backgroundColor: Colors.blue,
          ),
        );

        setState(() {
          partnerId = existingPartnerId;
        });
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ペア情報の取得に失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentSession?.user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('ユーザーが認証されていません')));
    }
    final userMetadata = user.userMetadata;
    final avatarUrl = userMetadata?['avatar_url'] as String?;
    final userName = userMetadata?['user_name'] as String? ?? 'unknown name';

    return Scaffold(
      appBar: AppBar(title: const Text('Login After')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
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
                SizedBox(
                  height: 64,
                  width: 64,
                  child: avatarUrl != null
                      ? Image.network(avatarUrl)
                      : const Icon(Icons.no_photography),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('user.name: $userName'),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: _showUpdateUserNameDialog,
                    ),
                  ],
                ),
                const Gap(18),
                Text('Email: ${user.email}', textAlign: TextAlign.center),
                const Gap(18),
                ElevatedButton(
                  onPressed: _signOut,
                  child: const Text('Sign out'),
                ),
                const Gap(18),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/upload');
                  },
                  child: const Text('食事写真をアップロード'),
                ),
                const Gap(18),
                Text(
                  partnerId == null ? 'ペア待機中…' : '現在のペア: $partnerId',
                  style: const TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }

  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unexpected Error. $error')),
        );
      }
    } finally {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  final _userNameController = TextEditingController();

  Future<void> _updateUserName() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User is not authenticated');
      }
      final userId = user.id;

      // 1. auth.users の user_name を更新
      await supabase.auth.updateUser(
        UserAttributes(
          data: {'user_name': _userNameController.text},
        ),
      );

      // 2. public.users を更新（Edge Function を使用）
      final response = await supabase.functions.invoke('update-public-user-name', body: {
        'userId': userId,
        'userName': _userNameController.text,
      });

      if (response.status != 200) {
        throw Exception('Failed to update public user name: ${response.data}');
      }

      // セッションをリフレッシュして最新の userMetadata を取得
      await supabase.auth.refreshSession();

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
}