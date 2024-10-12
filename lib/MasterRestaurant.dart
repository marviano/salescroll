import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'widgets/burger_menu.dart';
import 'widgets/loading_overlay.dart';
import 'package:salescroll/services/env.dart';
import 'services/alternating_color_listview.dart';
import 'RestaurantPackages.dart';
import 'widgets/network_error_handler.dart';

class MasterRestaurantPage extends StatefulWidget {
  @override
  _MasterRestaurantPageState createState() => _MasterRestaurantPageState();
}

class _MasterRestaurantPageState extends State<MasterRestaurantPage> {
  final GlobalKey<_MasterRestaurantFormState> _formKey = GlobalKey<_MasterRestaurantFormState>();

  @override
  Widget build(BuildContext context) {
    return NetworkErrorHandler(
      child: BurgerMenu(
        topBarTitle: "Master Restaurant",
        activePage: ActivePage.masterRestaurant,
        onRefresh: _refreshPage,
        child: MasterRestaurantForm(key: _formKey),
      ),
    );
  }

  void _refreshPage() {
    _formKey.currentState?.refreshPage();
  }
}

class MasterRestaurantForm extends StatefulWidget {
  MasterRestaurantForm({Key? key}) : super(key: key);
  @override
  _MasterRestaurantFormState createState() => _MasterRestaurantFormState();
}

class _MasterRestaurantFormState extends State<MasterRestaurantForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isEditing = false;
  List<Map<String, dynamic>> _restaurants = [];
  String? _selectedRestaurantId;
  String _selectedStatus = 'active';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchRestaurants();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchRestaurants() async {
    setState(() => _isSearching = true);
    try {
      final response = await http.get(
          Uri.parse('${Env.apiUrl}/api/restaurants?status=$_selectedStatus&search=${_searchController.text}')
      ).timeout(Duration(seconds: 10));
      if (response.statusCode == 200) {
        setState(() {
          _restaurants = List<Map<String, dynamic>>.from(json.decode(response.body));
        });
      } else {
        throw Exception('Failed to load restaurants');
      }
    } catch (e) {
      NetworkErrorNotifier.instance.notifyError();
      // _showErrorDialog('Failed to fetch restaurants: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchRestaurants();
    });
  }

  void refreshPage() {
    _refreshPage();
  }

  Future<void> _toggleRestaurantStatus(String id) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${Env.apiUrl}/api/restaurants/$id/toggle-status'),
      ).timeout(Duration(seconds: 10));
      if (response.statusCode == 200) {
        _fetchRestaurants();
      } else {
        throw Exception('Failed to toggle restaurant status');
      }
    } catch (e) {
      NetworkErrorNotifier.instance.notifyError();
      // _showErrorDialog('Failed to toggle restaurant status: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final response = await http.post(
          Uri.parse('${Env.apiUrl}/api/restaurants'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'restaurantName': _nameController.text}),
        ).timeout(Duration(seconds: 10));
        if (response.statusCode == 201) {
          _showDialog('Success', 'Restaurant added successfully');
          _nameController.clear();
          _fetchRestaurants();
        } else {
          throw Exception('Failed to add restaurant: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        NetworkErrorNotifier.instance.notifyError();
        // _showErrorDialog('Failed to add restaurant: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateRestaurant() async {
    if (_formKey.currentState!.validate() && _selectedRestaurantId != null) {
      setState(() => _isLoading = true);
      try {
        final response = await http.put(
          Uri.parse('${Env.apiUrl}/api/restaurants/$_selectedRestaurantId'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'restaurantName': _nameController.text}),
        ).timeout(Duration(seconds: 10));
        if (response.statusCode == 200) {
          _showDialog('Success', 'Restaurant updated successfully');
          _cancelUpdate();
          _fetchRestaurants();
        } else {
          throw Exception('Failed to update restaurant: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        NetworkErrorNotifier.instance.notifyError();
        // _showErrorDialog('Failed to update restaurant: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _cancelUpdate() {
    setState(() {
      _isEditing = false;
      _selectedRestaurantId = null;
      _nameController.clear();
    });
  }

  void _showErrorDialog(String message) {
    _showDialog('Error', message);
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

  void _refreshPage() {
    setState(() {
      _isLoading = false;
      _isSearching = false;
      _isEditing = false;
      _restaurants = [];
      _selectedRestaurantId = null;
      _selectedStatus = 'active';
      _nameController.clear();
      _searchController.clear();
    });
    _fetchRestaurants();
  }

  Widget _buildRestaurantList() {
    return _isSearching
        ? Center(child: CircularProgressIndicator())
        : AlternatingColorListView(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      children: _restaurants.map((restaurant) => ListTile(
        title: Text(restaurant['restaurant_name']),
        subtitle: Text('Status: ${restaurant['status']}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: restaurant['status'] == 'active',
              onChanged: (value) => _toggleRestaurantStatus(restaurant['id']),
            ),
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                  _selectedRestaurantId = restaurant['id'];
                  _nameController.text = restaurant['restaurant_name'];
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.inventory),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RestaurantPackages(
                      restaurantId: restaurant['id'],
                      restaurantName: restaurant['restaurant_name'],
                    ),
                  ),
                );
              },
              tooltip: 'View Restaurant Packages',
            ),
          ],
        ),
      )).toList(),
    );
  }


  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
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
                    decoration: InputDecoration(labelText: 'Restaurant Name'),
                    controller: _nameController,
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter restaurant name' : null,
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
                        onPressed: _isEditing ? _updateRestaurant : null,
                        child: Text('Update'),
                      ),
                      if (_isEditing)
                        ElevatedButton(
                          onPressed: _cancelUpdate,
                          child: Text('Cancel Update'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white,),
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
                labelText: 'Search Restaurants',
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
                    _fetchRestaurants();
                  },
                ),
                FilterChip(
                  label: Text('Active'),
                  selected: _selectedStatus == 'active',
                  onSelected: (selected) {
                    setState(() => _selectedStatus = 'active');
                    _fetchRestaurants();
                  },
                ),
                FilterChip(
                  label: Text('Inactive'),
                  selected: _selectedStatus == 'inactive',
                  onSelected: (selected) {
                    setState(() => _selectedStatus = 'inactive');
                    _fetchRestaurants();
                  },
                ),
              ],
            ),
            SizedBox(height: 20),
            Text('Restaurants:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            _buildRestaurantList(),
          ],
        ),
      ),
    );
  }
}