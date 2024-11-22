import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'env.dart';

class UserPermission {
  final String resource;
  final String action;

  UserPermission({required this.resource, required this.action});

  factory UserPermission.fromJson(Map<String, dynamic> json) {
    return UserPermission(
      resource: json['resource'],
      action: json['action'],
    );
  }
}

class UserPermissionsService {
  static final UserPermissionsService _instance = UserPermissionsService._internal();
  factory UserPermissionsService() => _instance;
  UserPermissionsService._internal();

  List<UserPermission>? _cachedPermissions;

  Future<List<UserPermission>> getUserPermissions() async {
    if (_cachedPermissions != null) {
      return _cachedPermissions!;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await http.get(
        Uri.parse('${Env.apiUrl}/api/users/permissions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await user.getIdToken()}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> permissionsJson = json.decode(response.body);
        _cachedPermissions = permissionsJson
            .map((json) => UserPermission.fromJson(json))
            .toList();
        return _cachedPermissions!;
      } else {
        throw Exception('Failed to load permissions');
      }
    } catch (e) {
      print('Error fetching permissions: $e');
      throw Exception('Failed to load permissions');
    }
  }

  void clearCache() {
    _cachedPermissions = null;
  }

  bool hasPermission(List<UserPermission> permissions, String resource, String action) {
    return permissions.any((p) => p.resource == resource && p.action == action);
  }
}