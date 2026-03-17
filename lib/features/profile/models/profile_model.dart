class Profile {
  const Profile({
    required this.id,
    required this.email,
    this.displayName,
    this.phone,
    this.avatarUrl,
    this.accountType,
    this.memberRank,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? phone;
  final String? avatarUrl;
  final String? accountType;
  final String? memberRank;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      displayName: json['display_name'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      accountType: json['account_type'] as String?,
      memberRank: json['member_rank'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'display_name': displayName,
      'phone': phone,
      'avatar_url': avatarUrl,
    };
  }

  Profile copyWith({
    String? displayName,
    String? phone,
    String? avatarUrl,
    String? accountType,
    String? memberRank,
  }) {
    return Profile(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      accountType: accountType ?? this.accountType,
      memberRank: memberRank ?? this.memberRank,
    );
  }
}
