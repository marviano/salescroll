import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
// import 'package:salescroll/MasterCustomer.dart';
import '../SalesCustomerEnrollment.dart';
import '../CustomerRegistration.dart';
import '../MasterRestaurant.dart';
import '../MasterCustomer.dart';
import '../CheckOrder.dart';
import '../login.dart';

enum ActivePage {
  salesCustomerEnrollment,
  customerRegistration,
  masterPackage,
  masterRestaurant,
  masterCustomer,
  checkOrder,
  login,
}

class BurgerMenu extends StatelessWidget {
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

  Future<void> _handleLogout(BuildContext context) async {
    try {
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();

      // Sign out from Google
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logged out successfully')),
      );

      // Navigate to LoginPage and remove all previous routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
            (Route<dynamic> route) => false,
      );
    } catch (e) {
      print('Error during logout: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to log out. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(topBarTitle),
        actions: [
          if (onRefresh != null)
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: onRefresh,
            ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
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
              'Pendaftaran Order',
              Icons.assignment,
              ActivePage.salesCustomerEnrollment,
                  () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SalesCustomerEnrollmentPage()),
              ),
            ),
            _buildListTile(
              context,
              'Pendaftaran Data Customer',
              Icons.person_add,
              ActivePage.customerRegistration,
                  () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CustomerRegistrationPage()),
              ),
            ),
            _buildListTile(
              context,
              'Check Order',
              Icons.list_alt,
              ActivePage.checkOrder,
                  () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CheckOrderPage()),
              ),
            ),
            _buildListTile(
              context,
              'Master Restaurant',
              Icons.restaurant,
              ActivePage.masterRestaurant,
                  () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MasterRestaurantPage()),
              ),
            ),
            _buildListTile(
              context,
              'Master Customer',
              Icons.account_box_rounded,
              ActivePage.masterCustomer,
                  () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MasterCustomerPage()),
              ),
            ),
            // _buildListTile(
            //   context,
            //   'Login',
            //   Icons.login,
            //   ActivePage.login,
            //       () => Navigator.push(
            //     context,
            //     MaterialPageRoute(builder: (context) => LoginPage()),
            //   ),
            // ),
            Divider(),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: () => _handleLogout(context),
            ),
          ],
        ),
      ),
      body: child,
    );
  }

  Widget _buildListTile(BuildContext context, String title, IconData icon, ActivePage page, VoidCallback onTap) {
    final isActive = activePage == page;
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
}