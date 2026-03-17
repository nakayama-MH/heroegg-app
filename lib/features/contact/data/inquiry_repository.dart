import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';

class InquiryRepository {
  InquiryRepository(this._client);

  final SupabaseClient _client;

  Future<void> submitInquiry({
    required String? userId,
    required String inquiryType,
    required String name,
    required String email,
    required String subject,
    required String message,
  }) async {
    await _client.from(SupabaseConstants.inquiriesTable).insert({
      // ignore: use_null_aware_elements
      if (userId != null) 'user_id': userId,
      'inquiry_type': inquiryType,
      'name': name,
      'email': email,
      'subject': subject,
      'message': message,
      'status': 'new',
    });
  }
}
