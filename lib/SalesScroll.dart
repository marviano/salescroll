// lib/SalesScroll.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SalesScroll extends StatefulWidget {
  const SalesScroll({Key? key}) : super(key: key);

  @override
  _SalesScrollState createState() => _SalesScrollState();
}

class _SalesScrollState extends State<SalesScroll> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildTabBar(),
          Expanded(child: _buildTabBarView()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCustomerDialog(),
        child: const Icon(Icons.add),
      ),
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
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      tabs: const [
        Tab(text: 'All Customers'),
        Tab(text: 'My Customers'),
        Tab(text: 'Follow-ups'),
        Tab(text: 'Analytics'),
      ],
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      controller: _tabController,
      children: [
        CustomerListTab(customers: _getAllCustomers()),
        CustomerListTab(customers: _getMyCustomers()),
        FollowUpsTab(followUps: _getFollowUps()),
        AnalyticsTab(analytics: _getAnalytics()),
      ],
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
      builder: (context) => const FilterDialog(),
    );
  }

  void _showAnalyticsDialog() {
    showDialog(
      context: context,
      builder: (context) => const AnalyticsDialog(),
    );
  }

  List<Customer> _getAllCustomers() => [];
  List<Customer> _getMyCustomers() => [];
  List<FollowUp> _getFollowUps() => [];
  Analytics _getAnalytics() => Analytics();
}

// lib/widgets/customer_list_tab.dart
class CustomerListTab extends StatelessWidget {
  final List<Customer> customers;

  const CustomerListTab({Key? key, required this.customers}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: customers.length,
      itemBuilder: (context, index) => CustomerListItem(customer: customers[index]),
    );
  }
}

class CustomerListItem extends StatelessWidget {
  final Customer customer;

  const CustomerListItem({Key? key, required this.customer}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: _buildLeadingIcon(),
        title: Text(customer.name),
        subtitle: Text(customer.company ?? ''),
        trailing: _buildTrailingButtons(),
        onTap: () => _showCustomerDetails(context),
      ),
    );
  }

  Widget _buildLeadingIcon() {
    return CircleAvatar(
      backgroundColor: _getStatusColor(),
      child: Text(customer.name[0]),
    );
  }

  Widget _buildTrailingButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.phone),
          onPressed: () => _makeCall(),
        ),
        IconButton(
          icon: const Icon(Icons.message),
          onPressed: () => _sendMessage(),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (customer.salesStatus) {
      case 'cold': return Colors.blue;
      case 'warm': return Colors.orange;
      case 'hot': return Colors.red;
      default: return Colors.grey;
    }
  }

  void _showCustomerDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => CustomerDetailsSheet(customer: customer),
    );
  }

  void _makeCall() {}
  void _sendMessage() {}
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

// lib/models/customer.dart
class Customer {
  final String id;
  final String name;
  final String? company;
  final String phoneNumber;
  final String salesStatus;
  final String? boundToUid;

  Customer({
    required this.id,
    required this.name,
    this.company,
    required this.phoneNumber,
    required this.salesStatus,
    this.boundToUid,
  });
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