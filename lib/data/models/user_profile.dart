class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    this.email,
    this.groupId,
  });

  final String id;
  final String username;
  final String? email;
  final String? groupId;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: (json['username'] as String?) ?? 'Unknown',
      email: json['email'] as String?,
      groupId: json['group_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        if (email != null) 'email': email,
        if (groupId != null) 'group_id': groupId,
      };
}
