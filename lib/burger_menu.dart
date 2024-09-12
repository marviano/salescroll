import 'package:flutter/material.dart';
import 'package:salescroll/MasterCustomer.dart';
import 'SalesCustomerEnrollment.dart';
import 'CustomerRegistration.dart';
import 'MasterRestaurant.dart';
import 'MasterCustomer.dart';

enum ActivePage {
  salesCustomerEnrollment,
  customerRegistration,
  masterPackage,
  masterRestaurant,
  masterCustomer,
}

class BurgerMenu extends StatelessWidget {
  final Widget child;
  final String topBarTitle;
  final ActivePage activePage;

  const BurgerMenu({
    Key? key,
    required this.child,
    required this.topBarTitle,
    required this.activePage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(topBarTitle),
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
            // _buildListTile(
            //   context,
            //   'Master Paket',
            //   Icons.inventory,
            //   ActivePage.masterPackage,
            //       () {
            //     // Add navigation to Master Paket page when it's created
            //     Navigator.pop(context);
            //   },
            // ),
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