import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import '../data/check_in_repository.dart';
import '../models/check_in.dart';

final checkInRepositoryProvider = Provider<CheckInRepository>((ref) {
  return CheckInRepository(ref.watch(supabaseClientProvider));
});

final activeCheckInProvider = FutureProvider<CheckIn?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final repository = ref.watch(checkInRepositoryProvider);
  return repository.getActiveCheckIn(user.id);
});

final checkInHistoryProvider = FutureProvider<List<CheckIn>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final repository = ref.watch(checkInRepositoryProvider);
  return repository.getCheckInHistory(user.id);
});

final checkInActionProvider =
    StateNotifierProvider<CheckInActionNotifier, AsyncValue<void>>((ref) {
  return CheckInActionNotifier(ref);
});

class CheckInActionNotifier extends StateNotifier<AsyncValue<void>> {
  CheckInActionNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<CheckIn> performCheckIn(String facilityId) async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(currentUserProvider);
      if (user == null) throw Exception('ログインが必要です');

      final repository = _ref.read(checkInRepositoryProvider);

      // 既にチェックイン中か確認
      final active = await repository.getActiveCheckIn(user.id);
      if (active != null) {
        throw Exception('既にチェックイン中です（${active.facilityName ?? "施設"}）');
      }

      // 施設の存在確認
      final exists = await repository.facilityExists(facilityId);
      if (!exists) {
        throw Exception('施設が見つかりません');
      }

      final checkIn = await repository.checkIn(user.id, facilityId);
      state = const AsyncValue.data(null);
      _ref.invalidate(activeCheckInProvider);
      return checkIn;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> performCheckOut(String checkInId) async {
    state = const AsyncValue.loading();
    try {
      final repository = _ref.read(checkInRepositoryProvider);
      await repository.checkOut(checkInId);
      state = const AsyncValue.data(null);
      _ref.invalidate(activeCheckInProvider);
      _ref.invalidate(checkInHistoryProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}
