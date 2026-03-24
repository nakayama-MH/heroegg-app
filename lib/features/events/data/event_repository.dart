import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../models/event_model.dart';

class EventRepository {
  EventRepository(this._client);

  final SupabaseClient _client;

  /// 全イベント取得（upcoming → completed の順）
  Future<List<PeetixEvent>> getEvents() async {
    final response = await _client
        .from(SupabaseConstants.peetixEventsTable)
        .select()
        .neq('status', 'cancelled')
        .order('event_date', ascending: true);

    return (response as List)
        .map((json) => PeetixEvent.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 今後のイベントのみ
  Future<List<PeetixEvent>> getUpcomingEvents() async {
    final response = await _client
        .from(SupabaseConstants.peetixEventsTable)
        .select()
        .eq('status', 'active')
        .gte('event_date', DateTime.now().toIso8601String())
        .order('event_date', ascending: true);

    return (response as List)
        .map((json) => PeetixEvent.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
