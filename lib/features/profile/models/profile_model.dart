class Profile {
  const Profile({
    required this.id,
    required this.email,
    this.displayName,
    this.gender,
    this.region,
    this.birthDate,
    this.phone,
    this.avatarUrl,
    this.role,
    this.accountType,
    this.memberRank,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? gender;
  final String? region;
  final DateTime? birthDate;
  final String? phone;
  final String? avatarUrl;
  final String? role;
  final String? accountType;
  final String? memberRank;

  bool get isStaffOrAdmin =>
      role == 'admin' || role == 'staff';

  String get genderLabel {
    switch (gender) {
      case 'male':
        return 'おとこ';
      case 'female':
        return 'おんな';
      case 'other':
        return 'そのほか';
      default:
        return '未設定';
    }
  }

  String get birthDateText {
    if (birthDate == null) return '未設定';
    return '${birthDate!.year}/${birthDate!.month.toString().padLeft(2, '0')}/${birthDate!.day.toString().padLeft(2, '0')}';
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      displayName: json['display_name'] as String?,
      gender: json['gender'] as String?,
      region: json['region'] as String?,
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'] as String)
          : null,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String?,
      accountType: json['account_type'] as String?,
      memberRank: json['member_rank'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'display_name': displayName,
      'gender': gender,
      'region': region,
      'birth_date': birthDate?.toIso8601String().split('T').first,
      'phone': phone,
      'avatar_url': avatarUrl,
    };
  }

  Profile copyWith({
    String? displayName,
    String? gender,
    String? region,
    DateTime? birthDate,
    String? phone,
    String? avatarUrl,
    String? role,
    String? accountType,
    String? memberRank,
  }) {
    return Profile(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      gender: gender ?? this.gender,
      region: region ?? this.region,
      birthDate: birthDate ?? this.birthDate,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      accountType: accountType ?? this.accountType,
      memberRank: memberRank ?? this.memberRank,
    );
  }
}
