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
  final _companyController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String? _selectedLeadSource;
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isEditing = false;
  List<Map<String, dynamic>> _customers = [];
  String? _selectedCustomerId;
  Timer? _debounce;

  final List<String> _leadSources = ['Event Marketing', 'Canvas', 'Digital Marketing', 'Referral', 'PoS'];

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
    _companyController.dispose();
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
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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
            'company': _companyController.text,
            'lead_source': _selectedLeadSource,
            'firebase_uid': 'your_firebase_uid_here',
          }),
        ).timeout(Duration(seconds: 10));
        if (response.statusCode == 201) {
          _showDialog('Success', 'Customer added successfully');
          _clearForm();
          _fetchCustomers();
        } else {
          throw Exception('Failed to add customer');
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
            'company': _companyController.text,
            'lead_source': _selectedLeadSource,
          }),
        ).timeout(Duration(seconds: 10));
        if (response.statusCode == 200) {
          _showDialog('Success', 'Customer updated successfully');
          _cancelUpdate();
          _fetchCustomers();
        } else {
          throw Exception('Failed to update customer');
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
    _phoneNumberController.clear();
    _addressController.clear();
    _companyController.clear();
    setState(() => _selectedLeadSource = null);
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    int? maxLines,
    TextInputType? keyboardType,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: maxLines != null ? 12 : 8),
        ),
        controller: controller,
        validator: validator,
        maxLines: maxLines,
        keyboardType: keyboardType,
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(customer['phone_number']),
            Text(customer['address']),
            if (customer['company'] != null) Text('Company: ${customer['company']}'),
            if (customer['lead_source'] != null) Text('Lead Source: ${customer['lead_source']}'),
          ],
        ),
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
              _companyController.text = customer['company'] ?? '';
              _selectedLeadSource = customer['lead_source'];
            });
            _scrollController.animateTo(
              0,
              duration: Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          },
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
        controller: _scrollController,
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildFormField(
                    label: 'Customer Name',
                    controller: _nameController,
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter customer name' : null,
                  ),
                  _buildFormField(
                    label: 'Phone Number',
                    controller: _phoneNumberController,
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter phone number' : null,
                    keyboardType: TextInputType.phone,
                  ),
                  _buildFormField(
                    label: 'Address',
                    controller: _addressController,
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter address' : null,
                    maxLines: 3,
                  ),
                  _buildFormField(
                    label: 'Company',
                    controller: _companyController,
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 8.0),
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Lead Source',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      value: _selectedLeadSource,
                      items: _leadSources.map((source) => DropdownMenuItem(
                        value: source,
                        child: Text(source),
                      )).toList(),
                      onChanged: (value) => setState(() => _selectedLeadSource = value),
                    ),
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Container(
              margin: EdgeInsets.symmetric(vertical: 8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search Customers',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  suffixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 500), _fetchCustomers);
                },
              ),
            ),
            SizedBox(height: 20),
            Text('Customers:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            _buildCustomerList(),
          ],
        ),
      ),
    );
  }

  void _cancelUpdate() {
    setState(() {
      _isEditing = false;
      _selectedCustomerId = null;
      _clearForm();
    });
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
}