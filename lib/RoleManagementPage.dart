import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'widgets/burger_menu.dart';
import 'widgets/loading_overlay.dart';
import 'services/env.dart';
import 'widgets/network_error_handler.dart';

class RoleManagementPage extends StatefulWidget {
  @override
  _RoleManagementPageState createState() => _RoleManagementPageState();
}

class _RoleManagementPageState extends State<RoleManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isEditing = false;
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _permissions = [];
  Set<int> _selectedPermissions = {};
  int? _selectedRoleId;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _scrollController.dispose();
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
        setState(() {
          _roles = [];
          _permissions = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final rolesResponse = await http.get(
        Uri.parse('${Env.apiUrl}/api/roles'),
      ).timeout(Duration(seconds: 10));

      final permissionsResponse = await http.get(
        Uri.parse('${Env.apiUrl}/api/permissions'),
      ).timeout(Duration(seconds: 10));

      if (rolesResponse.statusCode == 200 && permissionsResponse.statusCode == 200) {
        setState(() {
          _roles = List<Map<String, dynamic>>.from(json.decode(rolesResponse.body));
          _permissions = List<Map<String, dynamic>>.from(json.decode(permissionsResponse.body));
        });
        NetworkErrorNotifier.instance.clearError();
      } else {
        setState(() {
          _roles = [];
          _permissions = [];
        });
        throw Exception('Failed to fetch data');
      }
    } catch (e) {
      setState(() {
        _roles = [];
        _permissions = [];
      });
      NetworkErrorNotifier.instance.notifyError();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveRole() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final url = _isEditing
          ? '${Env.apiUrl}/api/roles/$_selectedRoleId'
          : '${Env.apiUrl}/api/roles';

      final payload = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'permissions': _selectedPermissions.toList(),
      };

      final response = await (_isEditing
          ? http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      )
          : http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      )).timeout(Duration(seconds: 10));

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Role updated successfully' : 'Role created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _clearForm();
        _fetchData();
      } else {
        throw Exception('Failed to save role');
      }
    } catch (e) {
      NetworkErrorNotifier.instance.notifyError();
      setState(() {
        _roles = [];
        _permissions = [];
      });
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

  void _editRole(Map<String, dynamic> role) {
    setState(() {
      _isEditing = true;
      _selectedRoleId = role['id'];
      _nameController.text = role['name'];
      _descriptionController.text = role['description'] ?? '';
      _selectedPermissions = Set.from(
          (role['permissions'] as List).map((p) => p['id'] as int)
      );
    });

    _scrollController.animateTo(
      0,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _clearForm() {
    setState(() {
      _isEditing = false;
      _selectedRoleId = null;
      _nameController.clear();
      _descriptionController.clear();
      _selectedPermissions.clear();
    });
  }

  Widget _buildRoleForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Role Name',
              border: OutlineInputBorder(),
            ),
            validator: (value) =>
            value?.isEmpty ?? true ? 'Please enter a role name' : null,
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          SizedBox(height: 16),
          Text('Permissions:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _permissions.map((permission) {
              return FilterChip(
                label: Text(permission['name']),
                selected: _selectedPermissions.contains(permission['id']),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedPermissions.add(permission['id']);
                    } else {
                      _selectedPermissions.remove(permission['id']);
                    }
                  });
                },
              );
            }).toList(),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _saveRole,
                child: Text(_isEditing ? 'Update Role' : 'Create Role'),
              ),
              if (_isEditing)
                ElevatedButton(
                  onPressed: _clearForm,
                  child: Text('Cancel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleList() {
    if (_roles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.refresh, size: 50, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Please refresh the page to load roles',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _refreshPage,
                child: Text('Refresh Now'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Existing Roles:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: _roles.length,
          itemBuilder: (context, index) {
            final role = _roles[index];
            return Card(
              child: ListTile(
                title: Text(role['name']),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (role['description'] != null)
                      Text(role['description']),
                    SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: (role['permissions'] as List)
                          .map((p) => Chip(
                        label: Text(
                          p['name'],
                          style: TextStyle(fontSize: 12),
                        ),
                      ))
                          .toList(),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () => _editRole(role),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return NetworkErrorHandler(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Role Management'),
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
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRoleForm(),
                SizedBox(height: 32),
                _buildRoleList(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}