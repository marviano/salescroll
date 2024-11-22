import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:salescroll/widgets/network_error_handler.dart';
import 'dart:convert';
import 'widgets/burger_menu.dart';
import 'widgets/loading_overlay.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:salescroll/services/env.dart';
import 'CheckOrder_Edit.dart';

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
  bool _isRefreshing = false;
  String _bookingTypeFilter = 'all';
  String _statusFilter = 'pending';
  DateTimeRange? _dateRange;

  String _restaurantSearch = '';
  String _customerSearch = '';
  String _timeFilter = 'all';  // 'all', 'today', 'tomorrow', 'next-week', 'next-month'
  bool _showAdvancedFilters = false; // To toggle filter visibility

  String _activeStatusFilter = 'pending';  // New variable for active filter

  // Add this getter method inside the class
  List<dynamic> get displayOrders {
    return _orders.where((order) {
      if (_activeStatusFilter != 'all') {
        return order['status'] == _activeStatusFilter;
      }
      return true;
    }).toList();
  }

  Map<String, int> _getOrderCounts() {
    // Start with a copy of all orders
    var filteredOrders = List.from(_orders);  // Get all orders first

    // Apply date range filter if it exists
    if (_dateRange != null) {
      filteredOrders = filteredOrders.where((order) {
        final orderDate = DateTime.parse(order['delivery_datetime']);
        return orderDate.isAfter(_dateRange!.start) &&
            orderDate.isBefore(_dateRange!.end.add(Duration(days: 1)));
      }).toList();
    }

    // Count all statuses regardless of current filter
    final counts = {
      'pending': filteredOrders.where((order) => order['status'] == 'pending').length,
      'completed': filteredOrders.where((order) => order['status'] == 'completed').length,
      'cancelled': filteredOrders.where((order) => order['status'] == 'cancelled').length,
    };

    print('DEBUG: Order counts - ${counts.toString()}');  // Add this for debugging

    return counts;
  }

  DateTimeRange _getTimeFilterDateRange() {
    final now = DateTime.now();
    DateTimeRange range;

    switch (_timeFilter) {
      case 'today':
        range = DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
        break;
      case 'tomorrow':
        final tomorrow = now.add(Duration(days: 1));
        range = DateTimeRange(
          start: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
          end: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 23, 59, 59),
        );
        break;
      case 'next-week':
      // Calculate the start of next week (next Monday)
        var nextMonday = now;
        while (nextMonday.weekday != DateTime.monday) {
          nextMonday = nextMonday.add(Duration(days: 1));
        }

        // End date is Sunday of next week
        final nextSunday = nextMonday.add(Duration(days: 6));

        range = DateTimeRange(
          start: DateTime(nextMonday.year, nextMonday.month, nextMonday.day),
          end: DateTime(nextSunday.year, nextSunday.month, nextSunday.day, 23, 59, 59),
        );
        break;
      case 'next-month':
      // Calculate the start of next month
        var nextMonth = DateTime(now.year, now.month + 1, 1);
        // Calculate the end of next month
        var endOfNextMonth = DateTime(now.year, now.month + 2, 0, 23, 59, 59);

        range = DateTimeRange(
          start: nextMonth,
          end: endOfNextMonth,
        );
        break;
      default:
        range = DateTimeRange(
          start: now,
          end: now.add(Duration(days: 365)),
        );
    }
    print('DEBUG: TimeFilter: $_timeFilter');
    print('DEBUG: Date Range - Start: ${range.start}, End: ${range.end}');
    return range;
  }


  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours > 0 && remainingMinutes > 0) {
      return '$hours jam $remainingMinutes menit';
    } else if (hours > 0) {
      return '$hours jam';
    } else {
      return '$minutes menit';
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _refreshPage() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    try {
      await _fetchOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Page refreshed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        NetworkErrorNotifier.instance.notifyError();
        setState(() => _orders = []);
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user logged in');

      final timeFilterRange = _getTimeFilterDateRange();
      final effectiveDateRange = _timeFilter != 'all' ? timeFilterRange : _dateRange;

      var queryParams = {
        'firebase_uid': user.uid,
        if (_bookingTypeFilter != 'all') 'booking_type': _bookingTypeFilter,
        // Remove the status filter from API request to get all statuses
        // if (_activeStatusFilter != 'all') 'status': _activeStatusFilter,
      };

      if (effectiveDateRange != null) {
        queryParams['start_date'] = DateFormat('yyyy-MM-dd HH:mm:ss').format(effectiveDateRange.start);
        queryParams['end_date'] = DateFormat('yyyy-MM-dd HH:mm:ss').format(effectiveDateRange.end);
      }

      final uri = Uri.parse('${Env.apiUrl}/api/orders').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        var filteredOrders = List.from(decodedResponse);

        if (_restaurantSearch.isNotEmpty) {
          filteredOrders = filteredOrders.where((order) {
            final restaurantName = order['restaurant_name']?.toString() ?? '';
            return restaurantName.toLowerCase().contains(_restaurantSearch.toLowerCase());
          }).toList();
        }

        if (_customerSearch.isNotEmpty) {
          filteredOrders = filteredOrders.where((order) {
            final customerName = order['customer_name']?.toString() ?? '';
            return customerName.toLowerCase().contains(_customerSearch.toLowerCase());
          }).toList();
        }

        setState(() => _orders = filteredOrders);
        NetworkErrorNotifier.instance.clearError();
      }
    } catch (e) {
      print('DEBUG: Error fetching orders: $e');
      setState(() => _orders = []);
      NetworkErrorNotifier.instance.notifyError();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NetworkErrorHandler(
      child: BurgerMenu(
        topBarTitle: "Check Orders",
        activePage: ActivePage.checkOrder,
        onRefresh: _isRefreshing ? null : _refreshPage,
        child: GestureDetector(
          onTap: () {
            if (_showAdvancedFilters) {
              setState(() => _showAdvancedFilters = false);
            }
          },
          behavior: HitTestBehavior.translucent,
          child: LoadingOverlay(
            isLoading: _isLoading,
            loadingText: 'Fetching orders...',
            child: Column(
              children: [
                _buildFilters(),
                Expanded(
                  child: _orders.isEmpty && !_isLoading
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh, size: 50, color: Colors.grey),
                        SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Please refresh the page to load orders',
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshPage,
                          child: Text('Refresh Now'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  )
                      : AbsorbPointer(
                    absorbing: _showAdvancedFilters,
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.all(16),
                      itemCount: displayOrders.length,
                      itemBuilder: (context, index) => _buildOrderCard(displayOrders[index], index),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: EdgeInsets.symmetric(horizontal: 12),
            title: Text(
              'Filters',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            trailing: AnimatedRotation(
              duration: Duration(milliseconds: 300),
              turns: _showAdvancedFilters ? 0.5 : 0,
              child: IconButton(
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  size: 20,
                ),
                onPressed: () => setState(() => _showAdvancedFilters = !_showAdvancedFilters),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: Container(height: 0),
            secondChild: Container(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
                  final maxHeight = MediaQuery.of(context).size.height * 0.6;
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    constraints: BoxConstraints(
                      maxHeight: maxHeight - (bottomPadding > 0 ? bottomPadding : 0),
                    ),
                    child: SingleChildScrollView(
                      physics: ClampingScrollPhysics(),
                      padding: EdgeInsets.only(
                        left: 12,
                        right: 12,
                        bottom: 12,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSearchField(
                            'Search Restaurant',
                            Icons.business,
                                (value) => setState(() => _restaurantSearch = value),
                          ),
                          SizedBox(height: 8),
                          _buildSearchField(
                            'Search Customer',
                            Icons.person,
                                (value) => setState(() => _customerSearch = value),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Tanggal',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 4),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildTimeFilterChip('Harini', 'today'),
                                SizedBox(width: 6),
                                _buildTimeFilterChip('Besok', 'tomorrow'),
                                SizedBox(width: 6),
                                _buildTimeFilterChip('Mingdep', 'next-week'),
                                SizedBox(width: 6),
                                _buildTimeFilterChip('Buldep', 'next-month'),
                              ],
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Tipe Booking',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 4),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildBookingTypeChip('All', 'all'),
                                SizedBox(width: 6),
                                _buildBookingTypeChip('Package', 'package'),
                                SizedBox(width: 6),
                                _buildBookingTypeChip('Room Only', 'room_only'),
                              ],
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Status',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 4),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildStatusChip('All', 'all'),
                                SizedBox(width: 6),
                                _buildStatusChip('Pending', 'pending'),
                                SizedBox(width: 6),
                                _buildStatusChip('Selesai', 'completed'),
                                SizedBox(width: 6),
                                _buildStatusChip('Batal', 'cancelled'),
                              ],
                            ),
                          ),
                          SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(Duration(days: 365)),
                                  initialDateRange: _dateRange,
                                );
                                if (picked != null) {
                                  setState(() {
                                    _dateRange = picked;
                                    _timeFilter = 'all';
                                  });
                                }
                              },
                              icon: Icon(Icons.date_range, size: 16),
                              label: Text(
                                _dateRange == null
                                    ? 'Custom Date Range'
                                    : '${DateFormat('dd/MM/yyyy').format(_dateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_dateRange!.end)}',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: Size(0, 32),
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _activeStatusFilter = _statusFilter;  // Apply the selected filter
                                  _showAdvancedFilters = false;
                                });
                                _fetchOrders();
                              },
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                minimumSize: Size(0, 36),
                                backgroundColor: Theme.of(context).primaryColor,
                              ),
                              child: Text(
                                'Cari',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            crossFadeState: _showAdvancedFilters
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: Duration(milliseconds: 300),
            reverseDuration: Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  Widget _buildBookingTypeChip(String label, String value) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: _bookingTypeFilter == value ? Colors.white : Colors.grey[800],
        ),
      ),
      selected: _bookingTypeFilter == value,
      onSelected: (selected) {
        setState(() => _bookingTypeFilter = selected ? value : 'all');
      },
      selectedColor: Theme.of(context).primaryColor,
      backgroundColor: Colors.grey[200],
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
  }

  Widget _buildStatusChip(String label, String value) {
    final counts = _getOrderCounts();
    String displayLabel = label;

    // Only add count for specific statuses (not 'all')
    if (value != 'all') {
      int count = counts[value] ?? 0;
      displayLabel = '$label ($count)';
    }

    // Get the same color configuration as used in order tags
    final TagConfig colorConfig = _getTagConfig(TagType.status, value);

    return FilterChip(
      label: Text(
        displayLabel,
        style: TextStyle(
          fontSize: 11,
          color: _statusFilter == value ? Colors.white : colorConfig.textColor,
        ),
      ),
      selected: _statusFilter == value,
      onSelected: (selected) {
        setState(() => _statusFilter = selected ? value : 'all');
      },
      selectedColor: colorConfig.borderColor,  // Use the main color when selected
      backgroundColor: colorConfig.backgroundColor,  // Use the light background when unselected
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: colorConfig.borderColor,
        ),
      ),
    );
  }
  
  Widget _buildSearchField(String label, IconData icon, Function(String) onChanged) {
    return SizedBox(
      height: 40,
      child: TextField(
        style: TextStyle(fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 12),
          prefixIcon: Icon(icon, size: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          isDense: true,
        ),
        onChanged: onChanged,
      ),
    );
  }

