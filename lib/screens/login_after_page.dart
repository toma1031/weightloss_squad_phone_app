import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import '../main.dart';
import 'meal_history_page.dart'; // MealHistoryPage をインポート
import 'partner_meal_history_page.dart'; // PartnerMealHistoryPage をインポート

class LoginAfterPage extends StatefulWidget {
  const LoginAfterPage({super.key});

  @override
  State<LoginAfterPage> createState() => _LoginAfterPageState();
}

class _LoginAfterPageState extends State<LoginAfterPage> {
  String? partnerId;
  String? partnerUserName; // ペアのユーザー名を保持する状態変数を追加
  bool isLoading = true;
  Timer? _inactiveCheckTimer;

  @override
  void initState() {
    super.initState();
    _checkBanStatus();
    _checkPairStatus();

    // リアルタイムサブスクリプション
    supabase.from('pairs').stream(primaryKey: ['id']).listen((
      List<Map<String, dynamic>> data,
    ) {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final hasPair = data.any(
        (pair) => pair['user1_id'] == user.id || pair['user2_id'] == user.id,
      );
      if (!hasPair) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ペアが解消されました。'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          partnerId = null;
          partnerUserName = null;
        });
      } else {
        // ペアが存在する場合、新しいパートナーの情報を取得
        final pair = data.firstWhere(
          (pair) => pair['user1_id'] == user.id || pair['user2_id'] == user.id,
        );
        final newPartnerId = pair['user1_id'] == user.id ? pair['user2_id'] : pair['user1_id'];

        // 相手のユーザー名を取得
        supabase
            .from('users')
            .select('user_name')
            .eq('id', newPartnerId)
            .single()
            .then((partnerData) {
          final newPartnerName = partnerData['user_name'] ?? 'Unknown';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('新しいパートナーとマッチングしました！パートナー: $newPartnerName'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            partnerId = newPartnerId;
            partnerUserName = newPartnerName;
          });
        });
      }
    });

    // 定期的に非アクティブユーザーをチェック（例：1時間ごと）
    _inactiveCheckTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      _checkInactiveUsers();
    });
  }

  Future<void> _checkBanStatus() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      const maxRetries = 3;
      for (var attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          final response = await supabase.functions.invoke(
            'check-ban-status',
            body: {'userId': user.id},
          );

          if (response.status != 200) {
            throw Exception('Failed to check ban status: ${response.data}');
          }

          final data = response.data as Map<String, dynamic>;
          final isBanned = data['isBanned'] as bool;
          final bannedUntil = data['bannedUntil'] as String?;

          if (isBanned) {
            await supabase.auth.signOut();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('あなたはBANされています。BAN解除日時: $bannedUntil'),
                backgroundColor: Colors.red,
              ),
            );
            Navigator.pushReplacementNamed(context, '/login');
          } else {
            // BAN されていない場合の SnackBar を表示
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('BANされていません。安心してご利用ください！'),
                backgroundColor: Colors.green,
              ),
            );
          }
          return; // 成功したらリトライを終了
        } catch (e) {
          print('Attempt $attempt of $maxRetries failed: $e');
          if (attempt == maxRetries) {
            print('Error checking ban status after $maxRetries attempts: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('BAN状態の確認に失敗しました: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          await Future.delayed(const Duration(seconds: 1)); // リトライ前に待機
        }
      }
    } catch (e) {
      print('Error checking ban status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('BAN状態の確認に失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> getUserPair() async {
    try {
      // 現在のペアを取得
      final pairData = await supabase
          .from('pairs')
          .select('id, user1_id, user2_id')
          .or('user1_id.eq.${supabase.auth.currentUser!.id},user2_id.eq.${supabase.auth.currentUser!.id}')
          .maybeSingle();

      if (pairData == null) {
        // ペアが存在しない場合
        return null;
      }

      // 相手ユーザーの ID を特定
      final partnerId = pairData['user1_id'] == supabase.auth.currentUser!.id
          ? pairData['user2_id']
          : pairData['user1_id'];

      // 相手ユーザーの BAN 状態を確認
      final partnerData = await supabase
          .from('users')
          .select('user_name, is_banned, banned_until')
          .eq('id', partnerId)
          .single();

      // BAN 判定
      bool isBanned = partnerData['is_banned'] == true;

      if (isBanned) {
        // 相手が BAN されている場合、ペアを削除
        try {
          final deleteResponse = await supabase
              .from('pairs')
              .delete()
              .eq('id', pairData['id'])
              .select()
              .maybeSingle();

          if (deleteResponse == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ペアは既に解除されています。'),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('相手がBANされたため、ペアが解除されました。'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } catch (deleteError) {
          print('ペア削除エラー: $deleteError');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ペアの解除に失敗しました: $deleteError'),
              backgroundColor: Colors.red,
            ),
          );
          return null;
        }
        return null;
      }

      // 相手が BAN されていない場合、ペア情報を返す
      return {
        'pairId': pairData['id'],
        'partnerId': partnerId,
        'partnerName': partnerData['user_name'] ?? 'Unknown',
      };
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

  Future<void> _checkInactiveUsers() async {
    try {
      const maxRetries = 3;
      for (var attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          // 既存の非アクティブユーザー処理
          final response = await http.post(
            Uri.parse(
              'https://mujcjzbysyssgycjfxju.supabase.co/functions/v1/check-inactive-users',
            ),
            headers: {'Content-Type': 'application/json'},
          );

          if (response.statusCode != 200) {
            throw Exception('Failed to check inactive users: ${response.body}');
          }

          // BAN されたユーザーのペアを解消
          final unpairResponse = await supabase.functions.invoke(
            'unpair-banned-users',
            body: {},
          );

          if (unpairResponse.status != 200) {
            throw Exception('Failed to unpair banned users: ${unpairResponse.data}');
          }

          print('Inactive users processed: ${response.body}');
          print('Unpair banned users response: ${unpairResponse.data}');
          return; // 成功したらリトライを終了
        } catch (e) {
          if (attempt == maxRetries) {
            print('Error checking inactive users after $maxRetries attempts: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('非アクティブユーザーのチェックに失敗しました: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          await Future.delayed(const Duration(seconds: 1)); // リトライ前に待機
        }
      }
    } catch (e) {
      print('Error checking inactive users: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('非アクティブユーザーのチェックに失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

      // getUserPair を使用してペア情報を取得（BAN チェックを含む）
      final pairInfo = await getUserPair();

      if (pairInfo == null) {
        // ペアが存在しない場合
        setState(() {
          partnerId = null;
          partnerUserName = null;
        });
      } else {
        // ペアが存在し、BAN されていない場合
        final existingPartnerId = pairInfo['partnerId'] as String;
        final partnerUserNameLocal = pairInfo['partnerName'] as String;

        // ユーザーが複数のペアを持っていないか確認
        final allPairs = await supabase
            .from('pairs')
            .select('id, user1_id, user2_id')
            .or('user1_id.eq.$userId,user2_id.eq.$userId')
            .order('created_at', ascending: false); // 最新のペアを優先

        if (allPairs.length > 1) {
          // 複数のペアが存在する場合、古いペアを削除
          final latestPair = allPairs[0];
          final oldPairs = allPairs.sublist(1);

          for (var oldPair in oldPairs) {
            await supabase
                .from('pairs')
                .delete()
                .eq('id', oldPair['id']);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('複数のペアが検出されました。古いペアを削除しました。'),
              backgroundColor: Colors.orange,
            ),
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('既に誰かとマッチ済みです。パートナー: $partnerUserNameLocal'),
            backgroundColor: Colors.blue,
          ),
        );

        setState(() {
          partnerId = existingPartnerId;
          partnerUserName = partnerUserNameLocal;
        });
      }
    } catch (e) {
      String errorMessage = 'ペア情報の取得に失敗しました: $e';
      if (e.toString().contains('infinite recursion')) {
        errorMessage = 'サーバーエラーが発生しました。管理者に連絡してください（無限再帰エラー）。';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
      setState(() {
        partnerId = null;
        partnerUserName = null;
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _requestPair() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User is not authenticated');
      }
      final userId = user.id;

      // 既にペアが存在するか確認（念のため）
      final pairInfo = await getUserPair();
      if (pairInfo != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('既にペアが存在します。'),
            backgroundColor: Colors.blue,
          ),
        );
        setState(() {
          partnerId = pairInfo['partnerId'] as String;
          partnerUserName = pairInfo['partnerName'] as String;
        });
        return;
      }

      // ペアが存在しない場合、新しいペアを作成
      bool pairedSuccessfully = false;
      int maxAttempts = 3; // 最大試行回数
      int attempt = 0;

      while (!pairedSuccessfully && attempt < maxAttempts) {
        final pairResponse = await supabase.functions.invoke(
          'random-match-user',
          body: {'userId': userId},
        );

        if (pairResponse.status != 200) {
          throw Exception('Failed to pair user: ${pairResponse.data}');
        }

        final responseData = pairResponse.data as Map<String, dynamic>;
        final message = responseData['message'];

        if (message == 'No unpaired users available') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('待機ユーザーがいません。しばらくしてからペア取得ボタンをタップしてみてください！'),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() {
            partnerId = null;
            partnerUserName = null;
          });
          pairedSuccessfully = true; // マッチング対象がない場合はループを終了
        } else if (message == 'Pair created') {
          final newPartnerId = responseData['partnerId'] as String;
          final newPartnerUserName = responseData['partnerName'] as String? ?? 'Unknown';

          // BAN 状態を再確認
          final partnerData = await supabase
              .from('users')
              .select('is_banned')
              .eq('id', newPartnerId)
              .single();

          bool isBanned = partnerData['is_banned'] == true;

          if (isBanned) {
            // BAN されている場合、ペアを削除して再試行
            final pairData = await supabase
                .from('pairs')
                .select('id')
                .or('user1_id.eq.$userId,user2_id.eq.$userId')
                .maybeSingle();

            if (pairData != null) {
              await supabase
                  .from('pairs')
                  .delete()
                  .eq('id', pairData['id']);
            }

            attempt++;
            if (attempt == maxAttempts) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('マッチングに失敗しました。BANされたユーザーとのペアリングを防ぎました。'),
                  backgroundColor: Colors.red,
                ),
              );
              setState(() {
                partnerId = null;
                partnerUserName = null;
              });
              pairedSuccessfully = true; // 試行回数上限に達したら終了
            }
            continue; // 再試行
          }

          // ユーザーが複数のペアを持っていないか確認
          final allPairs = await supabase
              .from('pairs')
              .select('id, user1_id, user2_id')
              .or('user1_id.eq.$userId,user2_id.eq.$userId')
              .order('created_at', ascending: false); // 最新のペアを優先

          if (allPairs.length > 1) {
            // 複数のペアが存在する場合、古いペアを削除
            final latestPair = allPairs[0];
            final oldPairs = allPairs.sublist(1);

            for (var oldPair in oldPairs) {
              await supabase
                  .from('pairs')
                  .delete()
                  .eq('id', oldPair['id']);
            }

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('複数のペアが検出されました。古いペアを削除しました。'),
                backgroundColor: Colors.orange,
              ),
            );
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('「$newPartnerUserName」が決まりました。'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            partnerId = newPartnerId;
            partnerUserName = newPartnerUserName;
          });
          pairedSuccessfully = true;
        }
      }
    } catch (e) {
      String errorMessage = 'ペアの取得に失敗しました: $e';
      if (e.toString().contains('infinite recursion')) {
        errorMessage = 'サーバーエラーが発生しました。管理者に連絡してください（無限再帰エラー）。';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
      setState(() {
        partnerId = null;
        partnerUserName = null;
      });
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
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context)
                        .pushNamed('/meal_history'); // MealHistoryPage への遷移ボタン
                  },
                  child: const Text('食事履歴を見る'),
                ),
                const Gap(18),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      '/partner_meal_history',
                    ); // PartnerMealHistoryPage への遷移ボタン
                  },
                  child: const Text('パートナーの食事履歴を見る'),
                ),
                const Gap(18),
                if (partnerId == null) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'ペア取得ボタンをタップして、食事管理パートナーを決めましょう！',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Gap(8),
                  ElevatedButton(
                    onPressed: _requestPair,
                    child: const Text('ペアを取得'),
                  ),
                  const Gap(18),
                ],
                Text(
                  partnerId == null ? 'ペア待機中…' : '現在のペア: $partnerUserName',
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
            SnackBar(content: Text('Unexpected Error. $error')));
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
        UserAttributes(data: {'user_name': _userNameController.text}),
      );

      // 2. public.users を更新（Edge Function を使用）
      final response = await supabase.functions.invoke(
        'update-public-user-name',
        body: {'userId': userId, 'userName': _userNameController.text},
      );

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
    _inactiveCheckTimer?.cancel();
    _userNameController.dispose();
    super.dispose();
  }
}