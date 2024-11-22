import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'widgets/burger_menu.dart';
import 'widgets/loading_overlay.dart';
import 'package:salescroll/services/env.dart';
import 'services/alternating_color_listview.dart';
import 'widgets/network_error_handler.dart';
import 'package:intl/intl.dart';

class MasterUserPage extends StatefulWidget {
  @override
  _MasterUserPageState createState() => _MasterUserPageState();
}

class _MasterUserPageState extends State<MasterUserPage> {
  final GlobalKey<_MasterUserFormState> _formKey = GlobalKey<_MasterUserFormState>();

  @override
  Widget build(BuildContext context) {
    return NetworkErrorHandler(
      child: BurgerMenu(
        topBarTitle: "Master User",
        activePage: ActivePage.masterUser,
        onRefresh: _refreshPage,
        child: MasterUserForm(key: _formKey),
      ),
    );
  }

  void _refreshPage() {
    _formKey.currentState?.refreshPage();
  }
}

class MasterUserForm extends StatefulWidget {
  MasterUserForm({Key? key}) : super(key: key);

  @override
  _MasterUserFormState createState() => _MasterUserFormState();
}

class _MasterUserFormState extends State<MasterUserForm> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isEditing = false;
  List<Map<String, dynamic>> _users = [];
  String? _selectedUserId;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _fetchUsers() async {
    print('Debug: Starting _fetchUsers()');
    print('Debug: Search text: ${_searchController.text}');
    print('Debug: API URL: ${Env.apiUrl}/api/master/users?search=${_searchController.text}'); // Updated URL

    setState(() => _isSearching = true);
    try {
      final response = await http.get(
          Uri.parse('${Env.apiUrl}/api/master/users?search=${_searchController.text}') // Updated URL
      ).timeout(Duration(seconds: 10));

      print('Debug: Response status code: ${response.statusCode}');
      print('Debug: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        print('Debug: Decoded data: $decodedData');

        setState(() {
          _users = List<Map<String, dynamic>>.from(decodedData);
        });
        print('Debug: Users list length: ${_users.length}');
      } else {
        print('Debug: Failed with status code: ${response.statusCode}');
        throw Exception('Failed to load users');
      }
    } catch (e) {
      print('Debug: Error in _fetchUsers: $e');
      NetworkErrorNotifier.instance.notifyError();
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _updateUser() async {
    if (_formKey.currentState!.validate() && _selectedUserId != null) {
      setState(() => _isLoading = true);
      try {
        final url = '${Env.apiUrl}/api/master/users/$_selectedUserId'; // Updated URL
        print('Debug: Making PUT request to: $url');
        print('Debug: Request body: ${jsonEncode({
          'display_name': _displayNameController.text,
        })}');

        final response = await http.put(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'display_name': _displayNameController.text,
          }),
        ).timeout(Duration(seconds: 10));

        print('Debug: Response status code: ${response.statusCode}');
        print('Debug: Response body: ${response.body}');

        if (response.statusCode == 200) {
          _showDialog('Success', 'User updated successfully');
          _cancelUpdate();
          _fetchUsers();
        } else {
          throw Exception('Failed to update user: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('Debug: Update error: $e');
        NetworkErrorNotifier.instance.notifyError();
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearForm() {
    _displayNameController.clear();
  }

  Widget _buildExpandableInfo(String title, String content) {
    return ExpansionTile(
      title: Text(title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey[700],
        ),
      ),
      children: [
        Padding(
          padding: EdgeInsets.all(16.0),
          child: SelectableText(
            content,
            style: TextStyle(
              fontFamily: 'Monospace',
              fontSize: 13,
              color: Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserList() {
    if (_isSearching) {
      return Center(child: CircularProgressIndicator());
    }

    return AlternatingColorListView(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      children: _users.map((user) {
        final createdAt = DateFormat('MMM d, y HH:mm:ss')
            .format(DateTime.parse(user['created_at']));
        final lastLogin = DateFormat('MMM d, y HH:mm:ss')
            .format(DateTime.parse(user['last_login']));

        return Card(
          elevation: 2,
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: Text(
                  user['display_name'] ?? 'No Display Name',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(user['email'] ?? 'No Email'),
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                      _selectedUserId = user['id'].toString();
                      _displayNameController.text = user['display_name'] ?? '';
                    });
                    _scrollController.animateTo(
                      0,
                      duration: Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Role: ${user['role_name'] ?? 'No Role'}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.blue[900],
                    ),
                  ),
                ),
              ),
              _buildExpandableInfo('User ID & Firebase Details',
                'ID: ${user['id']}\nFirebase UID: ${user['firebase_uid']}'),
              _buildExpandableInfo('Timestamps',
                'Created: $createdAt\nLast Login: $lastLogin'),
              SizedBox(height: 8),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      loadingText: 'Please wait...',
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isEditing) ...[
              Card(
                elevation: 3,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _displayNameController,
                          decoration: InputDecoration(
                            labelText: 'Display Name',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          validator: (value) =>
                            value?.isEmpty ?? true ? 'Please enter display name' : null,
                        ),
                        SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              icon: Icon(Icons.save),
                              label: Text('Update'),
                              onPressed: _updateUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            ),
                            ElevatedButton.icon(
                              icon: Icon(Icons.cancel),
                              label: Text('Cancel'),
                              onPressed: _cancelUpdate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],
            Container(
              margin: EdgeInsets.symmetric(vertical: 8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search Users',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[50],
                  prefixIcon: Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _fetchUsers();
                        },
                      )
                    : null,
                ),
                onChanged: (value) {
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 500), _fetchUsers);
                },
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Users List',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
            SizedBox(height: 12),
            _buildUserList(),
          ],
        ),
      ),
    );
  }

  void _cancelUpdate() {
    setState(() {
      _isEditing = false;
      _selectedUserId = null;
      _clearForm();
    });
  }

  void refreshPage() {
    setState(() {
      _isLoading = false;
      _isSearching = false;
      _isEditing = false;
      _users = [];
      _selectedUserId = null;
      _clearForm();
      _searchController.clear();
    });
    _fetchUsers();
  }
}