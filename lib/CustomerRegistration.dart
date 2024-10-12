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
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // Future<void> _submitForm() async {
  //   if (_formKey.currentState!.validate()) {
  //     setState(() => _isLoading = true);
  //
  //     try {
  //       final response = await _sendRegistrationRequest();
  //       _handleSuccessResponse(response);
  //     } on SocketException catch (_) {
  //       NetworkErrorNotifier.instance.notifyError();
  //       // _showErrorDialog('Koneksi internet terputus. Silakan periksa koneksi Anda dan coba lagi.');
  //     } on TimeoutException catch (_) {
  //       NetworkErrorNotifier.instance.notifyError();
  //       // _showErrorDialog('Waktu permintaan habis. Server mungkin sedang down atau lambat. Silakan coba lagi nanti.');
  //     } catch (e) {
  //       NetworkErrorNotifier.instance.notifyError();
  //       // _showErrorDialog('Gagal menyimpan data pelanggan: $e');
  //     } finally {
  //       setState(() => _isLoading = false);
  //     }
  //   }
  // }
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
          // Parse the error message from the response
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

  // Future<http.Response> _sendRegistrationRequest() async {
  //   const maxRetries = 3;
  //   int retryCount = 0;
  //
  //   while (retryCount < maxRetries) {
  //     try {
  //       return await http.post(
  //         Uri.parse('${Env.apiUrl}/api/customers'),
  //         headers: {'Content-Type': 'application/json; charset=UTF-8'},
  //         body: jsonEncode({
  //           'name': _nameController.text,
  //           'phone_number': _phoneController.text,
  //           'address': _addressController.text,
  //         }),
  //       ).timeout(Duration(seconds: 10));
  //     } catch (e) {
  //       retryCount++;
  //       if (retryCount >= maxRetries) {
  //         rethrow;
  //       }
  //       await Future.delayed(Duration(seconds: 2 * retryCount));
  //     }
  //   }
  //
  //   throw Exception('Max retries reached');
  // }

  Future<http.Response> _sendRegistrationRequest(String firebaseUid) async {
    print('DEBUG: Sending registration request with Firebase UID: $firebaseUid');
    final requestBody = jsonEncode({
      'name': _nameController.text,
      'phone_number': _phoneController.text,
      'address': _addressController.text,
      'firebase_uid': firebaseUid,
    });
    print('DEBUG: Request body: $requestBody');

    final response = await http.post(
      Uri.parse('${Env.apiUrl}/api/customers'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: requestBody,
    ).timeout(Duration(seconds: 10));

    print('DEBUG: Received response with status: ${response.statusCode}');
    print('DEBUG: Response body: ${response.body}');

    return response;
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

  Widget _buildTextFormField(String label, TextEditingController controller, [TextInputType? keyboardType]) {
    return TextFormField(
      decoration: InputDecoration(labelText: label),
      controller: controller,
      keyboardType: label == 'Nomor Telepon' ? TextInputType.number : keyboardType,
      inputFormatters: label == 'Nomor Telepon'
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Mohon masukkan $label';
        }
        if (label == 'Nomor Telepon') {
          if (value.length < 10 || value.length > 15) {
            return 'Nomor telepon harus antara 10 dan 15 digit';
          }
        }
        return null;
      },
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

  void refreshPage() {
    setState(() {
      _isLoading = false;
      _nameController.clear();
      _phoneController.clear();
      _addressController.clear();
    });
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
              SizedBox(height: 20),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }
}