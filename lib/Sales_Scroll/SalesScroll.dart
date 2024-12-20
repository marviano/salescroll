// lib/SalesScroll.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../Sales_Scroll/models/customer.dart';
import '../Sales_Scroll/services/sales_service.dart';
import '../Sales_Scroll/widgets/customer_list_item.dart';

class SalesScroll extends StatefulWidget {
  const SalesScroll({Key? key}) : super(key: key);

  @override
  _SalesScrollState createState() => _SalesScrollState();
}

class _SalesScrollState extends State<SalesScroll> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();
  final SalesService _salesService = SalesService();

  String _currentStatusFilter = 'all';

  bool _isLoading = false;
  bool _isGlobalLoading = false;

  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _loadCustomers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged() async {
    _filterCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      final customers = await _salesService.getCustomers();
      setState(() {
        _customers = customers;
        _filterCustomers();
      });
    } catch (e, stackTrace) {
      print('Error: $e');
      print('Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading customers: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterCustomers() {
    setState(() {
      final searchTerm = _searchController.text.toLowerCase();
      _filteredCustomers = _customers.where((customer) {
        final matchesSearch = customer.name.toLowerCase().contains(searchTerm) ||
            (customer.company?.toLowerCase().contains(searchTerm) ?? false);
        final matchesStatus = _currentStatusFilter == 'all' ||
            customer.salesStatus.toLowerCase() == _currentStatusFilter;
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

// In _bindCustomer method
  Future<void> _bindCustomer(Customer customer) async {
    setState(() => _isGlobalLoading = true);
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to bind customers')),
        );
        return;
      }

      await _salesService.bindCustomer(
        customerId: customer.id,
        agentUid: currentUser.uid,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer bound successfully. You must follow up within 3 hours.'),
          duration: Duration(seconds: 5),
        ),
      );

      await _loadCustomers();
      _tabController.animateTo(1);
    } finally {
      if (mounted) setState(() => _isGlobalLoading = false);
    }
  }

  Future<void> _confirmBinding(Customer customer, String contactMethod) async {
    setState(() => _isGlobalLoading = true);
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to confirm binding')),
        );
        return;
      }

      await _salesService.confirmBinding(
        customerId: customer.id,
        agentUid: currentUser.uid,
        contactMethod: contactMethod,
        contactStatus: 'successful',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Binding confirmed successfully')),
      );

      await _loadCustomers();
    } finally {
      if (mounted) setState(() => _isGlobalLoading = false);
    }
  }

  Future<void> _releaseCustomer(Customer customer) async {
    setState(() => _isGlobalLoading = true);
    try {
      await _salesService.releaseCustomer(
        customerId: customer.id,
        reason: 'Manual release',
      );
      await _loadCustomers();
    } finally {
      if (mounted) setState(() => _isGlobalLoading = false);
    }
  }

  Future<void> _handleContact(Customer customer, String contactMethod) async {
    setState(() => _isGlobalLoading = true);
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to contact customers')),
        );
        return;
      }

      final now = DateTime.now();

      // Check if this is an overdue contact
      final isOverdueContact = customer.boundToUid == currentUser.uid &&
          customer.bindingStartDate != null &&
          now.difference(customer.bindingStartDate!).inHours >= 3;

      try {
        // Add the contact record with auto confirmation for overdue contacts
        await _salesService.addCustomerContact(
          customerId: customer.id,
          contactedByUid: currentUser.uid,
          contactMethod: contactMethod,
          contactStatus: 'successful',
          // Set next follow-up date to 24 hours from now
          nextFollowUpDate: now.add(const Duration(hours: 24)),
          notes: isOverdueContact ? 'Overdue contact completed' : 'Regular follow-up',
          isOverdueContact: isOverdueContact, // Pass this flag to backend
        );

        // Reload the customers data to update UI
        await _loadCustomers();

        // Show success message
        String message = isOverdueContact
            ? 'Contact recorded and overdue status cleared!'
            : 'Contact successful! Next follow-up in 24 hours.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
          ),
        );
      } catch (e) {
        throw Exception('Failed to process contact: $e');
      }
    } catch (e) {
      print('Error in handleContact: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error contacting customer: $e')),
      );
    } finally {
      if (mounted) setState(() => _isGlobalLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: _buildAppBar(),
          body: Column(
            children: [
              _buildSearchBar(),
              _buildTabBar(),
              Expanded(child: _buildTabBarView()),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _isGlobalLoading ? null : () => _showAddCustomerDialog(),
            child: const Icon(Icons.add),
          ),
        ),
        if (_isGlobalLoading)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black26,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }


  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Sales Scroll'),
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: () => _showFilterDialog(),
        ),
        IconButton(
          icon: const Icon(Icons.analytics),
          onPressed: () => _showAnalyticsDialog(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search customers...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final currentUser = _auth.currentUser;
    int urgentCustomersCount = 0;

    if (currentUser != null) {
      print('DEBUG COUNT: Checking urgent customers for ${currentUser.uid}');

      urgentCustomersCount = _customers.where((c) {
        // Customer is bound to current user
        if (c.boundToUid != currentUser.uid) return false;

        if (c.bindingStatus == 'bound') {
          // Debug each condition
          print('DEBUG COUNT: Checking customer ${c.name}:');
          print('  binding_status: ${c.bindingStatus}');
          print('  binding_start_date: ${c.bindingStartDate}');
          print('  last_interaction_date: ${c.lastInteractionDate}');

          // Case 1: Newly bound customer with no interaction
          if (c.bindingStartDate != null && c.lastInteractionDate == null) {
            print('  URGENT: New binding without interaction');
            return true;
          }

          // Case 2: Customer with overdue initial contact (> 3 hours)
          if (c.bindingStartDate != null && c.lastInteractionDate == null &&
              DateTime.now().difference(c.bindingStartDate!).inHours >= 3) {
            final hours = DateTime.now().difference(c.bindingStartDate!).inHours;
            print('  Hours since binding: $hours');
            print('  URGENT: Over 3 hours without contact');
            return true;
          }

          // Case 3: Regular follow-up is due
          if (c.isFollowUpDue) {
            print('  URGENT: Follow-up is due');
            return true;
          }

          print('  Not urgent');
        }
        return false;
      }).length;

      print('DEBUG COUNT: Total urgent customers: $urgentCustomersCount');
    }

    return TabBar(
      controller: _tabController,
      isScrollable: true,
      tabs: [
        const Tab(text: 'All Customers'),
        Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('My Customers'),
              if (urgentCustomersCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$urgentCustomersCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Tab(text: 'Follow-ups'),
        const Tab(text: 'Analytics'),
      ],
    );
  }

  Widget _buildTabBarView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildCustomerList(),
        _buildMyCustomersList(),
        _buildFollowUpsList(),
        _buildAnalyticsView(),
      ],
    );
  }

  Widget _buildCustomerList() {
    final currentUser = _auth.currentUser;
    final filteredAndAvailableCustomers = _filteredCustomers.where((customer) {
      return customer.bindingStatus != 'bound';
    }).toList();

    return ListView.builder(
      itemCount: filteredAndAvailableCustomers.length,
      itemBuilder: (context, index) {
        final customer = filteredAndAvailableCustomers[index];
        return CustomerListItem(
          customer: customer,
          onTap: () => _showCustomerDetails(customer),
          onBind: () => _bindCustomer(customer),
          onRelease: () => _releaseCustomer(customer),
          onCall: () => _handleContact(customer, 'call'),
          onMessage: () => _handleContact(customer, 'whatsapp'),
        );
      },
    );
  }

  Widget _buildMyCustomersList() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Please login to view your customers'));
    }

    final myCustomers = _customers.where((c) =>
    c.boundToUid == currentUser.uid &&
        c.bindingStatus == 'bound'
    ).toList();

    print('DEBUG: Found ${myCustomers.length} bound customers'); // Add this debug line

    return ListView.builder(
      itemCount: myCustomers.length,
      itemBuilder: (context, index) {
        final customer = myCustomers[index];
        return CustomerListItem(
          customer: customer,
          onTap: () => _showCustomerDetails(customer),
          onRelease: () => _releaseCustomer(customer),
          onCall: () => _handleContact(customer, 'call'),
          onMessage: () => _handleContact(customer, 'whatsapp'),
        );
      },
    );
  }

  Widget _buildFollowUpsList() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Please login to view follow-ups'));
    }

    final followUps = _customers.where((c) =>
    c.boundToUid == currentUser.uid &&
        c.nextFollowUpDate != null &&
        c.nextFollowUpDate!.isBefore(DateTime.now())
    ).toList();

    return ListView.builder(
      itemCount: followUps.length,
      itemBuilder: (context, index) {
        final customer = followUps[index];
        return CustomerListItem(
          customer: customer,
          onTap: () => _showCustomerDetails(customer),
          onCall: () => _handleContact(customer, 'call'),
          onMessage: () => _handleContact(customer, 'whatsapp'),
        );
      },
    );
  }

  Widget _buildAnalyticsView() {
    return const Center(child: Text('Analytics Coming Soon'));
  }

  void _showCustomerDetails(Customer customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CustomerDetailsSheet(customer: customer),
    );
  }

  void _showAddCustomerDialog() {
    showDialog(
      context: context,
      builder: (context) => const AddCustomerDialog(),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Customers'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile(
                title: const Text('All'),
                value: 'all',
                groupValue: _currentStatusFilter,
                onChanged: (value) {
                  setState(() => _currentStatusFilter = value.toString());
                },
              ),
              RadioListTile(
                title: const Text('Cold'),
                value: 'cold',
                groupValue: _currentStatusFilter,
                onChanged: (value) {
                  setState(() => _currentStatusFilter = value.toString());
                },
              ),
              RadioListTile(
                title: const Text('Warm'),
                value: 'warm',
                groupValue: _currentStatusFilter,
                onChanged: (value) {
                  setState(() => _currentStatusFilter = value.toString());
                },
              ),
              RadioListTile(
                title: const Text('Hot'),
                value: 'hot',
                groupValue: _currentStatusFilter,
                onChanged: (value) {
                  setState(() => _currentStatusFilter = value.toString());
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _filterCustomers();
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showAnalyticsDialog() {
    showDialog(
      context: context,
      builder: (context) => const AnalyticsDialog(),
    );
  }
}

// lib/widgets/customer_list_tab.dart
class CustomerListTab extends StatelessWidget {
  final List<Customer> customers;
  final VoidCallback? onCustomerTap;
  final Future<void> Function(Customer)? onCustomerBind;
  final Future<void> Function(Customer)? onCustomerRelease;
  final Future<void> Function(Customer)? onCall;
  final Future<void> Function(Customer)? onMessage;

  const CustomerListTab({
    Key? key,
    required this.customers,
    this.onCustomerTap,
    this.onCustomerBind,
    this.onCustomerRelease,
    this.onCall,
    this.onMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: customers.length,
      itemBuilder: (context, index) => CustomerListItem(
        customer: customers[index],
        onTap: () => onCustomerTap?.call(),
        onBind: onCustomerBind != null ? () => onCustomerBind!(customers[index]) : null,
        onRelease: onCustomerRelease != null ? () => onCustomerRelease!(customers[index]) : null,
        onCall: onCall != null ? () => onCall!(customers[index]) : null,
        onMessage: onMessage != null ? () => onMessage!(customers[index]) : null,
      ),
    );
  }
}
// lib/widgets/follow_ups_tab.dart
class FollowUpsTab extends StatelessWidget {
  final List<FollowUp> followUps;

  const FollowUpsTab({Key? key, required this.followUps}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: followUps.length,
      itemBuilder: (context, index) => FollowUpListItem(followUp: followUps[index]),
    );
  }
}

class FollowUpListItem extends StatelessWidget {
  final FollowUp followUp;

  const FollowUpListItem({Key? key, required this.followUp}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(followUp.customer.name[0]),
        ),
        title: Text(followUp.customer.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Follow-up: ${DateFormat('MMM dd, yyyy').format(followUp.followUpDate)}'),
            Text(followUp.notes, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              onPressed: () => _markAsComplete(context),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editFollowUp(context),
            ),
          ],
        ),
        onTap: () => _showFollowUpDetails(context),
      ),
    );
  }

  void _markAsComplete(BuildContext context) {
    // Implement mark as complete logic
  }

  void _editFollowUp(BuildContext context) {
    // Implement edit follow-up logic
  }

  void _showFollowUpDetails(BuildContext context) {
    // Implement show details logic
  }
}

