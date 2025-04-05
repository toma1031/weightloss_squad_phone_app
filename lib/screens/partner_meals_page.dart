import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class PartnerMealsPage extends StatefulWidget {
  const PartnerMealsPage({super.key});

  @override
  PartnerMealsPageState createState() => PartnerMealsPageState();
}

class PartnerMealsPageState extends State<PartnerMealsPage> {
  List<Map<String, dynamic>> partnerMeals = [];
  bool isLoading = true;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPartnerMeals();
  }

  Future<void> _fetchPartnerMeals() async {
    setState(() => isLoading = true);
    try {
      // 現在のユーザーが属するペアを取得
      final userId = supabase.auth.currentUser!.id;
      final pairResponse = await supabase
          .from('pairs')
          .select('user1_id, user2_id')
          .or('user1_id.eq.$userId,user2_id.eq.$userId')
          .maybeSingle();

      if (pairResponse == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ペアが見つかりません')),
        );
        setState(() {
          isLoading = false;
          partnerMeals = [];
        });
        return;
      }

      final partnerId = pairResponse['user1_id'] == userId
          ? pairResponse['user2_id']
          : pairResponse['user1_id'];

      // 前日の日付を取得
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayDate = DateTime(yesterday.year, yesterday.month, yesterday.day).toIso8601String().split('T')[0];

      // ペアの相手の前日の daily_meals を取得
      final dailyMealsResponse = await supabase
          .from('daily_meals')
          .select('id, user_id, date, meals (id, title, description, image_url), comments (id, user_id, content, created_at)')
          .eq('user_id', partnerId)
          .eq('date', yesterdayDate);

      setState(() {
        partnerMeals = dailyMealsResponse;
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('データの取得に失敗しました: $e')),
      );
      setState(() {
        isLoading = false;
        partnerMeals = [];
      });
    }
  }

  Future<void> _postComment(int dailyMealId) async {
    if (_commentController.text.isEmpty) return;

    try {
      await supabase.from('comments').insert({
        'daily_meal_id': dailyMealId,
        'user_id': supabase.auth.currentUser!.id,
        'content': _commentController.text,
        'created_at': DateTime.now().toIso8601String(),
      });

      _commentController.clear();
      _fetchPartnerMeals(); // コメント投稿後にデータを再取得
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('コメントを投稿しました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('コメントの投稿に失敗しました: $e')),
      );
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ペアの食事'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : partnerMeals.isEmpty
              ? const Center(child: Text('前日の食事データがありません'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: partnerMeals.length,
                  itemBuilder: (context, index) {
                    final dailyMeal = partnerMeals[index];
                    final meals = dailyMeal['meals'] as List<dynamic>;
                    final comments = dailyMeal['comments'] as List<dynamic>;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('日付: ${dailyMeal['date']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ...meals.map((meal) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('タイトル: ${meal['title']}', style: const TextStyle(fontSize: 16)),
                                    Text('説明: ${meal['description'] ?? ''}'),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        meal['image_url'],
                                        height: 150,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const Text('画像の読み込みに失敗しました'),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                )),
                            const Divider(),
                            const Text('コメント', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ...comments.map((comment) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Text('${comment['content']} (${comment['created_at'].split('T')[0]})'),
                                )),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _commentController,
                              decoration: const InputDecoration(
                                labelText: 'コメントを入力',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => _postComment(dailyMeal['id']),
                              child: const Text('コメントを投稿'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}