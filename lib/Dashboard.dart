import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:salescroll/widgets/network_error_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'MasterUser.dart';
import 'Sales_Scroll/SalesScroll.dart';
import 'services/env.dart';
import 'CreateNewOrder.dart';
import 'CustomerRegistration.dart';
import 'MasterRestaurant.dart';
import 'MasterCustomer.dart';
import 'CheckOrder.dart';
import 'RoleManagementPage.dart';
import 'login.dart';
import 'UserRoleAssignment.dart';
import 'ExportOrder.dart';
import 'ExportCustomerProfile.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Map<String, dynamic>>? _permissions;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _displayName;
  bool _isLoadingName = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadUserDisplayName();
  }

  Future<void> _loadUserDisplayName() async {
    if (!mounted) return;

    setState(() {
      _isLoadingName = true;
      _loadError = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Print debug information
      print('DEBUG: Loading display name for user: ${user.uid}');

      final idToken = await user.getIdToken();
      print('DEBUG: Got ID token');

      // Changed from /api/users/{uid} to /api/users/profile/{uid}
      final apiUrl = '${Env.apiUrl}/api/users/profile/${user.uid}';
      print('DEBUG: Calling API: $apiUrl');

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timed out'),
      );

      print('DEBUG: API Response Status: ${response.statusCode}');
      print('DEBUG: API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        if (mounted) {
          setState(() {
            _displayName = userData['display_name'];
            _isLoadingName = false;
          });
          print('DEBUG: Display name loaded: $_displayName');
        }
      } else {
        throw Exception('Failed to load user data: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG: Error loading user display name: $e');
      if (mounted) {
        setState(() {
          _loadError = 'Failed to load user data';
          _isLoadingName = false;
        });
      }
    }
  }

  Future<void> _refreshPage() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    try {
      await _loadPermissions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Page refreshed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        NetworkErrorNotifier.instance.notifyError();
        setState(() => _permissions = null);
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _loadPermissions() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      final response = await http.get(
        Uri.parse('${Env.apiUrl}/api/users/permissions'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _permissions = List<Map<String, dynamic>>.from(json.decode(response.body));
          _isLoading = false;
        });
        NetworkErrorNotifier.instance.clearError();
      } else {
        setState(() => _permissions = null);
        throw Exception('Failed to load permissions');
      }
    } catch (e) {
      print('Error loading permissions: $e');
      setState(() {
        _permissions = null;
        _isLoading = false;
      });
      NetworkErrorNotifier.instance.notifyError();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await FirebaseMessaging.instance.deleteToken();
      final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
      await notifications.cancelAll();
      if (Platform.isAndroid) {
        final androidPlugin = notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.deleteNotificationChannel('meeting_notifications');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      final cacheDir = await getTemporaryDirectory();
      if (cacheDir.existsSync()) {
        try {
          await cacheDir.delete(recursive: true);
        } catch (e) {
          print('Debug: Error clearing cache: $e');
        }
      }
      await FirebaseAuth.instance.signOut();
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged out successfully')),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginPage()),
              (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      print('Error during logout: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to log out. Please try again.')),
        );
      }
    }
  }

  Future<void> _confirmAndLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to logout? This will clear app data and notifications.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Logout'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await _handleLogout(context);
    }
  }

  List<Widget> _buildMenuItems(BuildContext context) {
    final List<Widget> menuItems = [];

    if (_hasPermission('sales_management', 'view')) {
      menuItems.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _buildMenuCard(
            context,
            title: 'Sales Management',
            icon: Icons.trending_up,
            color: Colors.purple,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SalesScroll()),
            ),
          ),
        ),
      );
    }

    // First row - two items
    if (_hasPermission('order_registration', 'view') || _hasPermission('check_order', 'view')) {
      menuItems.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_hasPermission('order_registration', 'view'))
                Expanded(
                  child: _buildMenuCard(
                    context,
                    title: 'Pendaftaran Order',
                    icon: Icons.assignment,
                    color: Colors.blue,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SalesCustomerEnrollmentPage()),
                    ),
                  ),
                ),
              if (_hasPermission('order_registration', 'view') && _hasPermission('check_order', 'view'))
                const SizedBox(width: 12),
              if (_hasPermission('check_order', 'view'))
                Expanded(
                  child: _buildMenuCard(
                    context,
                    title: 'Check Order',
                    icon: Icons.list_alt,
                    color: Colors.orange,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CheckOrderPage()),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Second row - single item
    if (_hasPermission('customer_registration', 'view')) {
      menuItems.add(
        Padding(
          padding: const EdgeInsets.only(top: 12.0, left: 16.0, right: 16.0),
          child: _buildMenuCard(
            context,
            title: 'Pendaftaran Data Customer',
            icon: Icons.person_add,
            color: Colors.green,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CustomerRegistrationPage()),
            ),
          ),
        ),
      );
    }

    if (_hasPermission('data_export', 'view')) {
      menuItems.add(
        Padding(
          padding: const EdgeInsets.only(top: 12.0, left: 16.0, right: 16.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ExpansionTile(
              title: Text('Export Data', style: TextStyle(fontWeight: FontWeight.bold)),
              leading: Icon(Icons.download, color: Colors.purple),
              children: [
                _buildSubmenuItem(
                  context,
                  title: 'Export Order Data',
                  icon: Icons.receipt_long,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ExportOrderPage()),  // Changed this line
                  ),
                ),
                _buildSubmenuItem(
                  context,
                  title: 'Export Customer Data',
                  icon: Icons.people,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ExportCustomerProfilePage()),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Master Group
    if (_hasPermission('master_user', 'view') ||
        _hasPermission('master_restaurant', 'view') ||
        _hasPermission('master_customer', 'view')) {
      menuItems.add(
        Padding(
          padding: const EdgeInsets.only(top: 12.0, left: 16.0, right: 16.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ExpansionTile(
              title: Text('Data Master', style: TextStyle(fontWeight: FontWeight.bold)),
              leading: Icon(Icons.folder, color: Colors.indigo),
              children: [
                if (_hasPermission('master_user', 'view'))
                  _buildSubmenuItem(
                    context,
                    title: 'Data Pengguna',
                    icon: Icons.people,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MasterUserPage()),
                    ),
                  ),
                if (_hasPermission('master_restaurant', 'view'))
                  _buildSubmenuItem(
                    context,
                    title: 'Data Restoran',
                    icon: Icons.restaurant,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MasterRestaurantPage()),
                    ),
                  ),
                if (_hasPermission('master_customer', 'view'))
                  _buildSubmenuItem(
                    context,
                    title: 'Data Customer',
                    icon: Icons.account_box_rounded,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MasterCustomerPage()),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // User and Privileges Group
    if (_hasPermission('role_management', 'view')) {
      menuItems.add(
        Padding(
          padding: const EdgeInsets.only(top: 12.0, left: 16.0, right: 16.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ExpansionTile(
              title: Text('Pengguna & Hak Akses', style: TextStyle(fontWeight: FontWeight.bold)),
              leading: Icon(Icons.admin_panel_settings, color: Colors.teal),
              children: [
                _buildSubmenuItem(
                  context,
                  title: 'Manajemen Peran',
                  icon: Icons.admin_panel_settings,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RoleManagementPage()),
                  ),
                ),
                _buildSubmenuItem(
                  context,
                  title: 'Penugasan Peran',
                  icon: Icons.manage_accounts,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => UserRoleAssignmentPage()),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return menuItems;
  }

  Widget _buildUserHeader() {
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            radius: 24,
            child: _isLoadingName
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : Text(
              (_displayName?.isNotEmpty == true
                  ? _displayName![0]
                  : user?.email?[0] ?? '')
                  .toUpperCase(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat datang,',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                if (_isLoadingName)
                  const SizedBox(
                    width: 100,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else if (_loadError != null)
                  Text(
                    'Error: $_loadError',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                  )
                else if (_displayName?.isNotEmpty == true)
                    Text(
                      _displayName!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      user?.email ?? 'No user data',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                if (_loadError != null)
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                    label: const Text(
                      'Retry',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    onPressed: _loadUserDisplayName,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmenuItem(
      BuildContext context, {
        required String title,
        required IconData icon,
        required VoidCallback onTap,
      }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    );
  }

  // Helper method for permission checking remains the same
  bool _hasPermission(String resource, String action) {
    return _permissions?.any(
            (p) => p['resource'] == resource && p['action'] == action
    ) ?? false;
  }

  Widget _buildMenuCard(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 140,    // Increased height
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),  // Increased vertical padding
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(height: 12),  // Increased spacing
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,     // Ensure text can use up to 2 lines
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return NetworkErrorHandler(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.white,
                                    radius: 24,
                                    child: Text(
                                      (_displayName?.isNotEmpty == true
                                          ? _displayName![0]
                                          : user?.email?[0] ?? '')
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Selamat datang,',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.9),
                                            fontSize: 14,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        if (_displayName?.isNotEmpty == true)
                                          Text(
                                            _displayName!,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        Text(
                                          user?.email ?? '',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.9),
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: _isRefreshing
                                  ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                                  : const Icon(Icons.refresh, color: Colors.white),
                              onPressed: _isRefreshing ? null : _refreshPage,
                              tooltip: 'Refresh page',
                            ),
                            IconButton(
                              icon: const Icon(Icons.logout, color: Colors.white),
                              onPressed: () => _confirmAndLogout(context),
                              tooltip: 'Logout',
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_permissions?.isNotEmpty == true) ...[
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_user,
                              size: 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              '${_permissions!.length} Active Permissions',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _permissions == null
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh,
                          size: 50, color: Colors.grey),
                      SizedBox(height: 16),
                      Padding(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Please refresh the page to load menu items',
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshPage,
                        child: Text('Refresh Now'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                )
                    : Center(
                  child: ConstrainedBox(
                    constraints:
                    BoxConstraints(maxWidth: 600),
                    child: ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: _buildMenuItems(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}