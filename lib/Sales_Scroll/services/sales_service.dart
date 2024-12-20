import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/env.dart';
import '../models/customer.dart';

class SalesService {
  final String baseUrl = Env.apiUrl;

// In SalesService class (paste-4.txt)
  Future<List<Customer>> getCustomers({
    String? search,
    String? status,
    String? boundToUid,
  }) async {
    final queryParams = {
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status != 'all') 'status': status,
      if (boundToUid != null) 'bound_to_uid': boundToUid,
    };

    final uri = Uri.parse('$baseUrl/api/sales/customers')
        .replace(queryParameters: queryParams);

    try {
      final response = await http.get(uri);
      print('DEBUG: Raw response: ${response.body}'); // Add debug log

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Customer.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load customers: ${response.statusCode}');
      }
    } catch (e) {
      print('Error details: $e');
      throw Exception('Failed to load customers: $e');
    }
  }

  // In SalesService class (paste-4.txt)
  Future<void> bindCustomer({
    required String customerId,
    required String agentUid,
  }) async {
    final uri = Uri.parse('${Env.apiUrl}/api/sales/bind-customer');

    try {
      final response = await http.post(
        uri,
        body: json.encode({
          'customer_id': customerId,
          'agent_uid': agentUid,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      print('DEBUG: Bind response: ${response.body}'); // Add debug log

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to bind customer: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG: Bind error: $e'); // Add debug log
      throw Exception('Failed to bind customer: $e');
    }
  }

  Future<void> confirmBinding({
    required String customerId,
    required String agentUid,
    required String contactMethod,
    required String contactStatus,
    String? notes,
  }) async {
    final uri = Uri.parse('$baseUrl/api/sales/confirm-binding');

    try {
      final response = await http.post(
        uri,
        body: json.encode({
          'customer_id': customerId,
          'agent_uid': agentUid,
          'contact_method': contactMethod,
          'contact_status': contactStatus,
          'notes': notes,
          'contact_date': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to confirm binding: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to confirm binding: $e');
    }
  }

  Future<void> addCustomerContact({
    required String customerId,
    required String contactedByUid,
    required String contactMethod,
    required String contactStatus,
    String? notes,
    DateTime? nextFollowUpDate,
    bool isOverdueContact = false,
  }) async {
    final uri = Uri.parse('$baseUrl/api/sales/customer-contacts');

    try {
      final response = await http.post(
        uri,
        body: json.encode({
          'customer_id': customerId,
          'contacted_by_uid': contactedByUid,
          'contact_method': contactMethod,
          'contact_status': contactStatus,
          'notes': notes,
          'next_follow_up_date': nextFollowUpDate?.toIso8601String(),
          'is_overdue_contact': isOverdueContact, // Add this flag
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to add contact: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to add contact: $e');
    }
  }

  Future<void> releaseCustomer({
    required String customerId,
    required String reason,
  }) async {
    final uri = Uri.parse('$baseUrl/api/sales/release-customer');

    try {
      final response = await http.post(
        uri,
        body: json.encode({
          'customer_id': customerId,
          'reason': reason,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to release customer: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to release customer: $e');
    }
  }
}