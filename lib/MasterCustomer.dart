import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'widgets/burger_menu.dart';
import 'widgets/loading_overlay.dart';
import 'package:salescroll/services/env.dart';
import 'services/alternating_color_listview.dart';
import 'widgets/network_error_handler.dart';

class MasterCustomerPage extends StatefulWidget {
  @override
  _MasterCustomerPageState createState() => _MasterCustomerPageState();
}

class _MasterCustomerPageState extends State<MasterCustomerPage> {
  final GlobalKey<_MasterCustomerFormState> _formKey = GlobalKey<_MasterCustomerFormState>();

  @override
  Widget build(BuildContext context) {
    return NetworkErrorHandler(
      child: BurgerMenu(
        topBarTitle: "Master Customer",
        activePage: ActivePage.masterCustomer,
        onRefresh: _refreshPage,
        child: MasterCustomerForm(key: _formKey),
      ),
    );
  }

  void _refreshPage() {
    _formKey.currentState?.refreshPage();
  }
}

class MasterCustomerForm extends StatefulWidget {
  MasterCustomerForm({Key? key}) : super(key: key);

  @override
  _MasterCustomerFormState createState() => _MasterCustomerFormState();
}

class _MasterCustomerFormState extends State<MasterCustomerForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _searchController = TextEditingController();
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isEditing = false;
  List<Map<String, dynamic>> _customers = [];
  String? _selectedCustomerId;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneNumberController.dispose();
    _addressController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchCustomers() async {
    setState(() => _isSearching = true);
    try {
      final response = await http.get(
          Uri.parse('${Env.apiUrl}/api/customers?search=${_searchController.text}')
      ).timeout(Duration(seconds: 10));
      if (response.statusCode == 200) {
        setState(() {
          _customers = List<Map<String, dynamic>>.from(json.decode(response.body));
        });
      } else {
        throw Exception('Failed to load customers');
      }
    } catch (e) {
      NetworkErrorNotifier.instance.notifyError();
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchCustomers();
    });
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final response = await http.post(
          Uri.parse('${Env.apiUrl}/api/customers'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'name': _nameController.text,
            'phone_number': _phoneNumberController.text,
            'address': _addressController.text,
          }),
        ).timeout(Duration(seconds: 10));
        if (response.statusCode == 201) {
          _showDialog('Success', 'Customer added successfully');
          _clearForm();
          _fetchCustomers();
        } else {
          throw Exception('Failed to add customer: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        NetworkErrorNotifier.instance.notifyError();
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateCustomer() async {
    if (_formKey.currentState!.validate() && _selectedCustomerId != null) {
      setState(() => _isLoading = true);
      try {
        final response = await http.put(
          Uri.parse('${Env.apiUrl}/api/customers/$_selectedCustomerId'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'name': _nameController.text,
            'phone_number': _phoneNumberController.text,
            'address': _addressController.text,
          }),
        ).timeout(Duration(seconds: 10));
        if (response.statusCode == 200) {
          _showDialog('Success', 'Customer updated successfully');
          _cancelUpdate();
          _fetchCustomers();
        } else {
          throw Exception('Failed to update customer: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        NetworkErrorNotifier.instance.notifyError();
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _cancelUpdate() {
    setState(() {
      _isEditing = false;
      _selectedCustomerId = null;
      _clearForm();
    });
  }

  void _clearForm() {
    _nameController.clear();
    _phoneNumberController.clear();
    _addressController.clear();
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

  Widget _buildCustomerList() {
    return _isSearching
        ? Center(child: CircularProgressIndicator())
        : AlternatingColorListView(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      children: _customers.map((customer) => ListTile(
        title: Text(customer['name']),
        subtitle: Text('${customer['phone_number']}\n${customer['address']}'),
        isThreeLine: true,
        trailing: IconButton(
          icon: Icon(Icons.edit),
          onPressed: () {
            setState(() {
              _isEditing = true;
              _selectedCustomerId = customer['id'];
              _nameController.text = customer['name'];
              _phoneNumberController.text = customer['phone_number'];
              _addressController.text = customer['address'];
            });
          },
        ),
      )).toList(),
    );
  }

  void refreshPage() {
    setState(() {
      _isLoading = false;
      _isSearching = false;
      _isEditing = false;
      _customers = [];
      _selectedCustomerId = null;
      _clearForm();
      _searchController.clear();
    });
    _fetchCustomers();
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
                    decoration: InputDecoration(labelText: 'Customer Name'),
                    controller: _nameController,
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter customer name' : null,
                  ),
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Phone Number'),
                    controller: _phoneNumberController,
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter phone number' : null,
                  ),
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Address'),
                    controller: _addressController,
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter address' : null,
                    maxLines: 3,
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
                        onPressed: _isEditing ? _updateCustomer : null,
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
                labelText: 'Search Customers',
                suffixIcon: Icon(Icons.search),
              ),
              onChanged: _onSearchChanged,
            ),
            SizedBox(height: 20),
            Text('Customers:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            _buildCustomerList(),
          ],
        ),
      ),
    );
  }
}