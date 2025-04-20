import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../main.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  UploadPageState createState() => UploadPageState();
}

class UploadPageState extends State<UploadPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  XFile? _image;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedImage = await picker.pickImage(
        source: ImageSource.gallery,
        maxHeight: 1000,
        maxWidth: 1000,
      );

      if (pickedImage != null) {
        setState(() {
          _image = pickedImage;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('画像の選択に失敗しました: $e')));
      }
    }
  }

  Future<void> _logout() async {
    try {
      await supabase.auth.signOut();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ログアウトしました')));
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ログアウトに失敗しました: $e')));
    }
  }

  Future<void> _uploadImage() async {
    // 画像の選択チェック
    if (_image == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('画像を選択してください')));
      return;
    }

    // タイトルの入力チェック
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('タイトルを入力してください')));
      return;
    }

    // ログイン状態のチェック
    if (supabase.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインしてください。ログアウト後、再度ログインしてください。')),
      );
      await _logout();
      return;
    }

    // セッションをリフレッシュしてトークンを最新に
    try {
      await supabase.auth.refreshSession();
      print('Refreshed user ID: ${supabase.auth.currentUser?.id}');
    } catch (e) {
      print('Session refresh error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('セッションの更新に失敗しました。再度ログインしてください。')),
      );
      await _logout();
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 画像をSupabase Storageにアップロード
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${_image!.name}';
      final filePath = 'uploads/$fileName';

      await supabase.storage
          .from('meal-photos')
          .upload(filePath, File(_image!.path));

      // 公開URLを取得
      final imageUrl = supabase.storage
          .from('meal-photos')
          .getPublicUrl(filePath);

      // ユーザーIDを取得
      final userId = supabase.auth.currentUser!.id;

      // 今日の日付を取得（yyyy-MM-dd 形式）
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // ここ変更: ユーザーが属するペアを取得
      final pair =
          await supabase
              .from('pairs')
              .select('id')
              .or('user1_id.eq.$userId,user2_id.eq.$userId')
              .maybeSingle();

      if (pair == null) {
        throw Exception('ペアが見つかりません。');
      }

      // daily_meals に今日のエントリが存在するか確認
      final dailyMealData =
          await supabase
              .from('daily_meals')
              .select()
              .eq('user_id', userId)
              .eq('date', today)
              .maybeSingle();

      int dailyMealId; // int 型として扱う
      if (dailyMealData == null) {
        // daily_meals にエントリを作成
        final dailyMealResponse =
            await supabase
                .from('daily_meals')
                .insert({
                  'user_id': userId,
                  'date': today,
                  'created_at': DateTime.now().toIso8601String(),
                  'pair_id': pair['id'], // ここ変更: pair_id を設定
                })
                .select()
                .single();
        dailyMealId = dailyMealResponse['id'] as int; // int として取得
      } else {
        dailyMealId = dailyMealData['id'] as int; // int として取得
      }

      // meals テーブルにデータを挿入
      final data = {
        'daily_meal_id': dailyMealId, // int 値をそのまま使用
        'user_id': userId,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'image_url': imageUrl,
        'created_at': DateTime.now().toIso8601String(),
      };
      print('Inserting data into meals: $data');

      await supabase.from('meals').insert(data);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('アップロードが完了しました')));
        // フォームをリセット
        _titleController.clear();
        _descriptionController.clear();
        setState(() => _image = null);
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        if (e.code == '42501') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('アクセス権限がありません。ログアウト後、再度ログインしてください。')),
          );
          await _logout();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('アップロードに失敗しました: ${e.message}')),
          );
        }
        print('PostgrestException: $e');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('アップロードに失敗しました: $e')));
      }
      print('Unexpected error: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('食事写真のアップロード')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isUploading ? null : _pickImage,
              child: const Text('写真を選択'),
            ),
            if (_image != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_image!.path),
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'タイトル',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '説明',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isUploading ? null : _uploadImage,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child:
                  _isUploading
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(),
                      )
                      : const Text('アップロード'),
            ),
          ],
        ),
      ),
    );
  }
}
