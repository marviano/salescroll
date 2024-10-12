import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';  // Add this import for TimeoutException
import 'widgets/burger_menu.dart';
import 'widgets/loading_overlay.dart';

class CustomerRegistrationPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BurgerMenu(
      topBarTitle: "Pendaftaran Pelanggan",
      activePage: ActivePage.customerRegistration,
      child: CustomerRegistrationForm(),
    );
  }
}

class CustomerRegistrationForm extends StatefulWidget {
  @override
  _CustomerRegistrationFormState createState() => _CustomerRegistrationFormState();
}

class _CustomerRegistrationFormState extends State<CustomerRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final response = await _sendRegistrationRequest();
        _handleSuccessResponse(response);
      } on SocketException catch (_) {
        _showErrorDialog('Koneksi internet terputus. Silakan periksa koneksi Anda dan coba lagi.');
      } on TimeoutException catch (_) {
        _showErrorDialog('Waktu permintaan habis. Server mungkin sedang down atau lambat. Silakan coba lagi nanti.');
      } catch (e) {
        _showErrorDialog('Gagal menyimpan data pelanggan: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<http.Response> _sendRegistrationRequest() {
    return http.post(
      Uri.parse('http://192.168.1.10:3000/api/customers'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'name': _nameController.text,
        'phoneNumber': _phoneController.text,
        'address': _addressController.text,
      }),
    ).timeout(Duration(seconds: 10));
  }

  void _handleSuccessResponse(http.Response response) {
    if (response.statusCode == 201) {
      _showDialog('Formulir Terkirim', 'Data pelanggan berhasil disimpan. Response: ${response.body}');
    } else {
      throw Exception('Failed to save customer data. Status: ${response.statusCode}, Body: ${response.body}');
    }
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
              _buildTextFormField('Nomor Telepon', _phoneController, TextInputType.phone),
              _buildTextFormField('Alamat', _addressController),
              SizedBox(height: 20),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField(String label, TextEditingController controller, [TextInputType? keyboardType]) {
    return TextFormField(
      decoration: InputDecoration(labelText: label),
      controller: controller,
      keyboardType: keyboardType,
      validator: (value) => value?.isEmpty ?? true ? 'Mohon masukkan $label' : null,
    );
  }

  Widget _buildSubmitButton() {
    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.5,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submitForm,
          child: Text('Kirim'),
        ),
      ),
    );
  }
}