import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'burger_menu.dart';
import 'package:salescroll/env.dart';
import 'dart:async';

class SalesCustomerEnrollmentPage extends StatefulWidget {
  @override
  _SalesCustomerEnrollmentPageState createState() => _SalesCustomerEnrollmentPageState();
}

class _SalesCustomerEnrollmentPageState extends State<SalesCustomerEnrollmentPage> {
  final _formKey = GlobalKey<FormState>();
  // final _packageController = TextEditingController();
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  // String _name = '', _address = '', _phoneNumber = '';
  String? _selectedRestaurant;
  Package? _selectedPackage;
  List<SelectedPackage> _selectedPackages = [];
  DateTime? _deliveryDateTime;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounce;
  bool _isTyping = false;
  bool _isFieldFocused = false;

  final List<String> _restaurants = ['Lombok Idjoe', 'IClub', '2 Fat Guys', 'Ueno'];
  final Map<String, List<Package>> _restaurantPackages = {
    'Lombok Idjoe': [
      Package(id: 'L1', name: 'Lombok Dasar', price: 100, description: 'Fitur dasar untuk Lombok'),
      Package(id: 'L2', name: 'Lombok Premium', price: 200, description: 'Fitur premium untuk Lombok')
    ],
    'IClub': [
      Package(id: 'I1', name: 'IClub Standar', price: 150, description: 'Fitur standar untuk IClub'),
      Package(id: 'I2', name: 'IClub VIP', price: 250, description: 'Fitur VIP untuk IClub')
    ],
  };

