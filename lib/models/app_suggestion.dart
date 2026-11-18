class AppSuggestion {
  final String id;
  final String title;
  final String description;
  final String category; // '💡 Nova Funcionalidade', '⚡ Melhoria TVDE', '🐛 Reportar Erro (Bug)', '🚗 Carro / Bateria'
  final String author;
  final DateTime createdAt;
  final bool sentViaWhatsApp;
  final bool sentOnline;
  final String deviceId;
  final String appVersion;
  final String vehicleName;

  AppSuggestion({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.author = '',
    required this.createdAt,
    this.sentViaWhatsApp = false,
    this.sentOnline = false,
    this.deviceId = '',
    this.appVersion = '',
    this.vehicleName = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category,
    'author': author,
    'createdAt': createdAt.toIso8601String(),
    'sentViaWhatsApp': sentViaWhatsApp,
    'sentOnline': sentOnline,
    'deviceId': deviceId,
    'appVersion': appVersion,
    'vehicleName': vehicleName,
  };

  factory AppSuggestion.fromJson(Map<String, dynamic> json) => AppSuggestion(
    id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    category: json['category'] as String? ?? '💡 Nova Funcionalidade',
    author: json['author'] as String? ?? '',
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
        : DateTime.now(),
    sentViaWhatsApp: json['sentViaWhatsApp'] as bool? ?? false,
    sentOnline: json['sentOnline'] as bool? ?? false,
    deviceId: json['deviceId'] as String? ?? '',
    appVersion: json['appVersion'] as String? ?? '',
    vehicleName: json['vehicleName'] as String? ?? '',
  );
}
