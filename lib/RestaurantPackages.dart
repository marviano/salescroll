import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:salescroll/services/env.dart';
import 'services/alternating_color_listview.dart';
import 'widgets/loading_overlay.dart';
import 'widgets/burger_menu.dart';
import 'widgets/network_error_handler.dart';

class RestaurantPackages extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const RestaurantPackages({
    Key? key,
    required this.restaurantId,
    required this.restaurantName,
  }) : super(key: key);

  @override
  _RestaurantPackagesState createState() => _RestaurantPackagesState();
}

class _RestaurantPackagesState extends State<RestaurantPackages> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _searchController = TextEditingController();
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isEditing = false;
  List<Map<String, dynamic>> _packages = [];
  String? _selectedPackageId;
  String _selectedStatus = 'active';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchPackages();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchPackages() async {
    setState(() => _isSearching = true);
    try {
      final response = await http.get(
          Uri.parse('${Env.apiUrl}/api/packages?restaurant_id=${widget.restaurantId}&status=$_selectedStatus&search=${_searchController.text}')
      ).timeout(Duration(seconds: 10));
      if (response.statusCode == 200) {
        setState(() {
          _packages = List<Map<String, dynamic>>.from(json.decode(response.body));
        });
      } else {
        throw Exception('Failed to load packages: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching packages: $e');
      NetworkErrorNotifier.instance.notifyError();
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchPackages();
    });
  }

  Future<void> _togglePackageStatus(String id) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${Env.apiUrl}/api/packages/$id/toggle-status'),
      ).timeout(Duration(seconds: 10));
      if (response.statusCode == 200) {
        _fetchPackages();
      } else {
        throw Exception('Failed to toggle package status');
      }
    } catch (e) {
      NetworkErrorNotifier.instance.notifyError();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      print('DEBUG: Sending package data:');
      print('id_restaurant: ${widget.restaurantId}');
      print('package_name: ${_nameController.text}');
      print('description: ${_descriptionController.text}');
      print('price: ${_priceController.text}');
      try {
        final response = await http.post(
          Uri.parse('${Env.apiUrl}/api/packages'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'id_restaurant': widget.restaurantId,
            'package_name': _nameController.text,
            'description': _descriptionController.text,
            'price': double.parse(_priceController.text),
          }),
        ).timeout(Duration(seconds: 10));
        if (response.statusCode == 201) {
          _showDialog('Success', 'Package added successfully');
          _clearForm();
          _fetchPackages();
        } else {
          throw Exception('Failed to add package: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        NetworkErrorNotifier.instance.notifyError();
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updatePackage() async {
    if (_formKey.currentState!.validate() && _selectedPackageId != null) {
      setState(() => _isLoading = true);
      try {
        final response = await http.put(
          Uri.parse('${Env.apiUrl}/api/packages/$_selectedPackageId'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'package_name': _nameController.text,
            'description': _descriptionController.text,
            'price': double.parse(_priceController.text),
          }),
        ).timeout(Duration(seconds: 10));
        if (response.statusCode == 200) {
          _showDialog('Success', 'Package updated successfully');
          _cancelUpdate();
          _fetchPackages();
        } else {
          throw Exception('Failed to update package: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        NetworkErrorNotifier.instance.notifyError();
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearForm() {
    _nameController.clear();
    _descriptionController.clear();
    _priceController.clear();
  }

  void _cancelUpdate() {
    setState(() {
      _isEditing = false;
      _selectedPackageId = null;
      _clearForm();
    });
  }

  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            child: Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageList() {
    return _isSearching
        ? Center(child: CircularProgressIndicator())
        : AlternatingColorListView(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      children: _packages.map((package) => ListTile(
        title: Text(package['package_name']),
        subtitle: Text('Price: ${package['price']} - Status: ${package['status']}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: package['status'] == 'active',
              onChanged: (value) => _togglePackageStatus(package['id']),
            ),
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                  _selectedPackageId = package['id'];
                  _nameController.text = package['package_name'];
                  _descriptionController.text = package['description'] ?? '';
                  _priceController.text = package['price'].toString();
                });
              },
            ),
          ],
        ),
      )).toList(),
    );
  }

  void refreshPage() {
    setState(() {
      _isLoading = false;
      _isSearching = false;
      _isEditing = false;
      _packages = [];
      _selectedPackageId = null;
      _selectedStatus = 'active';
      _clearForm();
      _searchController.clear();
    });
    _fetchPackages();
  }

  @override
  Widget build(BuildContext context) {
    return NetworkErrorHandler(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Packages for ${widget.restaurantName}'),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: refreshPage,
            ),
          ],
        ),
        body: LoadingOverlay(
          isLoading: _isLoading,
          loadingText: 'Please wait...',
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        decoration: InputDecoration(labelText: 'Package Name'),
                        controller: _nameController,
                        validator: (value) => value?.isEmpty ?? true ? 'Please enter package name' : null,
                      ),
                      TextFormField(
                        decoration: InputDecoration(labelText: 'Description'),
                        controller: _descriptionController,
                        maxLines: 3,
                      ),
                      TextFormField(
                        decoration: InputDecoration(labelText: 'Price'),
                        controller: _priceController,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a price';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: _isEditing ? null : _submitForm,
                            child: Text('Add'),
                          ),
                          ElevatedButton(
                            onPressed: _isEditing ? _updatePackage : null,
                            child: Text('Update'),
                          ),
                          if (_isEditing)
                            ElevatedButton(
                              onPressed: _cancelUpdate,
                              child: Text('Cancel Update'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Divider(thickness: 1, color: Colors.grey[300]),
                SizedBox(height: 20),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search Packages',
                    suffixIcon: Icon(Icons.search),
                  ),
                  onChanged: _onSearchChanged,
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FilterChip(
                      label: Text('All'),
                      selected: _selectedStatus == 'all',
                      onSelected: (selected) {
                        setState(() => _selectedStatus = 'all');
                        _fetchPackages();
                      },
                    ),
                    FilterChip(
                      label: Text('Active'),
                      selected: _selectedStatus == 'active',
                      onSelected: (selected) {
                        setState(() => _selectedStatus = 'active');
                        _fetchPackages();
                      },
                    ),
                    FilterChip(
                      label: Text('Inactive'),
                      selected: _selectedStatus == 'inactive',
                      onSelected: (selected) {
                        setState(() => _selectedStatus = 'inactive');
                        _fetchPackages();
                      },
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Text('Packages:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                _buildPackageList(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}