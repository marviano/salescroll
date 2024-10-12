// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'services/env.dart';
//
// class LoginPage extends StatefulWidget {
//   @override
//   _LoginPageState createState() => _LoginPageState();
// }
//
// class _LoginPageState extends State<LoginPage> {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final GoogleSignIn googleSignIn = GoogleSignIn();
//   User? _user;
//   bool _isLoading = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _checkCurrentUser();
//   }
//
//   void _checkCurrentUser() {
//     _user = _auth.currentUser;
//     print('DEBUG: Current user: ${_user?.displayName ?? "None"}');
//   }
//
//   Future<User?> _handleSignIn() async {
//     try {
//       setState(() {
//         _isLoading = true;
//       });
//
//       print('DEBUG: Starting Google Sign In process');
//       final GoogleSignInAccount? googleSignInAccount = await googleSignIn.signIn();
//       if (googleSignInAccount != null) {
//         print('DEBUG: Google Sign In account selected');
//         final GoogleSignInAuthentication googleSignInAuthentication =
//         await googleSignInAccount.authentication;
//
//         final AuthCredential credential = GoogleAuthProvider.credential(
//           accessToken: googleSignInAuthentication.accessToken,
//           idToken: googleSignInAuthentication.idToken,
//         );
//
//         print('DEBUG: Signing in to Firebase');
//         final UserCredential authResult = await _auth.signInWithCredential(credential);
//         final User? user = authResult.user;
//
//         print('DEBUG: Firebase Sign In successful. User: ${user?.displayName}');
//
//         if (user != null) {
//           bool dbSaveSuccess = await _saveUserToDatabase(user);
//           if (!dbSaveSuccess) {
//             print('DEBUG: Failed to save user to database. Forcing logout.');
//             await _handleSignOut();
//             return null;
//           }
//         }
//
//         return user;
//       }
//     } catch (error) {
//       print('DEBUG: Error during Google sign in: $error');
//       return null;
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
//
//   Future<void> _handleSignOut() async {
//     try {
//       print('DEBUG: Starting Sign Out process');
//       await _auth.signOut();
//       await googleSignIn.signOut();
//       print('DEBUG: Sign Out successful');
//       setState(() {
//         _user = null;
//       });
//     } catch (error) {
//       print('DEBUG: Error during Sign Out: $error');
//     }
//   }
//
//   Future<bool> _saveUserToDatabase(User user) async {
//     final String apiUrl = '${Env.apiUrl}/api/users';
//
//     try {
//       print('DEBUG: Preparing user data for database insertion');
//
//       final userData = {
//         'firebase_uid': user.uid,
//         'email': user.email ?? '',
//         'display_name': user.displayName ?? '',
//       };
//
//       print('DEBUG: User data to be saved:');
//       userData.forEach((key, value) => print('DEBUG: $key: $value'));
//
//       final response = await http.post(
//         Uri.parse(apiUrl),
//         headers: <String, String>{
//           'Content-Type': 'application/json; charset=UTF-8',
//         },
//         body: jsonEncode(userData),
//       );
//
//       if (response.statusCode == 201) {
//         print('DEBUG: User data saved successfully to database');
//         return true;
//       } else {
//         print('DEBUG: Failed to save user data. Status code: ${response.statusCode}');
//         print('DEBUG: Response body: ${response.body}');
//         return false;
//       }
//     } catch (e) {
//       print('DEBUG: Error saving user data: $e');
//       return false;
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Login'),
//       ),
//       body: Center(
//         child: _isLoading
//             ? CircularProgressIndicator()
//             : Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             if (_user == null)
//               ElevatedButton(
//                 child: Text('Sign in with Google'),
//                 onPressed: () async {
//                   User? user = await _handleSignIn();
//                   if (user != null) {
//                     setState(() {
//                       _user = user;
//                     });
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(content: Text('Signed in: ${user.displayName}')),
//                     );
//                   } else {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(content: Text('Sign in failed')),
//                     );
//                   }
//                 },
//               )
//             else
//               Column(
//                 children: [
//                   Text('Welcome, ${_user!.displayName}!'),
//                   SizedBox(height: 20),
//                   Text('Email: ${_user!.email}'),
//                   SizedBox(height: 20),
//                   ElevatedButton(
//                     child: Text('Sign out'),
//                     onPressed: () async {
//                       await _handleSignOut();
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(content: Text('Signed out')),
//                       );
//                     },
//                   ),
//                 ],
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'services/env.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn googleSignIn = GoogleSignIn();
  User? _user;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
  }

  void _checkCurrentUser() {
    _user = _auth.currentUser;
    print('DEBUG: Current user: ${_user?.displayName ?? "None"}');
    if (_user != null) {
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacementNamed('/sales_customer_enrollment');
  }

  Future<User?> _handleSignIn() async {
    try {
      setState(() {
        _isLoading = true;
      });

      print('DEBUG: Starting Google Sign In process');
      final GoogleSignInAccount? googleSignInAccount = await googleSignIn.signIn();
      if (googleSignInAccount != null) {
        print('DEBUG: Google Sign In account selected');
        final GoogleSignInAuthentication googleSignInAuthentication =
        await googleSignInAccount.authentication;

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleSignInAuthentication.accessToken,
          idToken: googleSignInAuthentication.idToken,
        );

        print('DEBUG: Signing in to Firebase');
        final UserCredential authResult = await _auth.signInWithCredential(credential);
        final User? user = authResult.user;

        print('DEBUG: Firebase Sign In successful. User: ${user?.displayName}');

        if (user != null) {
          bool dbSaveSuccess = await _saveUserToDatabase(user);
          if (!dbSaveSuccess) {
            print('DEBUG: Failed to save user to database. Forcing logout.');
            await _handleSignOut();
            return null;
          }
          _navigateToHome();
        }

        return user;
      }
    } catch (error) {
      print('DEBUG: Error during Google sign in: $error');
      return null;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSignOut() async {
    try {
      print('DEBUG: Starting Sign Out process');
      await _auth.signOut();
      await googleSignIn.signOut();
      print('DEBUG: Sign Out successful');
      setState(() {
        _user = null;
      });
    } catch (error) {
      print('DEBUG: Error during Sign Out: $error');
    }
  }

  Future<bool> _saveUserToDatabase(User user) async {
    final String apiUrl = '${Env.apiUrl}/api/users';

    try {
      print('DEBUG: Preparing user data for database insertion');

      final userData = {
        'firebase_uid': user.uid,
        'email': user.email ?? '',
        'display_name': user.displayName ?? '',
      };

      print('DEBUG: User data to be saved:');
      userData.forEach((key, value) => print('DEBUG: $key: $value'));

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(userData),
      );

      if (response.statusCode == 201) {
        print('DEBUG: User data saved successfully to database');
        return true;
      } else {
        print('DEBUG: Failed to save user data. Status code: ${response.statusCode}');
        print('DEBUG: Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('DEBUG: Error saving user data: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
      ),
      body: Center(
        child: _isLoading
            ? CircularProgressIndicator()
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_user == null)
              ElevatedButton(
                child: Text('Sign in with Google'),
                onPressed: () async {
                  User? user = await _handleSignIn();
                  if (user != null) {
                    setState(() {
                      _user = user;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Signed in: ${user.displayName}')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Sign in failed')),
                    );
                  }
                },
              )
            else
              Column(
                children: [
                  Text('Welcome, ${_user!.displayName}!'),
                  SizedBox(height: 20),
                  Text('Email: ${_user!.email}'),
                  SizedBox(height: 20),
                  ElevatedButton(
                    child: Text('Sign out'),
                    onPressed: () async {
                      await _handleSignOut();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Signed out')),
                      );
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}