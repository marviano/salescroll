import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'widgets/burger_menu.dart';
import 'widgets/loading_overlay.dart';
import 'package:salescroll/services/env.dart';
import 'package:flutter/services.dart';
import 'widgets/network_error_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomerRegistrationPage extends StatefulWidget {
  @override
  _CustomerRegistrationPageState createState() => _CustomerRegistrationPageState();
}

class _CustomerRegistrationPageState extends State<CustomerRegistrationPage> {
  final GlobalKey<_CustomerRegistrationFormState> _formKey = GlobalKey<_CustomerRegistrationFormState>();

  @override
  Widget build(BuildContext context) {
    return NetworkErrorHandler(
      child: BurgerMenu(
        topBarTitle: "Pendaftaran Pelanggan",
        activePage: ActivePage.customerRegistration,
        onRefresh: _refreshPage,
        child: CustomerRegistrationForm(key: _formKey),
      ),
    );
  }

  void _refreshPage() {
    _formKey.currentState?.refreshPage();
  }
}

class CustomerRegistrationForm extends StatefulWidget {
  CustomerRegistrationForm({Key? key}) : super(key: key);

  @override
  _CustomerRegistrationFormState createState() => _CustomerRegistrationFormState();
}

class _CustomerRegistrationFormState extends State<CustomerRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _companyController = TextEditingController();
  String? _selectedLeadSource;
  bool _isLoading = false;

  final List<String> _leadSources = [
    'Event Marketing',
    'Canvas',
    'Digital Marketing',
    'Referral',
    'PoS'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Future<http.Response> _sendRegistrationRequest(String firebaseUid) async {
    final requestBody = jsonEncode({
      'name': _nameController.text,
      'phone_number': _phoneController.text,
      'address': _addressController.text,
      'firebase_uid': firebaseUid,
      'company': _companyController.text,
      'lead_source': _selectedLeadSource,
    });

    return await http.post(
      Uri.parse('${Env.apiUrl}/api/customers'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: requestBody,
    ).timeout(Duration(seconds: 10));
  }

  Widget _buildTextFormField(String label, TextEditingController controller, [TextInputType? keyboardType]) {
    final bool isOptional = label == 'Perusahaan';
    final displayLabel = isOptional ? '$label (Opsional)' : label;

    return Padding(
      padding: EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: displayLabel,
          border: OutlineInputBorder(),
        ),
        controller: controller,
        keyboardType: label == 'Nomor Telepon' ? TextInputType.number : keyboardType,
        inputFormatters: label == 'Nomor Telepon'
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            if (isOptional) {
              return null; // Company is optional
            }
            return 'Mohon masukkan $label';
          }
          if (label == 'Nomor Telepon') {
            if (value.length < 10 || value.length > 15) {
              return 'Nomor telepon harus antara 10 dan 15 digit';
            }
          }
          return null;
        },
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.5,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submitForm,
          child: Text('Kirim'),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 16.0),
          ),
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('No user logged in');
        }

        final response = await _sendRegistrationRequest(user.uid);
        if (response.statusCode == 201) {
          _handleSuccessResponse(response);
        } else {
          final errorBody = json.decode(response.body);
          throw Exception('Server error: ${errorBody['error'] ?? 'Unknown error'}');
        }
      } catch (e) {
        print('Error in _submitForm: $e');
        _showErrorDialog('Failed to save customer data: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void refreshPage() {
    setState(() {
      _isLoading = false;
      _nameController.clear();
      _phoneController.clear();
      _addressController.clear();
      _companyController.clear();
      _selectedLeadSource = null;
      _formKey.currentState?.reset();
    });
  }

  void _handleSuccessResponse(http.Response response) {
    final responseBody = json.decode(response.body);
    _showDialog('Formulir Terkirim', 'Data pelanggan berhasil disimpan. ID: ${responseBody['id']}');
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
                  onPressed: () => Navigator.pop(context)
              )
            ]
        )
    );
  }

  Widget _buildLeadSourceDropdown() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: 'Lead Source (Opsional)',
          border: OutlineInputBorder(),
        ),
        value: _selectedLeadSource,
        items: _leadSources.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _selectedLeadSource = newValue;
          });
        },
        isExpanded: true,
        hint: Text('Pilih lead source'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      loadingText: 'Menyimpan data...',
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextFormField('Nama Pelanggan', _nameController),
              _buildTextFormField('Nomor Telepon', _phoneController, TextInputType.number),
              _buildTextFormField('Alamat', _addressController),
              _buildTextFormField('Perusahaan', _companyController),
              SizedBox(height: 16),
              _buildLeadSourceDropdown(),
              SizedBox(height: 20),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }
}