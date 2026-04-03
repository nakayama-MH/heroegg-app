import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../models/event_model.dart';

class EventRepository {
  EventRepository(this._client);

  final SupabaseClient _client;

  /// 全イベント取得（upcoming → completed の順）
  Future<List<Event>> getEvents() async {
    final response = await _client
        .from(SupabaseConstants.peetixEventsTable)
        .select()
        .neq('status', 'cancelled')
        .order('event_date', ascending: true);

    return (response as List)
        .map((json) => Event.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 今後のイベントのみ
  Future<List<Event>> getUpcomingEvents() async {
    final response = await _client
        .from(SupabaseConstants.peetixEventsTable)
        .select()
        .eq('status', 'active')
        .gte('event_date', DateTime.now().toIso8601String())
        .order('event_date', ascending: true);

    return (response as List)
        .map((json) => Event.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// イベント1件取得
  Future<Event> getEvent(String id) async {
    final response = await _client
        .from(SupabaseConstants.peetixEventsTable)
        .select()
        .eq('id', id)
        .single();

    return Event.fromJson(response);
  }

  /// イベント作成
  Future<Event> createEvent(Event event) async {
    final data = event.toJson();
    data['created_by'] = _client.auth.currentUser!.id;

    final response = await _client
        .from(SupabaseConstants.peetixEventsTable)
        .insert(data)
        .select()
        .single();

    return Event.fromJson(response);
  }

  /// イベント更新
  Future<Event> updateEvent(String id, Event event) async {
    final response = await _client
        .from(SupabaseConstants.peetixEventsTable)
        .update(event.toJson())
        .eq('id', id)
        .select()
        .single();

    return Event.fromJson(response);
  }

  /// イベント削除（ステータスをcancelledに変更）
  Future<void> deleteEvent(String id) async {
    await _client
        .from(SupabaseConstants.peetixEventsTable)
        .update({'status': 'cancelled'})
        .eq('id', id);
  }

  /// イベント画像アップロード
  Future<String> uploadEventImage(Uint8List bytes, String ext) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'events/$timestamp.$ext';
    final mimeExt = ext == 'jpg' ? 'jpeg' : ext;

    await _client.storage.from('event-images').uploadBinary(
          path,
          bytes,
          fileOptions:
              FileOptions(upsert: true, contentType: 'image/$mimeExt'),
        );

    return _client.storage.from('event-images').getPublicUrl(path);
  }
}
