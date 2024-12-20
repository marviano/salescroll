import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../MasterUser.dart';
import '../services/env.dart';
import '../CreateNewOrder.dart';
import '../CustomerRegistration.dart';
import '../MasterRestaurant.dart';
import '../MasterCustomer.dart';
import '../CheckOrder.dart';
import '../login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../Dashboard.dart';
import '../RoleManagementPage.dart';
import '../UserRoleAssignment.dart';
import '../ExportOrder.dart';
import '../ExportCustomerProfile.dart';
import '../Sales_Scroll/SalesScroll.dart';

enum ActivePage {
  dashboard,
  salesCustomerEnrollment,
  customerRegistration,
  masterPackage,
  masterRestaurant,
  masterCustomer,
  checkOrder,
  login,
  roleManagement,
  userRoleAssignment,
  masterUser,
  exportOrder,
  exportCustomer,
  salesScroll,
}

class BurgerMenu extends StatefulWidget {
  final Widget child;
  final String topBarTitle;
  final ActivePage activePage;
  final VoidCallback? onRefresh;
  final Color backgroundColor;

  const BurgerMenu({
    Key? key,
    required this.child,
    required this.topBarTitle,
    required this.activePage,
    this.onRefresh,
    this.backgroundColor = Colors.white,
  }) : super(key: key);

  @override
  _BurgerMenuState createState() => _BurgerMenuState();
}

class _BurgerMenuState extends State<BurgerMenu> {
  List<Map<String, dynamic>>? _permissions;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
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
      );

      if (response.statusCode == 200) {
        setState(() {
          _permissions = List<Map<String, dynamic>>.from(json.decode(response.body));
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load permissions');
      }
    } catch (e) {
      print('Error loading permissions: $e');
      setState(() => _isLoading = false);
    }
  }

  bool _hasPermission(String resource, String action) {
    return _permissions?.any(
            (p) => p['resource'] == resource && p['action'] == action
    ) ?? false;
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
          SnackBar(content: Text('Logged out successfully')),
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
          SnackBar(content: Text('Failed to log out. Please try again.')),
        );
      }
    }
  }

  Future<void> _confirmAndLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Logout'),
          content: Text('Are you sure you want to logout? This will clear app data and notifications.'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Logout'),
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
    final List<Widget> menuItems = [
      DrawerHeader(
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
        ),
        child: Text(
          'Menu',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
          ),
        ),
      ),
      _buildListTile(
        context,
        'Home',
        Icons.home,
        ActivePage.dashboard,
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DashboardPage()),
        ),
      ),
    ];

    if (_hasPermission('sales_management', 'view')) {  // Add appropriate permission
      menuItems.add(_buildListTile(
        context,
        'Sales Management',
        Icons.trending_up,
        ActivePage.salesScroll,
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SalesScroll()),
        ),
      ));
    }

    // Order Registration
    if (_hasPermission('order_registration', 'view')) {
      menuItems.add(_buildListTile(
        context,
        'Pendaftaran Order',
        Icons.assignment,
        ActivePage.salesCustomerEnrollment,
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SalesCustomerEnrollmentPage()),
        ),
      ));
    }

    // Customer Registration
    if (_hasPermission('customer_registration', 'view')) {
      menuItems.add(_buildListTile(
        context,
        'Pendaftaran Data Customer',
        Icons.person_add,
        ActivePage.customerRegistration,
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CustomerRegistrationPage()),
        ),
      ));
    }

    // Check Order
    if (_hasPermission('check_order', 'view')) {
      menuItems.add(_buildListTile(
        context,
        'Check Order',
        Icons.list_alt,
        ActivePage.checkOrder,
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CheckOrderPage()),
        ),
      ));
    }

    // Export Data
    if (_hasPermission('data_export', 'view')) {
      menuItems.add(_buildListTile(
        context,
        'Export Order Data',
        Icons.receipt_long,
        ActivePage.exportOrder,  // Add this to your ActivePage enum
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ExportOrderPage()),
        ),
      ));

      menuItems.add(_buildListTile(
        context,
        'Export Customer Data',
        Icons.people_outline,
        ActivePage.exportCustomer,
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ExportCustomerProfilePage()),
        ),
      ));
    }

    // Master Restaurant
    if (_hasPermission('master_restaurant', 'view')) {
      menuItems.add(_buildListTile(
        context,
        'Master Restaurant',
        Icons.restaurant,
        ActivePage.masterRestaurant,
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MasterRestaurantPage()),
        ),
      ));
    }

    // Master Customer
    if (_hasPermission('master_customer', 'view')) {
      menuItems.add(_buildListTile(
        context,
        'Master Customer',
        Icons.account_box_rounded,
        ActivePage.masterCustomer,
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MasterCustomerPage()),
        ),
      ));
    }

    // Master User
    if (_hasPermission('master_user', 'view')) {
      menuItems.add(_buildListTile(
        context,
        'Master User',
        Icons.people,
        ActivePage.masterUser,
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MasterUserPage()),
        ),
      ));
    }

    // Role Management
    if (_hasPermission('role_management', 'view')) {
      menuItems.add(_buildListTile(
        context,
        'Role Management',
        Icons.admin_panel_settings,
        ActivePage.roleManagement,
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => RoleManagementPage()),
        ),
      ));

      menuItems.add(_buildListTile(
        context,
        'User Role Assignment',
        Icons.manage_accounts,
        ActivePage.userRoleAssignment,
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => UserRoleAssignmentPage()),
        ),
      ));
    }

    menuItems.addAll([
      Divider(),
      ListTile(
        leading: Icon(Icons.logout),
        title: Text('Logout'),
        onTap: () => _confirmAndLogout(context),
      ),
    ]);

    return menuItems;
  }

  Widget _buildListTile(BuildContext context, String title, IconData icon, ActivePage page, VoidCallback onTap) {
    final isActive = widget.activePage == page;
    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? Theme.of(context).primaryColor : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isActive ? Theme.of(context).primaryColor : null,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      tileColor: isActive ? Colors.grey[200] : null,
      onTap: () {
        Navigator.pop(context); // Close the drawer
        if (!isActive) {
          onTap();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      appBar: AppBar(
        backgroundColor: widget.backgroundColor,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(widget.topBarTitle),
        actions: [
          if (widget.onRefresh != null)
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: widget.onRefresh,
            ),
        ],
      ),
      drawer: _isLoading
          ? const Drawer(child: Center(child: CircularProgressIndicator()))
          : Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: _buildMenuItems(context),
        ),
      ),
      body: widget.child,
    );
  }
}