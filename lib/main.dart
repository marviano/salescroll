// BEFORE APPLYING THE AUTH WRAPPER | UNTUK CEK USER-NYA SEDANG LOGIN ATAU TIDAK
// import 'package:flutter/material.dart';
// import 'SalesCustomerEnrollment.dart';
// import '../widgets/network_error_handler.dart';
// import 'package:firebase_core/firebase_core.dart';
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//   runApp(MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return NetworkErrorHandler(
//       child: MaterialApp(
//         title: 'Restaurant Sales App',
//         theme: ThemeData(
//           primarySwatch: Colors.blue,
//         ),
//         home: SalesCustomerEnrollmentPage(),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'MasterCustomer.dart';
import 'MasterRestaurant.dart';
import 'RestaurantPackages.dart';
import 'SalesCustomerEnrollment.dart';
import 'widgets/network_error_handler.dart';
import 'Login.dart';
import 'CustomerRegistration.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return NetworkErrorHandler(
      child: MaterialApp(
        title: 'Restaurant Sales App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: AuthWrapper(
          child: SalesCustomerEnrollmentPage(),
        ),
        routes: {
          '/login': (context) => LoginPage(),
          '/customer_registration': (context) => AuthWrapper(child: CustomerRegistrationPage()),
          '/master_customer': (context) => AuthWrapper(child: MasterCustomerPage()),
          '/master_restaurant': (context) => AuthWrapper(child: MasterRestaurantPage()),
          '/sales_customer_enrollment': (context) => AuthWrapper(child: SalesCustomerEnrollmentPage()),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final Widget child;

  const AuthWrapper({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;
          if (user == null) {
            return LoginPage();
          }
          return child;
        }
        return Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}