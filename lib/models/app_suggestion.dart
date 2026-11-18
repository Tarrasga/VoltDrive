class AppSuggestion {
  final String id;
  final String title;
  final String description;
  final String category; // '💡 Ideia Nova', '⚡ Melhoria TVDE', '🐛 Erro / Problema', '🚗 Zoe / Veículo'
  final String author;
  final DateTime createdAt;
  final bool sentViaWhatsApp;

  AppSuggestion({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.author = '',
    required this.createdAt,
    this.sentViaWhatsApp = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category,
    'author': author,
    'createdAt': createdAt.toIso8601String(),
    'sentViaWhatsApp': sentViaWhatsApp,
  };

  factory AppSuggestion.fromJson(Map<String, dynamic> json) => AppSuggestion(
    id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    category: json['category'] as String? ?? '💡 Ideia Nova',
    author: json['author'] as String? ?? '',
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
        : DateTime.now(),
    sentViaWhatsApp: json['sentViaWhatsApp'] as bool? ?? false,
  );
}
