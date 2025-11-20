import 'package:supabase_flutter/supabase_flutter.dart';

class HabitRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Stream<List<Map<String, dynamic>>> getHabitsStream(String userId) {
    return _client
        .from('habits')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at');
  }

  Stream<List<Map<String, dynamic>>> getRecentLogsStream(String userId) {
    return _client
        .from('habit_logs')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('completed_at', ascending: false)
        .limit(50);
  }

  Future<void> completeHabitInteraction(String habitId, String userId) async {
    await _client.from('habit_logs').insert({
      'habit_id': habitId,
      'user_id': userId,
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    });

    await _client.rpc('increment_points', params: {'row_id': userId});

    await _client.rpc('update_user_streak', params: {'user_uuid': userId});
  }

  Future<void> deleteHabit(String habitId) async {
    await _client.from('habits').delete().eq('id', habitId);
  }
}