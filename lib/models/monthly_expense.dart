class MonthlyExpense {
  final String id;
  final String monthKey; // Ex: '2026-11' ou '' para recorrente/padrão
  final String title;    // Ex: 'Baterias (Aluguer Zoe)', 'Via Verde', 'Pneus', 'Seguro'
  final double amount;   // Valor em Euros (€)
  final bool isRecurring; // Repete todos os meses automaticamente
  final String category; // 'battery', 'tolls', 'maintenance', 'insurance', 'other'
  final DateTime date;

  MonthlyExpense({
    required this.id,
    required this.monthKey,
    required this.title,
    required this.amount,
    this.isRecurring = true,
    this.category = 'other',
    DateTime? date,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'monthKey': monthKey,
    'title': title,
    'amount': amount,
    'isRecurring': isRecurring,
    'category': category,
    'date': date.toIso8601String(),
  };

  factory MonthlyExpense.fromJson(Map<String, dynamic> json) => MonthlyExpense(
    id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
    monthKey: json['monthKey'] as String? ?? '',
    title: json['title'] as String? ?? 'Despesa',
    amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    isRecurring: json['isRecurring'] as bool? ?? true,
    category: json['category'] as String? ?? 'other',
    date: json['date'] != null ? (DateTime.tryParse(json['date'] as String) ?? DateTime.now()) : DateTime.now(),
  );

  MonthlyExpense copyWith({
    String? id,
    String? monthKey,
    String? title,
    double? amount,
    bool? isRecurring,
    String? category,
    DateTime? date,
  }) => MonthlyExpense(
    id: id ?? this.id,
    monthKey: monthKey ?? this.monthKey,
    title: title ?? this.title,
    amount: amount ?? this.amount,
    isRecurring: isRecurring ?? this.isRecurring,
    category: category ?? this.category,
    date: date ?? this.date,
  );
}
