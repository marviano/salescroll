import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'widgets/burger_menu.dart';
import 'widgets/loading_overlay.dart';
import 'services/env.dart';
import 'widgets/network_error_handler.dart';

class UserRoleAssignmentPage extends StatefulWidget {
  @override
  _UserRoleAssignmentPageState createState() => _UserRoleAssignmentPageState();
}

class _UserRoleAssignmentPageState extends State<UserRoleAssignmentPage> {
  bool _isLoading = false;
  bool _isRefreshing = false;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _roles = [];
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshPage() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    try {
      await _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Page refreshed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        NetworkErrorNotifier.instance.notifyError();
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _onSearchChanged() {
    setState(() {});
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final usersResponse = await http.get(
        Uri.parse('${Env.apiUrl}/api/users/roles'),
      ).timeout(Duration(seconds: 10));

      final rolesResponse = await http.get(
        Uri.parse('${Env.apiUrl}/api/roles'),
      ).timeout(Duration(seconds: 10));

      if (usersResponse.statusCode == 200 && rolesResponse.statusCode == 200) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(json.decode(usersResponse.body));
          _roles = List<Map<String, dynamic>>.from(json.decode(rolesResponse.body));
        });
        NetworkErrorNotifier.instance.clearError();
      } else {
        setState(() {
          _users = [];
          _roles = [];
        });
        throw Exception('Failed to fetch data');
      }
    } catch (e) {
      setState(() {
        _users = [];
        _roles = [];
      });
      NetworkErrorNotifier.instance.notifyError();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUserRole(int userId, int? newRoleId) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.put(
        Uri.parse('${Env.apiUrl}/api/users/$userId/role'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'role_id': newRoleId}),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User role updated successfully'), backgroundColor: Colors.green),
        );
        _fetchData();
      } else {
        setState(() {
          _users = [];
          _roles = [];
        });
        throw Exception('Failed to update user role');
      }
    } catch (e) {
      setState(() {
        _users = [];
        _roles = [];
      });
      NetworkErrorNotifier.instance.notifyError();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection lost. Please refresh the page.'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Refresh',
            textColor: Colors.white,
            onPressed: _refreshPage,
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildUserList() {
    final searchTerm = _searchController.text.toLowerCase();
    final filteredUsers = _users.where((user) {
      final searchString = [
        user['email'] ?? '',
        user['display_name'] ?? '',
        user['role_name'] ?? 'No Role',
      ].join(' ').toLowerCase();
      return searchString.contains(searchTerm);
    }).toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        final user = filteredUsers[index];
        return Card(
          margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      child: Text(
                        (user['display_name'] ?? user['email'])[0].toUpperCase(),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['display_name'] ?? 'No Name',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            user['email'] ?? 'No Email',
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Divider(height: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Role:',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      child: DropdownButtonFormField<int?>(
                        value: user['role_id'],
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text('No Role'),
                          ),
                          ..._roles.map((role) => DropdownMenuItem<int?>(
                            value: role['id'],
                            child: Text(role['name']),
                          )).toList(),
                        ],
                        onChanged: (newRoleId) {
                          if (newRoleId != user['role_id']) {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text('Confirm Role Change'),
                                  content: Text(
                                      'Are you sure you want to change the role of ${user['display_name'] ?? user['email']} ' +
                                          'to ${newRoleId == null ? "No Role" : _roles.firstWhere((r) => r['id'] == newRoleId)['name']}?'
                                  ),
                                  actions: [
                                    TextButton(
                                      child: Text('Cancel'),
                                      onPressed: () => Navigator.of(context).pop(),
                                    ),
                                    TextButton(
                                      child: Text('Confirm'),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        _updateUserRole(user['id'], newRoleId);
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return NetworkErrorHandler(
      child: Scaffold(
        appBar: AppBar(
          title: Text('User Role Assignment'),
          actions: [
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
                  : const Icon(Icons.refresh),
              onPressed: _isRefreshing ? null : _refreshPage,
              tooltip: 'Refresh page',
            ),
          ],
        ),
        body: LoadingOverlay(
          isLoading: _isLoading,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search Users',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () => _searchController.clear(),
                    )
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchData,
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        if (_users.isNotEmpty) ...[
                          Text(
                            'Total Users: ${_users.length}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          SizedBox(height: 16),
                          _buildUserList(),
                        ] else if (!_isLoading) ...[
                          Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.refresh, size: 50, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'Please refresh the page to load data',
                                  style: TextStyle(color: Colors.grey[600]),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _refreshPage,
                                  child: Text('Refresh Now'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
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