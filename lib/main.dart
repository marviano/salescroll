import 'package:flutter/material.dart';
import 'SalesCustomerEnrollment.dart'; // Import the new file

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Restaurant Sales App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SalesCustomerEnrollmentPage(),
    );
  }
}