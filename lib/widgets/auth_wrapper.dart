import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Login.dart';

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
        return CircularProgressIndicator();
      },
    );
  }
}