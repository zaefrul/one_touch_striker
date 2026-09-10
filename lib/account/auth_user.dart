enum AuthProvider { google, apple }

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.provider,
    this.email,
  });

  final String id;
  final String name;
  final String? email;
  final AuthProvider provider;

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'P';
    }
    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get providerLabel =>
      provider == AuthProvider.google ? 'Google' : 'Apple';

  Map<String, String?> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'provider': provider.name,
      };

  factory AuthUser.fromJson(Map<String, Object?> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Player',
      email: json['email'] as String?,
      provider: AuthProvider.values.firstWhere(
        (value) => value.name == json['provider'],
        orElse: () => AuthProvider.google,
      ),
    );
  }
}

class SocialProfile {
  const SocialProfile({
    required this.id,
    required this.provider,
    this.name = '',
    this.email,
  });

  final String id;
  final String name;
  final String? email;
  final AuthProvider provider;
}

class AuthCanceled implements Exception {
  const AuthCanceled();
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}
