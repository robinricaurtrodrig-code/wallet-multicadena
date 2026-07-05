class UserModel {
  final String uid;
  final String email;
  final String username;
  final DateTime? fechaRegistro;
  final bool walletCreada;

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    this.fechaRegistro,
    this.walletCreada = false,
  });

  /// Construye un UserModel desde un mapa de Firestore
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      fechaRegistro: json['fechaRegistro'] != null
          ? (json['fechaRegistro'] as dynamic).toDate()
          : null,
      walletCreada: json['walletCreada'] ?? false,
    );
  }

  /// Convierte el modelo a un mapa para guardar en Firestore
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'fechaRegistro': fechaRegistro,
      'walletCreada': walletCreada,
    };
  }
}

class UserSettings {
  String idioma;
  String tema;
  String monedaPreferida;
  bool notificacionesActivas;
  List<String> tokensFavoritos;

  UserSettings({
    this.idioma = 'es',
    this.tema = 'dark',
    this.monedaPreferida = 'USD',
    this.notificacionesActivas = true,
    this.tokensFavoritos = const [],
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      idioma: json['idioma'] ?? 'es',
      tema: json['tema'] ?? 'dark',
      monedaPreferida: json['monedaPreferida'] ?? 'USD',
      notificacionesActivas: json['notificacionesActivas'] ?? true,
      tokensFavoritos: (json['tokensFavoritos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idioma': idioma,
      'tema': tema,
      'monedaPreferida': monedaPreferida,
      'notificacionesActivas': notificacionesActivas,
      'tokensFavoritos': tokensFavoritos,
    };
  }
}
