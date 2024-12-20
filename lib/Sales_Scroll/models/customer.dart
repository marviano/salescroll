class Customer {
  final String id;
  final String name;
  final String? company;
  final String phoneNumber;
  final String salesStatus;
  final String? boundToUid;
  final String? boundToName;
  final DateTime? bindingStartDate;
  final String bindingStatus;
  final DateTime? lastInteractionDate;
  final String? lastContactMethod;
  final String? lastContactStatus;
  final DateTime? nextFollowUpDate;
  final String? lastContactNotes;
  final int totalOrders;
  final int completedOrders;

  Customer({
    required this.id,
    required this.name,
    this.company,
    required this.phoneNumber,
    required this.salesStatus,
    this.boundToUid,
    this.boundToName,
    this.bindingStartDate,
    required this.bindingStatus,
    this.lastInteractionDate,
    this.lastContactMethod,
    this.lastContactStatus,
    this.nextFollowUpDate,
    this.lastContactNotes,
    this.totalOrders = 0,
    this.completedOrders = 0,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      name: json['name'],
      company: json['company'],
      phoneNumber: json['phone_number'],
      salesStatus: json['sales_status'] ?? 'cold',
      boundToUid: json['bound_to_uid'],
      boundToName: json['bound_to_name'],
      bindingStartDate: json['binding_start_date'] != null
          ? DateTime.parse(json['binding_start_date'])
          : null,
      bindingStatus: json['binding_status'] ?? 'available',
      lastInteractionDate: json['last_interaction_date'] != null
          ? DateTime.parse(json['last_interaction_date'])
          : null,
      lastContactMethod: json['last_contact_method'],
      lastContactStatus: json['last_contact_status'],
      nextFollowUpDate: json['next_follow_up_date'] != null
          ? DateTime.parse(json['next_follow_up_date'])
          : null,
      lastContactNotes: json['last_contact_notes'],
      totalOrders: json['total_orders'] ?? 0,
      // Fix for completed_orders
      completedOrders: json['completed_orders'] != null
          ? int.parse(json['completed_orders'].toString())
          : 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'company': company,
    'phone_number': phoneNumber,
    'sales_status': salesStatus,
    'bound_to_uid': boundToUid,
    'bound_to_name': boundToName,
    'binding_status': bindingStatus,
    'binding_start_date': bindingStartDate?.toIso8601String(),
    'last_interaction_date': lastInteractionDate?.toIso8601String(),
    'last_contact_method': lastContactMethod,
    'last_contact_status': lastContactStatus,
    'next_follow_up_date': nextFollowUpDate?.toIso8601String(),
    'last_contact_notes': lastContactNotes,
    'total_orders': totalOrders,
    'completed_orders': completedOrders,
  };

  // Helper method to get contact age in days
  int? get daysSinceLastContact {
    if (lastInteractionDate == null) return null;
    return DateTime.now().difference(lastInteractionDate!).inDays;
  }

  // Helper method to check if follow-up is due
  bool get isFollowUpDue {
    if (nextFollowUpDate == null) return false;
    return DateTime.now().isAfter(nextFollowUpDate!);
  }

  bool get isThreeHourFollowUpDue {
    if (nextFollowUpDate == null) return false;
    final now = DateTime.now();
    final difference = nextFollowUpDate!.difference(now);
    return difference.isNegative || difference.inHours < 3;
  }

  // Helper method to calculate conversion rate
  double get conversionRate {
    if (totalOrders == 0) return 0.0;
    return (completedOrders / totalOrders) * 100;
  }

  // Create a copy of Customer with updated fields
  Customer copyWith({
    String? id,
    String? name,
    String? company,
    String? phoneNumber,
    String? salesStatus,
    String? boundToUid,
    String? boundToName,
    DateTime? bindingStartDate,
    String? bindingStatus,
    DateTime? lastInteractionDate,
    String? lastContactMethod,
    String? lastContactStatus,
    DateTime? nextFollowUpDate,
    String? lastContactNotes,
    int? totalOrders,
    int? completedOrders,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      company: company ?? this.company,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      salesStatus: salesStatus ?? this.salesStatus,
      boundToUid: boundToUid ?? this.boundToUid,
      boundToName: boundToName ?? this.boundToName,
      bindingStartDate: bindingStartDate ?? this.bindingStartDate,
      bindingStatus: bindingStatus ?? this.bindingStatus,
      lastInteractionDate: lastInteractionDate ?? this.lastInteractionDate,
      lastContactMethod: lastContactMethod ?? this.lastContactMethod,
      lastContactStatus: lastContactStatus ?? this.lastContactStatus,
      nextFollowUpDate: nextFollowUpDate ?? this.nextFollowUpDate,
      lastContactNotes: lastContactNotes ?? this.lastContactNotes,
      totalOrders: totalOrders ?? this.totalOrders,
      completedOrders: completedOrders ?? this.completedOrders,
    );
  }

  @override
  String toString() {
    return 'Customer{id: $id, name: $name, company: $company, status: $salesStatus, binding: $bindingStatus}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Customer && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}