class EmergencyContact {
  final String id;
  final String name;
  final String phone;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
  };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) => EmergencyContact(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
  );
}