// Helper method for dropdown fields
  Widget _buildDropdownField(String label, String value, List<DropdownMenuItem<String>> items, Function(String?) onChanged) {
    return SizedBox(
      height: 40,
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        style: TextStyle(fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          isDense: true,
        ),
        items: items.map((item) => DropdownMenuItem<String>(
          value: item.value,
          child: Text(item.child.toString(), style: TextStyle(fontSize: 12)),
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }

// Helper method for time filter chips
  Widget _buildTimeFilterChip(String label, String value) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(fontSize: 11),
      ),
      selected: _timeFilter == value,
      onSelected: (selected) {
        setState(() {
          _timeFilter = selected ? value : 'all';
          _dateRange = selected ? _getTimeFilterDateRange() : null;
        });
      },
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      visualDensity: VisualDensity.compact,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
            _buildInfoRow(Icons.timer, _formatDuration(order['duration_minutes'] ?? 60)),
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
                  _buildDetailRow('Duration', _formatDuration(order['duration_minutes'] ?? 60)),
                ]),

                SizedBox(height: 16),
                _buildSectionTitle('Order Items'),
                _buildPackageDetails(order, order['package_details']),

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (order['is_room_only'] == true) ...[
                        Text(
                          'Room Only Booking',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Duration: ${_formatDuration(order['duration_minutes'] ?? 60)}',
                              style: TextStyle(fontSize: 14),
                            ),
                            Text(
                              'Price/Hour: ${_formatPrice(order['room_price_per_hour'] ?? 0)}',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        Divider(height: 16),
                      ] else if (order['package_details']?.isNotEmpty == true) ...[
                        Text(
                          'Package Booking',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          order['package_details'],
                          style: TextStyle(fontSize: 14),
                        ),
                        Divider(height: 16),
                      ],
                      Row(
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
                            _formatPrice(
                                order['is_room_only'] == true
                                    ? ((order['duration_minutes'] ?? 60) / 60 * (order['room_price_per_hour'] ?? 0)).round()
                                    : (order['total_price'] ?? 0)
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green[800],
                            ),
                          ),
                        ],
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

  Widget _buildPackageDetails(dynamic order, String? packageDetails) {
    if (order['is_room_only'] == true) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Center(
          child: Text(
            'Room Only Booking',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

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
    // Only show buttons based on order status
    if (order['status'] == 'completed' || order['status'] == 'cancelled') {
      return Container();
    }

    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            Icons.edit,
                () => _onEditPressed(order),
            'Edit',
            isEdit: true,  // Add this parameter
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildActionButton(
              Icons.check_circle,
                  () => _onCompletePressed(order),
              'Selesai'
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildActionButton(
              Icons.cancel,
                  () => _onCancelPressed(order),
              'Batalkan',
              isDestructive: true
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onPressed, String label, {bool isDestructive = false, bool isEdit = false}) {
    final Color buttonColor = isDestructive
        ? Colors.red
        : isEdit
        ? Colors.amber[700]!  // Yellow/amber color for edit
        : Colors.green;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: buttonColor),
      label: Text(
          label,
          style: TextStyle(
              fontSize: 12,
              color: buttonColor
          )
      ),
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 8),
        side: BorderSide(
            color: isDestructive
                ? Colors.red[400]!
                : isEdit
                ? Colors.amber[600]!  // Yellow/amber border for edit
                : Colors.green[400]!
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
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

  void _onCompletePressed(dynamic order) {
    final orderId = order['order_id']?.substring(0, 8) ?? 'N/A';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        title: Column(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
            SizedBox(height: 8),
            Text('Selesaikan Order #$orderId'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apakah Anda yakin ingin menyelesaikan order ini?'),
            SizedBox(height: 12),
            Text(
              'Tindakan ini akan mengubah status order menjadi "Selesai" dan tidak dapat diubah kembali.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);

              try {
                final response = await http.put(
                  Uri.parse('${Env.apiUrl}/api/orders/${order['order_id']}/status'),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({'status': 'completed'}), // Changed from 'delivered' to 'completed'
                );

                if (response.statusCode == 200) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Order #$orderId telah berhasil diselesaikan'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.green,
                        action: SnackBarAction(
                          label: 'OK',
                          textColor: Colors.white,
                          onPressed: () {},
                        ),
                      ),
                    );
                    _refreshPage();
                  }
                } else {
                  throw Exception('Gagal memperbarui status order: ${response.statusCode}');
                }
              } catch (e) {
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Error'),
                      content: Text('Gagal menyelesaikan order: ${e.toString()}'),
                      actions: [
                        TextButton(
                          child: Text('OK'),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('Ya, Selesaikan'),
          ),
        ],
      ),
    );
  }


  void _onEditPressed(dynamic order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckOrderEdit(
          orderData: order,
        ),
      ),
    ).then((updated) {
      if (updated == true) {
        _refreshPage();
      }
    });
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
            SizedBox(height: 8),
            Text('Batalkan Order #$orderId'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apakah Anda yakin ingin membatalkan order ini?'),
            SizedBox(height: 12),
            Text(
              'Perhatian: Tindakan ini tidak dapat dibatalkan dan akan mengubah status order menjadi "Dibatalkan".',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);

              try {
                final response = await http.put(
                  Uri.parse('${Env.apiUrl}/api/orders/${order['order_id']}/status'),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({'status': 'cancelled'}),
                );

                if (response.statusCode == 200) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Order #$orderId telah dibatalkan'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.red,
                        action: SnackBarAction(
                          label: 'OK',
                          textColor: Colors.white,
                          onPressed: () {},
                        ),
                      ),
                    );
                    _refreshPage();
                  }
                } else {
                  throw Exception('Gagal memperbarui status order');
                }
              } catch (e) {
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Error'),
                      content: Text('Gagal membatalkan order: ${e.toString()}'),
                      actions: [
                        TextButton(
                          child: Text('OK'),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Ya, Batalkan'),
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