import 'package:ags_gold/core/utils/mobile_format.dart';

class UserRole {
  final String id;
  final String name;
  final List<UserPermission> permissions;

  const UserRole({
    required this.id,
    required this.name,
    this.permissions = const [],
  });

  factory UserRole.fromJson(Map<String, dynamic> json) {
    final perms = (json['permissions'] as List<dynamic>? ?? [])
        .map((e) => UserPermission.fromJson(e as Map<String, dynamic>))
        .toList();
    return UserRole(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      permissions: perms,
    );
  }
}

class UserPermission {
  final String id;
  final String name;

  const UserPermission({required this.id, required this.name});

  factory UserPermission.fromJson(Map<String, dynamic> json) {
    return UserPermission(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
    );
  }
}

class UserProfile {
  final String id;
  final String? mobileNumber;
  final String? firstName;
  final String? lastName;
  final bool isActive;
  final bool isSuperuser;
  final List<UserRole> roles;
  final bool hasAvatar;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    this.mobileNumber,
    this.firstName,
    this.lastName,
    required this.isActive,
    required this.isSuperuser,
    this.roles = const [],
    this.hasAvatar = false,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayName {
    final name = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    return name.isEmpty ? displayContactLine : name;
  }

  String get displayContactLine => formatDisplayMobile(mobileNumber);

  String get initials {
    if (firstName != null && firstName!.isNotEmpty) {
      return firstName![0].toUpperCase();
    }
    final digits = mobileNumber?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (digits.isNotEmpty) return digits[0];
    return 'U';
  }

  Set<String> get effectivePermissions {
    if (isSuperuser) return {'*'};
    final perms = <String>{};
    for (final role in roles) {
      for (final p in role.permissions) {
        perms.add(p.name);
      }
    }
    return perms;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final roles = (json['roles'] as List<dynamic>? ?? [])
        .map((e) => UserRole.fromJson(e as Map<String, dynamic>))
        .toList();
    return UserProfile(
      id: json['id'] as String,
      mobileNumber: json['mobile_number'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      isActive: json['is_active'] as bool? ?? false,
      isSuperuser: json['is_superuser'] as bool? ?? false,
      roles: roles,
      hasAvatar: json['has_avatar'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