// lib/widgets/analytics_tab.dart
class AnalyticsTab extends StatelessWidget {
  final Analytics analytics;

  const AnalyticsTab({Key? key, required this.analytics}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildPerformanceCard(),
          _buildPipelineCard(),
          _buildContactMethodsCard(),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Performance Metrics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            // Add performance metrics widgets
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sales Pipeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            // Add pipeline visualization widgets
          ],
        ),
      ),
    );
  }

  Widget _buildContactMethodsCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contact Methods', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            // Add contact methods statistics widgets
          ],
        ),
      ),
    );
  }
}

// lib/models/follow_up.dart
class FollowUp {
  final String id;
  final Customer customer;
  final DateTime followUpDate;
  final String notes;

  FollowUp({
    required this.id,
    required this.customer,
    required this.followUpDate,
    required this.notes,
  });
}

// lib/models/analytics.dart
class Analytics {
  // Add analytics data properties
}

// lib/widgets/dialogs.dart
class AddCustomerDialog extends StatelessWidget {
  const AddCustomerDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Customer'),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Add form fields
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {},
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class FilterDialog extends StatelessWidget {
  const FilterDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Customers'),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Add filter options
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {},
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class AnalyticsDialog extends StatelessWidget {
  const AnalyticsDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Analytics Details'),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Add detailed analytics
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class CustomerDetailsSheet extends StatelessWidget {
  final Customer customer;

  const CustomerDetailsSheet({Key? key, required this.customer}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Customer Details', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          // Add customer details
        ],
      ),
    );
  }
}