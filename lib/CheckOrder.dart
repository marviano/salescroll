import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'widgets/burger_menu.dart';
import 'widgets/loading_overlay.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:salescroll/services/env.dart';

enum TagType { status, people, purpose }

class TagConfig {
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;

  TagConfig({
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
  });
}

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
      if (user == null) throw Exception('No user logged in');

      final response = await http.get(
        Uri.parse('${Env.apiUrl}/api/orders?firebase_uid=${user.uid}'),
        headers: {'Content-Type': 'application/json'},
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
    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No orders found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _orders.length,
      itemBuilder: (context, index) => _buildOrderCard(_orders[index], index),
    );
  }

  Widget _buildOrderCard(dynamic order, int index) {
    final orderId = order['order_id']?.substring(0, 8) ?? 'N/A';
    final backgroundColor = index % 2 == 0 ? Colors.green[50] : Colors.white;
    final numberOfPeople = order['number_of_people']?.toString() ?? 'N/A';
    final purpose = order['purpose'] ?? 'N/A';
    final roomName = order['room_name'] ?? 'N/A';
    final roomLayout = order['room_layout'] ?? 'N/A';

    return Card(
      elevation: 4,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        collapsedBackgroundColor: backgroundColor,
        backgroundColor: backgroundColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order #$orderId',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
            ),
            SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTag(
                      order['status'] ?? 'N/A',
                      _getTagConfig(TagType.status, order['status'])
                  ),
                  SizedBox(width: 8),
                  _buildTag(
                      '$numberOfPeople people',
                      _getTagConfig(TagType.people, null)
                  ),
                  SizedBox(width: 8),
                  _buildTag(
                      purpose,
                      _getTagConfig(TagType.purpose, null)
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8),
            _buildInfoRow(Icons.business, order['restaurant_name'] ?? 'N/A'),
            _buildInfoRow(Icons.person, order['customer_name'] ?? 'N/A'),
            _buildInfoRow(Icons.event, _formatDate(order['delivery_datetime'])),
            _buildInfoRow(Icons.meeting_room, '$roomName ($roomLayout)'),
            SizedBox(height: 8),
            _buildActionButtons(order),
          ],
        ),
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailSection('Order Information', [
                  _buildDetailRow('Customer', order['customer_name'] ?? 'N/A'),
                  _buildDetailRow('Restaurant', order['restaurant_name'] ?? 'N/A'),
                  _buildDetailRow('Purpose', purpose),
                  _buildDetailRow('Status', order['status'] ?? 'N/A'),
                  _buildDetailRow('Delivery Date', _formatDate(order['delivery_datetime'])),
                ]),

                SizedBox(height: 16),
                _buildDetailSection('Room Details', [
                  _buildDetailRow('Room', roomName),
                  _buildDetailRow('Layout', roomLayout),
                  _buildDetailRow('Capacity', '$numberOfPeople people'),
                ]),

                SizedBox(height: 16),
                _buildSectionTitle('Order Items'),
                _buildPackageDetails(order['package_details']),

                if (order['memo'] != null && order['memo'].toString().isNotEmpty) ...[
                  SizedBox(height: 16),
                  _buildDetailSection('Memo', [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        order['memo'],
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ]),
                ],

                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Price',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _formatPrice(order['total_price'] ?? 0),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageDetails(String? packageDetails) {
    if (packageDetails == null || packageDetails.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Center(
          child: Text(
            'No packages',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: packageDetails.split('\n').map((package) {
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[200]!,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.fastfood, size: 20, color: Colors.grey[600]),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    package,
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTagRow(List<Widget> tags) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: tags,
    );
  }

  Widget _buildTag(String text, TagConfig config) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3), // reduced from 8,4
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(9), // reduced from 12
        border: Border.all(color: config.borderColor),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9, // reduced from 12
          color: config.textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(dynamic order) {
    return Row(
      children: [
        _buildActionButton(Icons.edit, () => _onEditPressed(order), 'Edit'),
        SizedBox(width: 8),
        _buildActionButton(Icons.track_changes, () => _onTrackPressed(order), 'Track'),
        SizedBox(width: 8),
        _buildActionButton(Icons.cancel, () => _onCancelPressed(order), 'Cancel'),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onPressed, String label) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 8),
          side: BorderSide(color: Colors.grey[400]!),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  void _onEditPressed(dynamic order) {
    final orderId = order['order_id']?.substring(0, 8) ?? 'N/A';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Order #$orderId'),
        content: Text('Edit functionality will be implemented here.'),
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
    final orderId = order['order_id']?.substring(0, 8) ?? 'N/A';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Track Order #$orderId'),
        content: Text('Tracking information will be displayed here.'),
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
    final orderId = order['order_id']?.substring(0, 8) ?? 'N/A';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Column(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
            SizedBox(height: 8),
            Text('Cancel Order #$orderId'),
          ],
        ),
        content: Text('Are you sure you want to cancel this order? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Order #$orderId has been cancelled.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Yes, Cancel Order'),
          ),
        ],
      ),
    );
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

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange[700]!;
      case 'confirmed':
        return Colors.green[700]!;
      case 'cancelled':
        return Colors.red[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  TagConfig _getTagConfig(TagType type, String? status) {
    switch (type) {
      case TagType.status:
        final baseColor = _getStatusColor(status);
        return TagConfig(
          backgroundColor: baseColor.withOpacity(0.15),
          textColor: baseColor.withOpacity(0.85),
          borderColor: baseColor,
        );

      case TagType.people:
        return TagConfig(
          backgroundColor: Colors.blue[50]!,
          textColor: Colors.blue[700]!,
          borderColor: Colors.blue[200]!,
        );

      case TagType.purpose:
        return TagConfig(
          backgroundColor: Colors.purple[50]!,
          textColor: Colors.purple[700]!,
          borderColor: Colors.purple[200]!,
        );
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMMM yyyy, HH:mm').format(date);
    } catch (e) {
      return 'Invalid Date';
    }
  }

  String _formatPrice(int price) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(price);
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
}