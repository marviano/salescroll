import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'widgets/burger_menu.dart';
import 'widgets/loading_overlay.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:salescroll/services/env.dart';

class CheckOrderPage extends StatefulWidget {
  @override
  _CheckOrderPageState createState() => _CheckOrderPageState();
}

class _CheckOrderPageState extends State<CheckOrderPage> {
  List<dynamic> _orders = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final response = await http.get(
        Uri.parse('${Env.apiUrl}/api/orders?firebase_uid=${user.uid}'),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _orders = json.decode(response.body);
        });
      } else {
        throw Exception('Failed to load orders');
      }
    } catch (e) {
      _showErrorDialog('Error fetching orders: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            child: Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd - MMMM - yyyy').format(date);
    } catch (e) {
      return 'Invalid Date';
    }
  }

  String _formatPrice(int price) {
    final formatter = NumberFormat("#,##0", "id_ID");
    return 'Rp ${formatter.format(price)},-';
  }

  String _formatPhoneNumber(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) return 'N/A';
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final regex = RegExp(r'(\d{4})(\d{4})(\d{4})');
    final match = regex.firstMatch(digitsOnly);
    if (match != null) {
      return '${match.group(1)}-${match.group(2)}-${match.group(3)}';
    }
    return phoneNumber;
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied to clipboard')),
    );
  }

  String _calculateTotalPrice(List<dynamic> items) {
    int total = 0;
    for (var item in items) {
      int price = (item['price_per_item'] as num?)?.toInt() ?? 0;
      int quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      total += price * quantity;
    }
    return _formatPrice(total);
  }

  @override
  Widget build(BuildContext context) {
    return BurgerMenu(
      topBarTitle: "Check Orders",
      activePage: ActivePage.checkOrder,
      child: LoadingOverlay(
        isLoading: _isLoading,
        loadingText: 'Fetching orders...',
        child: _orders.isEmpty
            ? Center(child: Text('No orders found'))
            : ListView.builder(
          itemCount: _orders.length,
          itemBuilder: (context, index) {
            final order = _orders[index];
            final Color backgroundColor = index % 2 == 0
                ? Color(0xFFFFF8F3)  // Original color for even indices (including 0)
                : Color(0xFFFFE8D3);  // Darker shade for odd indices
            final Color highlightColor = index % 2 == 0
                ? Color(0xFFFFE8D3)  // Highlight color for even indices
                : Color(0xFFFFF8F3);  // Highlight color for odd indices
            return Card(
              margin: EdgeInsets.all(8.0),
              child: Container(
                color: backgroundColor,
                child: ExpansionTile(
                  title: Text('Order #${order['id']?.substring(0, 8) ?? 'N/A'}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: highlightColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Status: ${order['status'] ?? 'N/A'}', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: highlightColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${order['restaurant_name'] ?? 'N/A'}', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: highlightColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Delivery: ${_formatDate(order['delivery_datetime'])}', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: highlightColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Customer: ${order['customer_name'] ?? 'N/A'}', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Divider(height: 1, thickness: 0.5, color: Colors.black.withOpacity(0.2)),
                          SizedBox(height: 16),
                          Text('Order Details', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Text('Restaurant: ${order['restaurant_name'] ?? 'N/A'}'),
                          Text('Purpose: ${order['order_purpose'] ?? 'N/A'}'),
                          Text('Order Date: ${_formatDate(order['order_date'])}'),
                          Text('Delivery Date: ${_formatDate(order['delivery_datetime'])}'),
                          SizedBox(height: 16),
                          Divider(height: 1, thickness: 0.5, color: Colors.black.withOpacity(0.2)),
                          SizedBox(height: 16),
                          Text('Customer Information', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Text('Name: ${order['customer_name'] ?? 'N/A'}'),
                          Row(
                            children: [
                              Text('Phone: ${_formatPhoneNumber(order['customer_phone'])}'),
                              SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.copy, size: 20),
                                onPressed: () => _copyToClipboard(order['customer_phone'] ?? ''),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Divider(height: 1, thickness: 0.5, color: Colors.black.withOpacity(0.2)),
                          SizedBox(height: 16),
                          Text('Items', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          ...(order['items'] as List? ?? []).map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['package_name'] ?? 'N/A'),
                                      Text('Quantity: ${item['quantity'] ?? 'N/A'}'),
                                    ],
                                  ),
                                ),
                                Text(_formatPrice(((item['price_per_item'] as num?)?.toInt() ?? 0) * ((item['quantity'] as num?)?.toInt() ?? 0))),
                              ],
                            ),
                          )).toList(),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Price', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                _calculateTotalPrice(order['items'] ?? []),
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}