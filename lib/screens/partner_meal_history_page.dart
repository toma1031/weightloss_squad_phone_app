import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../main.dart';

class PartnerMealHistoryPage extends StatefulWidget {
  const PartnerMealHistoryPage({super.key});

  @override
  State<PartnerMealHistoryPage> createState() => _PartnerMealHistoryPageState();
}

class _PartnerMealHistoryPageState extends State<PartnerMealHistoryPage> {
  List<Map<String, dynamic>> dailyMeals = [];
  Map<int, List<Map<String, dynamic>>> mealsByDailyMeal = {};
  Map<int, List<Map<String, dynamic>>> commentsByDailyMeal = {};
  Map<int, TextEditingController> commentControllers = {};
  Map<int, bool> isPostingComment = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPartnerMealHistory();
  }

  Future<void> _fetchPartnerMealHistory() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User is not authenticated');
      }
      final userId = user.id;
      print('Current user ID: $userId');

      // ペア情報を取得
      print('Fetching pair data...');
      final pairData =
          await supabase
              .from('pairs')
              .select()
              .or('user1_id.eq.$userId,user2_id.eq.$userId')
              .maybeSingle();
      print('Pair data: $pairData');

      if (pairData == null) {
        throw Exception('ペアが見つかりません');
      }

      // パートナーの user_id を取得
      final partnerId =
          pairData['user1_id'] == userId
              ? pairData['user2_id']
              : pairData['user1_id'];
      print('Partner ID: $partnerId');

      // パートナーの daily_meals を取得
      print('Fetching daily_meals for partner...');
      final dailyMealData = await supabase
          .from('daily_meals')
          .select()
          .eq('user_id', partnerId)
          .order('date', ascending: false);
      print('Daily meal data: $dailyMealData');

      if (dailyMealData.isEmpty) {
        print('No daily meals found for partner.');
        setState(() {
          dailyMeals = [];
          mealsByDailyMeal = {};
          commentsByDailyMeal = {};
          commentControllers = {};
          isPostingComment = {};
        });
        return;
      }

      // 関連する meals を取得
      final dailyMealIds = dailyMealData.map((dm) => dm['id'] as int).toList();
      print('Daily meal IDs: $dailyMealIds');
      final mealData = await supabase
          .from('meals')
          .select()
          .inFilter('daily_meal_id', dailyMealIds)
          .order('created_at', ascending: true);
      print('Meal data: $mealData');

      // meals を daily_meal_id ごとにマッピング
      final mealsMap = <int, List<Map<String, dynamic>>>{};
      for (var meal in mealData) {
        final dailyMealId = meal['daily_meal_id'] as int;
        if (!mealsMap.containsKey(dailyMealId)) {
          mealsMap[dailyMealId] = [];
        }
        mealsMap[dailyMealId]!.add(meal);
      }

      // 関連する comments を取得
      final commentData = await supabase
          .from('comments')
          .select()
          .inFilter('daily_meal_id', dailyMealIds);
      print('Comment data: $commentData');

      // comments を daily_meal_id ごとにマッピング
      final commentMap = <int, List<Map<String, dynamic>>>{};
      for (var comment in commentData) {
        final dailyMealId = comment['daily_meal_id'] as int;
        if (!commentMap.containsKey(dailyMealId)) {
          commentMap[dailyMealId] = [];
        }
        commentMap[dailyMealId]!.add(comment);
      }

      // コメント入力用のコントローラーを初期化
      final controllers = <int, TextEditingController>{};
      final postingMap = <int, bool>{};
      for (var dailyMeal in dailyMealData) {
        final dailyMealId = dailyMeal['id'] as int;
        controllers[dailyMealId] = TextEditingController();
        postingMap[dailyMealId] = false;
      }

      setState(() {
        dailyMeals = dailyMealData.cast<Map<String, dynamic>>();
        mealsByDailyMeal = mealsMap;
        commentsByDailyMeal = commentMap;
        commentControllers = controllers;
        isPostingComment = postingMap;
      });
    } catch (e) {
      print('Error fetching partner meal history: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('パートナーの食事履歴の取得に失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _postComment(int dailyMealId) async {
    final controller = commentControllers[dailyMealId];
    if (controller == null || controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('コメントを入力してください')));
      return;
    }

    setState(() {
      isPostingComment[dailyMealId] = true;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User is not authenticated');
      }

      // comments テーブルに新しいコメントを挿入
      await supabase.from('comments').insert({
        'daily_meal_id': dailyMealId,
        'user_id': user.id,
        'content': controller.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

      // コメント投稿後にデータを再取得
      await _fetchPartnerMealHistory();

      // 入力欄をクリア
      controller.clear();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('コメントを投稿しました')));
    } catch (e) {
      print('Error posting comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('コメントの投稿に失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isPostingComment[dailyMealId] = false;
      });
    }
  }

  @override
  void dispose() {
    // コントローラーを破棄
    commentControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('パートナーの食事履歴')),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : dailyMeals.isEmpty
              ? const Center(child: Text('パートナーの食事データがありません'))
              : ListView.builder(
                itemCount: dailyMeals.length,
                itemBuilder: (context, index) {
                  final dailyMeal = dailyMeals[index];
                  final dailyMealId = dailyMeal['id'] as int;
                  final date = DateFormat(
                    'yyyy-MM-dd',
                  ).format(DateTime.parse(dailyMeal['date']));
                  final mealsForDay = mealsByDailyMeal[dailyMealId] ?? [];
                  final commentsForDay = commentsByDailyMeal[dailyMealId] ?? [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey, width: 1),
                            ),
                          ),
                          child: Text(
                            date,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      ...mealsForDay.map((meal) {
                        final createdAt = DateTime.parse(meal['created_at']);
                        final time = DateFormat('HH:mm').format(createdAt);

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                meal['image_url'] != null &&
                                        meal['image_url'].isNotEmpty
                                    ? Image.network(
                                      meal['image_url'],
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        print('Image load error: $error');
                                        return const Icon(Icons.broken_image);
                                      },
                                      loadingBuilder: (
                                        context,
                                        child,
                                        loadingProgress,
                                      ) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return const CircularProgressIndicator();
                                      },
                                    )
                                    : const Icon(
                                      Icons.no_photography,
                                      size: 100,
                                    ),
                                const Gap(16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '食事の種類: ${meal['title']}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text('時間: $time'),
                                      const Gap(8),
                                      Text(
                                        '説明: ${meal['description'] ?? '説明なし'}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'パートナーへの感想:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Gap(8),
                            commentsForDay.isEmpty
                                ? const Text('まだコメントがありません')
                                : Column(
                                  children:
                                      commentsForDay.map((comment) {
                                        final commentTime = DateFormat(
                                          'yyyy-MM-dd HH:mm',
                                        ).format(
                                          DateTime.parse(comment['created_at']),
                                        );
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8.0,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                comment['content'],
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                '投稿日時: $commentTime',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                ),
                            const Gap(16),
                            // コメント投稿用の入力欄とボタン
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: commentControllers[dailyMealId],
                                    decoration: const InputDecoration(
                                      labelText: 'コメントを入力',
                                      border: OutlineInputBorder(),
                                    ),
                                    maxLines: 2,
                                  ),
                                ),
                                const Gap(8),
                                ElevatedButton(
                                  onPressed:
                                      isPostingComment[dailyMealId] == true
                                          ? null
                                          : () => _postComment(dailyMealId),
                                  child:
                                      isPostingComment[dailyMealId] == true
                                          ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(),
                                          )
                                          : const Text('投稿'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
    );
  }
}