  List<Package> get _availablePackages => _selectedRestaurant != null
      ? _restaurantPackages[_selectedRestaurant!] ?? []
      : [];

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      print("DEBUG: Name listener triggered with text: ${_nameController.text}");
      _onSearchChanged(_nameController.text);
    });
    // _addressController.addListener(() {
    //   print("DEBUG: Address listener triggered with text: ${_addressController.text}");
    // });
    // _phoneController.addListener(() {
    //   print("DEBUG: Phone listener triggered with text: ${_phoneController.text}");
    // });
  }

  void _onSearchChanged(String query) async {
    print("DEBUG: _onSearchChanged called with query: $query");
    setState(() {
      _isTyping = query.isNotEmpty;
    });
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty || !_isFieldFocused) {
        print("DEBUG: Query is empty or field is not focused, clearing results");
        setState(() {
          _searchResults = [];
          _isLoading = false;
          _isTyping = false;
        });
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        print("DEBUG: Sending request to ${Env.apiUrl}/api/customers/search?query=$query");
        final response = await http.get(
          Uri.parse('${Env.apiUrl}/api/customers/search?query=$query'),
        );

        print("DEBUG: Received response with status code: ${response.statusCode}");
        print("DEBUG: Response body: ${response.body}");

        if (response.statusCode == 200) {
          final List<dynamic> results = json.decode(response.body);
          setState(() {
            _searchResults = results.cast<Map<String, dynamic>>();
            _isLoading = false;
            _isTyping = false;
          });
          print("DEBUG: Updated search results, count: ${_searchResults.length}");
        } else {
          throw Exception('Failed to load search results');
        }
      } catch (e) {
        print("DEBUG: Error in _onSearchChanged: $e");
        setState(() {
          _isLoading = false;
          _isTyping = false;
        });
      }
    });
  }

  void _selectCustomer(Map<String, dynamic> customer) {
    print("DEBUG: _selectCustomer called with customer: $customer");
    setState(() {
      _nameController.text = customer['name'];
      _addressController.text = customer['address'];
      _phoneController.text = customer['phone_number'];
      _searchResults = [];
      _isTyping = false;
    });
    // Unfocus the current text field to close the dropdown
    FocusScope.of(context).unfocus();
  }

  void _submitForm() {
    print("DEBUG: _submitForm called");
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
              title: Text('Formulir Terkirim'),
              content: Text('Data pelanggan berhasil disimpan'),
              actions: [
                TextButton(
                    child: Text('OK'),
                    onPressed: () => Navigator.pop(context))
              ]));
    }
  }

  void _addPackage(Package package) {
    print("DEBUG: _addPackage called with package: ${package.name}");
    setState(() {
      var existingPackage = _selectedPackages.firstWhere(
              (element) => element.package.id == package.id,
          orElse: () => SelectedPackage(package: package, quantity: 0));
      if (existingPackage.quantity == 0) _selectedPackages.add(existingPackage);
      existingPackage.quantity++;
    });
  }

  void _removePackage(SelectedPackage selectedPackage) {
    print("DEBUG: _removePackage called with package: ${selectedPackage.package.name}");
    setState(() {
      if (selectedPackage.quantity > 1)
        selectedPackage.quantity--;
      else
        _selectedPackages.remove(selectedPackage);
    });
  }

  void _showSearchDialog() {
    print("DEBUG: _showSearchDialog called");
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Cari Paket'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                      hintText: 'Masukkan nama paket',
                      suffixIcon: Icon(Icons.search)),
                  onChanged: (value) => setState(() {})),
              SizedBox(height: 10),
              Container(
                height: 200,
                width: double.maxFinite,
                child: ListView(
                  children: _availablePackages
                      .where((package) => package.name
                      .toLowerCase()
                      .contains(_searchController.text.toLowerCase()))
                      .map((package) => ListTile(
                      title: Text(package.name),
                      subtitle: Text('Rp${package.price}'),
                      onTap: () {
                        _addPackage(package);
                        Navigator.pop(context);
                      }))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDateTime(BuildContext context) async {
    print("DEBUG: _selectDateTime called");
    final DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: _deliveryDateTime ?? DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime(2101));
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
          context: context,
          initialTime:
          TimeOfDay.fromDateTime(_deliveryDateTime ?? DateTime.now()));
      if (pickedTime != null) {
        setState(() {
          _deliveryDateTime = DateTime(pickedDate.year, pickedDate.month,
              pickedDate.day, pickedTime.hour, pickedTime.minute);
        });
        print("DEBUG: Selected date and time: $_deliveryDateTime");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print("DEBUG: Build method called, _isLoading: $_isLoading, _isTyping: $_isTyping, _searchResults.length: ${_searchResults.length}");
    return BurgerMenu(
      topBarTitle: "Pendaftaran Order",
      activePage: ActivePage.salesCustomerEnrollment,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Focus(
                  onFocusChange: (hasFocus) {
                    setState(() {
                      _isFieldFocused = hasFocus;
                      if (!hasFocus) {
                        _searchResults = [];
                        _isTyping = false;
                      }
                    });
                  },
                  child: TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Nama Pelanggan',
                      hintText: 'Ketik untuk mulai mencari',
                      suffixIcon: _isTyping && _isFieldFocused
                          ? Container(
                        width: 20,
                        height: 20,
                        margin: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : null,
                    ),
                    validator: (value) => value?.isEmpty ?? true
                        ? 'Mohon masukkan nama pelanggan'
                        : null,
                    // onSaved: (value) => _name = value!,
                  ),
                ),
                if (_isLoading && _isFieldFocused)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_searchResults.isNotEmpty && _isFieldFocused)
                  Container(
                    height: 200,
                    child: ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final customer = _searchResults[index];
                        print("DEBUG: Building ListTile for customer: ${customer['name']}");
                        return ListTile(
                          title: Text(customer['name']),
                          subtitle: Text('${customer['address']} - ${customer['phone_number']}'),
                          onTap: () => _selectCustomer(customer),
                        );
                      },
                    ),
                  ),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(labelText: 'Alamat'),
                  validator: (value) =>
                  value?.isEmpty ?? true ? 'Mohon masukkan alamat' : null,
                  // onSaved: (value) => _address = value!,
                ),
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(labelText: 'Nomor Telepon'),
                  keyboardType: TextInputType.phone,
                  validator: (value) => value?.isEmpty ?? true
                      ? 'Mohon masukkan nomor telepon'
                      : null,
                  // onSaved: (value) => _phoneNumber = value!,
                ),
                SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(labelText: 'Nama Restoran'),
                  value: _selectedRestaurant,
                  items: _restaurants
                      .map((restaurant) => DropdownMenuItem(
                      value: restaurant, child: Text(restaurant)))
                      .toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedRestaurant = newValue;
                      _selectedPackage = null;
                      _selectedPackages.clear();
                      // _packageController.clear();
                    });
                  },
                  validator: (value) =>
                  value == null ? 'Mohon pilih restoran' : null,
                  onSaved: (value) => _selectedRestaurant = value,
                ),
                SizedBox(height: 20),
                Text('Pilih Paket:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<Package>(
                        value: _selectedPackage,
                        items: _availablePackages
                            .map((package) => DropdownMenuItem(
                            value: package,
                            child:
                            Text('${package.name} - Rp${package.price}')))
                            .toList(),
                        onChanged: _selectedRestaurant != null
                            ? (newValue) {
                          setState(() {
                            _selectedPackage = newValue;
                            if (newValue != null) _addPackage(newValue);
                          });
                        }
                            : null,
                        decoration: InputDecoration(
                            hintText: 'Pilih paket',
                            enabled: _selectedRestaurant != null),
                      ),
                    ),
                    SizedBox(width: 10),
                    IconButton(
                        icon: Icon(Icons.search),
                        onPressed: _selectedRestaurant != null
                            ? _showSearchDialog
                            : null),
                  ],
                ),
                ..._selectedPackages.map((selectedPackage) => ListTile(
                  title: Text(selectedPackage.package.name),
                  subtitle: Text(
                      '${selectedPackage.package.description} - Rp${selectedPackage.package.price}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Jumlah: ${selectedPackage.quantity}'),
                      IconButton(
                          icon: Icon(Icons.add),
                          onPressed: () =>
                              _addPackage(selectedPackage.package)),
                      IconButton(
                          icon: Icon(Icons.remove),
                          onPressed: () => _removePackage(selectedPackage)),
                    ],
                  ),
                )),
                SizedBox(height: 20),
                InkWell(
                  onTap: () => _selectDateTime(context),
                  child: InputDecorator(
                    decoration: InputDecoration(
                        labelText: 'Tanggal dan Waktu Pengiriman',
                        hintText: 'Pilih tanggal dan waktu'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_deliveryDateTime != null
                            ? DateFormat('dd/MM/yyyy HH:mm')
                            .format(_deliveryDateTime!)
                            : 'Pilih tanggal dan waktu'),
                        Icon(Icons.calendar_today),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Center(
                    child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.5,
                        child: ElevatedButton(
                            onPressed: _submitForm, child: Text('Kirim')))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    print("DEBUG: dispose method called");
    // _packageController.dispose();
    _searchController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}

class Package {
  final String id, name, description;
  final double price;

  Package(
      {required this.id,
        required this.name,
        required this.price,
        required this.description});
}

class SelectedPackage {
  final Package package;
  int quantity;

  SelectedPackage({required this.package, this.quantity = 1});
}