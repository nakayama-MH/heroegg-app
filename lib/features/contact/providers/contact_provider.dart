import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import '../data/inquiry_repository.dart';

final inquiryRepositoryProvider = Provider<InquiryRepository>((ref) {
  return InquiryRepository(ref.watch(supabaseClientProvider));
});

final contactSubmitProvider =
    StateNotifierProvider<ContactSubmitNotifier, AsyncValue<void>>((ref) {
  return ContactSubmitNotifier(
    ref.watch(inquiryRepositoryProvider),
    ref,
  );
});

class ContactSubmitNotifier extends StateNotifier<AsyncValue<void>> {
  ContactSubmitNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  final InquiryRepository _repository;
  final Ref _ref;

  Future<void> submit({
    required String inquiryType,
    required String name,
    required String email,
    required String subject,
    required String message,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(currentUserProvider);
      await _repository.submitInquiry(
        userId: user?.id,
        inquiryType: inquiryType,
        name: name,
        email: email,
        subject: subject,
        message: message,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}
