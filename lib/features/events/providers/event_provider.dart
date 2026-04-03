import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import '../data/event_repository.dart';
import '../models/event_model.dart';

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(ref.watch(supabaseClientProvider));
});

final eventsProvider = FutureProvider<List<Event>>((ref) async {
  final repository = ref.watch(eventRepositoryProvider);
  return repository.getEvents();
});

final eventDetailProvider =
    FutureProvider.family<Event, String>((ref, id) async {
  final repository = ref.watch(eventRepositoryProvider);
  return repository.getEvent(id);
});

final eventFormProvider =
    StateNotifierProvider<EventFormNotifier, AsyncValue<void>>((ref) {
  return EventFormNotifier(ref.watch(eventRepositoryProvider), ref);
});

class EventFormNotifier extends StateNotifier<AsyncValue<void>> {
  EventFormNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  final EventRepository _repository;
  final Ref _ref;

  Future<void> createEvent(Event event) async {
    state = const AsyncValue.loading();
    try {
      await _repository.createEvent(event);
      _ref.invalidate(eventsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateEvent(String id, Event event) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateEvent(id, event);
      _ref.invalidate(eventsProvider);
      _ref.invalidate(eventDetailProvider(id));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteEvent(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteEvent(id);
      _ref.invalidate(eventsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
