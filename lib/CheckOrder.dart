import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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

  @override
  Widget build(BuildContext context) {
    return BurgerMenu(
      topBarTitle: "Check Orders",
      activePage: ActivePage.checkOrder,
      child: LoadingOverlay(
        isLoading: _isLoading,
        loadingText: 'Fetching orders...',
        child: _buildOrderList(),
      ),
    );
  }

  Widget _buildOrderList() {
    if (_orders.isEmpty) return Center(child: Text('No orders found'));

    return ListView.builder(
      itemCount: _orders.length,
      itemBuilder: (context, index) => _buildOrderCard(_orders[index], index),
    );
  }

  Widget _buildOrderCard(dynamic order, int index) {
    final backgroundColor = index % 2 == 0 ? Color(0xFFFFF8F3) : Color(0xFFFFE8D3);
    final orderId = order['id']?.substring(0, 8) ?? 'N/A';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: backgroundColor,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ExpansionTile(
            tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              'Order #$orderId',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderSummary(order, backgroundColor),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _buildIconButton(Icons.edit, () => _onEditPressed(order)),
                    SizedBox(width: 12),
                    _buildIconButton(Icons.track_changes, () => _onTrackPressed(order)),
                    SizedBox(width: 12),
                    _buildIconButton(Icons.cancel, () => _onCancelPressed(order)),
                  ],
                ),
              ],
            ),
            children: [_buildOrderDetails(order)],
            childrenPadding: EdgeInsets.zero,
            trailing: Icon(
              Icons.expand_more,
              color: Color(0xFF8D6E63), // Light dark brown color
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey[400]!, // Lighter border color
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        color: Colors.grey[400], // Lighter icon color to appear disabled
        padding: EdgeInsets.all(8),
        constraints: BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }

  void _onEditPressed(dynamic order) {
    final orderId = order['id']?.substring(0, 8) ?? 'N/A';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Order #$orderId'),
        content: Text('Edit functionality for Order #$orderId will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _onTrackPressed(dynamic order) {
    final orderId = order['id']?.substring(0, 8) ?? 'N/A';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Track Order #$orderId'),
        content: Text('Tracking information for Order #$orderId will be displayed here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _onCancelPressed(dynamic order) {
    final orderId = order['id']?.substring(0, 8) ?? 'N/A';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Order #$orderId'),
        content: Text('Are you sure you want to cancel Order #$orderId?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No'),
          ),
          TextButton(
            onPressed: () {
              // Implement cancellation logic here
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Order #$orderId has been cancelled.')),
              );
            },
            child: Text('Yes'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(dynamic order, Color highlightColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHighlightedText('Status: ${order['status'] ?? 'N/A'}', highlightColor),
        SizedBox(height: 4),
        _buildHighlightedText('${order['restaurant_name'] ?? 'N/A'}', highlightColor),
        SizedBox(height: 4),
        _buildHighlightedText('Delivery: ${_formatDate(order['delivery_datetime'])}', highlightColor),
        SizedBox(height: 4),
        _buildHighlightedText('Customer: ${order['customer_name'] ?? 'N/A'}', highlightColor),
      ],
    );
  }

  Widget _buildHighlightedText(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildOrderDetails(dynamic order) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection('Order Details', [
            Text('Restaurant: ${order['restaurant_name'] ?? 'N/A'}'),
            Text('Purpose: ${order['order_purpose'] ?? 'N/A'}'),
            Text('Order Date: ${_formatDate(order['order_date'])}'),
            Text('Delivery Date: ${_formatDate(order['delivery_datetime'])}'),
          ]),
          _buildSection('Customer Information', [
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
          ]),
          _buildSection('Items', [
            ...(order['items'] as List? ?? []).map(_buildOrderItem).toList(),
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
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        ...children,
        SizedBox(height: 16),
        Divider(height: 1, thickness: 0.5, color: Colors.black.withOpacity(0.2)),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildOrderItem(dynamic item) {
    return Padding(
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
    );
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user logged in');

      final response = await http.get(
        Uri.parse('${Env.apiUrl}/api/orders?firebase_uid=${user.uid}'),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() => _orders = json.decode(response.body));
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
    return match != null ? '${match.group(1)}-${match.group(2)}-${match.group(3)}' : phoneNumber;
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied to clipboard')),
    );
  }

  String _calculateTotalPrice(List<dynamic> items) {
    int total = items.fold(0, (sum, item) => sum + ((item['price_per_item'] as num?)?.toInt() ?? 0) * ((item['quantity'] as num?)?.toInt() ?? 0));
    return _formatPrice(total);
  }
}