import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../main.dart';

class MealHistoryPage extends StatefulWidget {
  const MealHistoryPage({super.key});

  @override
  State<MealHistoryPage> createState() => _MealHistoryPageState();
}

class _MealHistoryPageState extends State<MealHistoryPage> {
  List<Map<String, dynamic>> dailyMeals = [];
  Map<int, List<Map<String, dynamic>>> mealsByDailyMeal = {};
  Map<int, List<Map<String, dynamic>>> commentsByDailyMeal = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMealHistory();
  }

  Future<void> _fetchMealHistory() async {
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
        throw Exception('ペアが見つかりません。');
      }

      final partnerId =
          pairData['user1_id'] == userId
              ? pairData['user2_id']
              : pairData['user1_id'];
      print('Partner ID: $partnerId');

      // 自分の daily_meals を取得
      print('Fetching daily_meals for user...');
      final dailyMealData = await supabase
          .from('daily_meals')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false);
      print('Daily meal data: $dailyMealData');

      if (dailyMealData.isEmpty) {
        setState(() {
          dailyMeals = [];
          mealsByDailyMeal = {};
          commentsByDailyMeal = {};
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

      // 関連する comments を取得（パートナーからのコメントのみ）
      print('Fetching comments for daily_meals...');
      final commentData = await supabase
          .from('comments')
          .select()
          .inFilter('daily_meal_id', dailyMealIds)
          .eq('user_id', partnerId); // パートナーが投稿したコメントのみ取得
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

      setState(() {
        dailyMeals = dailyMealData.cast<Map<String, dynamic>>();
        mealsByDailyMeal = mealsMap;
        commentsByDailyMeal = commentMap;
      });
    } catch (e) {
      print('Error fetching meal history: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('食事履歴の取得に失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('食事履歴')),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : dailyMeals.isEmpty
              ? const Center(child: Text('まだ食事データがありません'))
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

                        // デバッグ用に image_url をログに出力
                        print('Meal image_url: ${meal['image_url']}');

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
                                      // description を表示
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
                              'パートナーからの感想:',
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
