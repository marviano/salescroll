import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'services/env.dart';
import 'SalesCustomerEnrollment.dart';
import 'Dashboard.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
    _setupFCM();
  }

  // FCM Setup and Token Management
  Future<void> _setupFCM() async {
    try {
      // Request notification permission
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      print('DEBUG: Notification authorization status: ${settings.authorizationStatus}');

      // Handle token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
        print('DEBUG: FCM Token refreshed');
        _updateFCMToken(token);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('DEBUG: Received foreground message:');
        print('DEBUG: Title: ${message.notification?.title}');
        print('DEBUG: Body: ${message.notification?.body}');
        print('DEBUG: Data: ${message.data}');
      });
    } catch (e) {
      print('DEBUG: Error setting up FCM: $e');
    }
  }

  Future<String?> _getFCMToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      print('DEBUG: Got FCM token: ${token?.substring(0, 20)}...');
      return token;
    } catch (e) {
      print('DEBUG: Error getting FCM token: $e');
      return null;
    }
  }

  Future<void> _updateFCMToken(String token) async {
    if (_auth.currentUser == null) return;

    try {
      final response = await http.post(
        Uri.parse('${Env.apiUrl}/api/users/fcm-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firebase_uid': _auth.currentUser!.uid,
          'fcm_token': token,
        }),
      );

      if (response.statusCode == 200) {
        print('DEBUG: FCM token updated successfully');
      } else {
        print('DEBUG: Failed to update FCM token. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG: Error updating FCM token: $e');
    }
  }

  // User Management
  void _checkCurrentUser() {
    _user = _auth.currentUser;
    print('DEBUG: Current user: ${_user?.displayName ?? "None"}');
    if (_user != null) {
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => DashboardPage()),
    );
  }

  Future<User?> _handleSignIn() async {
    try {
      print('\n====== STARTING SIGN IN PROCESS ======');
      print('DEBUG: Time: ${DateTime.now()}');

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Google Sign In
      print('\n----- GOOGLE SIGN IN ATTEMPT -----');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('DEBUG: Google Sign In cancelled by user');
        return null;
      }

      print('DEBUG: Google User Info:');
      print('- Email: ${googleUser.email}');
      print('- Display Name: ${googleUser.displayName}');
      print('- ID: ${googleUser.id}');

      // Get Google Auth Tokens
      print('\n----- GETTING GOOGLE AUTH TOKENS -----');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print('DEBUG: Got authentication tokens');
      print('- Access Token Length: ${googleAuth.accessToken?.length ?? 0}');
      print('- ID Token Length: ${googleAuth.idToken?.length ?? 0}');

      // Create Firebase Credential
      print('\n----- CREATING FIREBASE CREDENTIAL -----');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      print('DEBUG: Created Firebase credential');

      // Firebase Sign In
      print('\n----- FIREBASE SIGN IN ATTEMPT -----');
      final UserCredential authResult = await _auth.signInWithCredential(credential);
      final User? user = authResult.user;

      if (user != null) {
        print('DEBUG: Firebase Sign In successful');
        print('- UID: ${user.uid}');
        print('- Email: ${user.email}');
        print('- Display Name: ${user.displayName}');
        print('- Email Verified: ${user.emailVerified}');

        // Save user to database with FCM token
        print('\n----- SAVING USER TO DATABASE -----');
        bool dbSaveSuccess = await _saveUserToDatabase(user);

        if (!dbSaveSuccess) {
          print('ERROR: Failed to save user to database');
          await _handleSignOut();
          setState(() {
            _errorMessage = 'Failed to save user data. Please try again.';
          });
          return null;
        }

        _navigateToHome();
        return user;
      } else {
        print('ERROR: Firebase user is null after sign in');
        setState(() {
          _errorMessage = 'Sign in failed. Please try again.';
        });
        return null;
      }
    } catch (error, stackTrace) {
      print('\n====== ERROR IN SIGN IN PROCESS ======');
      print('DEBUG: Error type: ${error.runtimeType}');
      print('DEBUG: Error message: $error');
      print('DEBUG: Stack trace:\n$stackTrace');

      setState(() {
        _errorMessage = 'Sign in failed: ${error.toString()}';
      });
      return null;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSignOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      setState(() {
        _user = null;
        _errorMessage = null;
      });
      print('DEBUG: User signed out successfully');
    } catch (error) {
      print('DEBUG: Error during sign out: $error');
      setState(() {
        _errorMessage = 'Error signing out: ${error.toString()}';
      });
    }
  }

  Future<bool> _saveUserToDatabase(User user) async {
    final String apiUrl = '${Env.apiUrl}/api/users';

    try {
      print('\n----- API REQUEST DETAILS -----');
      print('DEBUG: API URL: $apiUrl');

      // Get FCM token
      String? fcmToken = await _getFCMToken();
      print('DEBUG: FCM Token obtained: ${fcmToken != null}');

      // Save user data
      final userResponse = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firebase_uid': user.uid,
          'email': user.email ?? '',
          'display_name': user.displayName ?? '',
        }),
      );

      print('DEBUG: User save response: ${userResponse.statusCode}');
      if (userResponse.statusCode != 201) {
        print('DEBUG: Failed to save user data');
        return false;
      }

      // If we have FCM token, update it
      if (fcmToken != null) {
        final tokenResponse = await http.post(
          Uri.parse('${Env.apiUrl}/api/users/fcm-token'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'firebase_uid': user.uid,
            'fcm_token': fcmToken,
          }),
        );

        print('DEBUG: Token update response: ${tokenResponse.statusCode}');
        if (tokenResponse.statusCode != 200) {
          print('DEBUG: Failed to save FCM token');
          return false;
        }
      }

      return true;
    } catch (error) {
      print('\n====== ERROR SAVING TO DATABASE ======');
      print('DEBUG: Error type: ${error.runtimeType}');
      print('DEBUG: Error message: $error');
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
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (_isLoading)
                CircularProgressIndicator()
              else if (_user == null)
                Column(
                  children: [
                    ElevatedButton.icon(
                      icon: Image.asset(
                        'assets/google_logo.png', // Make sure to add this asset
                        height: 24.0,
                      ),
                      label: Text('Sign in with Google'),
                      onPressed: () async {
                        User? user = await _handleSignIn();
                        if (user != null && mounted) {
                          setState(() {
                            _user = user;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Signed in: ${user.displayName}')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.all(12),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                      ),
                    ),
                    if (_errorMessage != null)
                      Padding(
                        padding: EdgeInsets.only(top: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                )
              else
                Column(
                  children: [
                    Text(
                      'Welcome, ${_user!.displayName}!',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Email: ${_user!.email}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      child: Text('Sign out'),
                      onPressed: () async {
                        await _handleSignOut();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Signed out')),
                          );
                        }
                      },
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}