import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'burger_menu.dart';
import 'package:salescroll/env.dart';
import 'dart:async';
import 'loading_overlay.dart';

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
  String? _selectedCustomerId;
  String? _selectedRestaurantId;

  final _restaurantController = TextEditingController();
  List<Map<String, dynamic>> _restaurantSearchResults = [];
  List<Package> _availablePackages = [];
  bool _isRestaurantLoading = false;
  Timer? _restaurantDebounce;
  bool _isRestaurantTyping = false;
  bool _isRestaurantFieldFocused = false;
  bool _isPackagesLoading = false;
  bool _isLoading = false;
  bool _isSubmitting = false;

  List<Restaurant> _availableRestaurants = [];
  Restaurant? _selectedRestaurant;
  bool _isRestaurantsLoading = true;  // Change this line

  Package? _selectedPackage;
  List<SelectedPackage> _selectedPackages = [];
  DateTime? _deliveryDateTime;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;
  bool _isTyping = false;
  bool _isFieldFocused = false;

  final List<String> _restaurants = ['Lombok Idjoe', 'IClub', '2 Fat Guys', 'Ueno'];

  int _calculateTotalPrice() {
    return _selectedPackages.fold(0, (total, selectedPackage) =>
    total + (selectedPackage.package.priceInCents * selectedPackage.quantity));
  }

  String _formatPrice(int priceInCents) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(priceInCents / 100);
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      print("DEBUG: Name listener triggered with text: ${_nameController.text}");
      _onSearchChanged(_nameController.text);
    });
    // Add this listener for restaurant search
    print("DEBUG: Calling _fetchRestaurants() from initState");
    _fetchRestaurants();
    // _restaurantController.addListener(() {
    //   _onRestaurantSearchChanged(_restaurantController.text);
    // });
    // _addressController.addListener(() {
    //   print("DEBUG: Address listener triggered with text: ${_addressController.text}");
    // });
    // _phoneController.addListener(() {
    //   print("DEBUG: Phone listener triggered with text: ${_phoneController.text}");
    // });
  }

  void _showDescription(BuildContext context, String description) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Description'),
          content: SingleChildScrollView(
            child: Text(description),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _onRestaurantSearchChanged(String query) async {
    setState(() {
      _isRestaurantTyping = query.isNotEmpty;
    });
    if (_restaurantDebounce?.isActive ?? false) _restaurantDebounce!.cancel();
    _restaurantDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty || !_isRestaurantFieldFocused) {
        setState(() {
          _restaurantSearchResults = [];
          _isRestaurantLoading = false;
          _isRestaurantTyping = false;
        });
        return;
      }

      setState(() {
        _isRestaurantLoading = true;
      });

      try {
        final response = await http.get(
          Uri.parse('${Env.apiUrl}/api/restaurants/search?query=$query'),
        );

        if (response.statusCode == 200) {
          final List<dynamic> results = json.decode(response.body);
          setState(() {
            _restaurantSearchResults = results.map((result) => {
              'id': result['id'],
              'name': result['name'], // Use 'name' instead of 'restaurant_name'
            }).toList();
            _isRestaurantLoading = false;
            _isRestaurantTyping = false;
          });
          print("DEBUG: Parsed restaurant results: $_restaurantSearchResults");
        } else {
          throw Exception('Failed to load restaurant search results');
        }
      } catch (e) {
        print("Error in _onRestaurantSearchChanged: $e");
        setState(() {
          _restaurantSearchResults = [];
          _isRestaurantLoading = false;
          _isRestaurantTyping = false;
        });
      }
    });
  }

  void _onSearchChanged(String query) async {
    print("DEBUG: _onSearchChanged called with query: '$query'");
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
        final url = '${Env.apiUrl}/api/customers/search?query=$query';
        print("DEBUG: Sending request to $url");
        final response = await http.get(Uri.parse(url));

        print("DEBUG: Received response with status code: ${response.statusCode}");
        print("DEBUG: Response headers: ${response.headers}");
        print("DEBUG: Raw response body: ${response.body}");

        if (response.statusCode == 200) {
          final List<dynamic> results = json.decode(response.body);
          setState(() {
            _searchResults = results.cast<Map<String, dynamic>>();
            _isLoading = false;
            _isTyping = false;
          });
          print("DEBUG: Updated search results, count: ${_searchResults.length}");
          print("DEBUG: First result (if any): ${_searchResults.isNotEmpty ? _searchResults.first : 'No results'}");
        } else {
          print("DEBUG: Non-200 status code received");
          throw Exception('Failed to load search results: ${response.statusCode} ${response.reasonPhrase}');
        }
      } catch (e, stackTrace) {
        print("DEBUG: Error in _onSearchChanged: $e");
        print("DEBUG: Stack trace: $stackTrace");
        setState(() {
          _isLoading = false;
          _isTyping = false;
        });
        // Consider showing an error message to the user here
      }
    });
  }

  void _selectCustomer(Map<String, dynamic> customer) {
    setState(() {
      _selectedCustomerId = customer['id'];  // Save the customer ID
      _nameController.text = customer['name'];
      _addressController.text = customer['address'];
      _phoneController.text = customer['phone_number'];
      _searchResults = [];
      _isTyping = false;
    });
    FocusScope.of(context).unfocus();
  }

  void _selectRestaurant(Restaurant? restaurant) {
    print("DEBUG: Restaurant selected: ${restaurant?.name}");
    setState(() {
      _selectedRestaurant = restaurant;
      _selectedRestaurantId = restaurant?.id;
      _selectedPackage = null;
      _selectedPackages.clear();
      _availablePackages.clear();
    });
    if (restaurant != null) {
      print("DEBUG: Calling _fetchPackagesForRestaurant with ID: ${restaurant.id}");
      _fetchPackagesForRestaurant(restaurant.id);
    }
    FocusScope.of(context).unfocus();
  }

  void _submitForm() async {
    print("DEBUG: _submitForm called");
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Check if delivery date and time are selected
      if (_deliveryDateTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mohon pilih tanggal dan waktu pengiriman')),
        );
        return;
      }

      // Show confirmation modal
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return OrderConfirmationModal(
            customerName: _nameController.text,
            restaurantName: _selectedRestaurant?.name ?? '',
            selectedPackages: _selectedPackages,
            deliveryDateTime: _deliveryDateTime!,
            totalPrice: _calculateTotalPrice(),
            onConfirm: () {
              Navigator.of(context).pop(); // Close the modal
              _processOrder(); // Process the order
            },
            onCancel: () {
              Navigator.of(context).pop(); // Close the modal
            },
          );
        },
      );
    }
  }

  void _processOrder() async {
    setState(() {
      _isSubmitting = true;
    });

    // Prepare the data
    final orderData = {
      'id_customer': _selectedCustomerId,
      'id_restaurant': _selectedRestaurantId,
      'delivery_datetime': _deliveryDateTime!.toIso8601String(),
      'order_items': _selectedPackages.map((sp) => {
        'id_package': sp.package.id,
        'quantity': sp.quantity,
        'price': sp.package.priceInCents,
      }).toList(),
    };

    try {
      final response = await http.post(
        Uri.parse('${Env.apiUrl}/api/orders'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(orderData),
      );

      setState(() {
        _isSubmitting = false;
      });

      if (response.statusCode == 201) {
        // Order saved successfully
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Order Submitted'),
            content: Text('Your order has been saved successfully.'),
            actions: [
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                  // You might want to clear the form or navigate to a different page here
                },
              ),
            ],
          ),
        );
      } else {
        // Error saving order
        throw Exception('Failed to save order');
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      print('Error saving order: $e');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Error'),
          content: Text('There was an error submitting your order. Please try again.'),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
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
                      subtitle: Text(package.formattedPrice),
                      onTap: () {
                        _addPackage(package);
                        Navigator.pop(context);
                      }
                  ))
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

  Future<void> _fetchRestaurants({int retryCount = 3}) async {
    print("DEBUG: Starting to fetch restaurants (attempt ${4 - retryCount})");
    try {
      final url = '${Env.apiUrl}/api/restaurants';
      print("DEBUG: Sending request to $url");
      final response = await http.get(Uri.parse(url));

      print("DEBUG: Received response with status code: ${response.statusCode}");
      print("DEBUG: Response headers: ${response.headers}");
      print("DEBUG: Raw response body: ${response.body}");

      if (response.statusCode == 200) {
        final List<dynamic> restaurantsJson = json.decode(response.body);
        print("DEBUG: Parsed ${restaurantsJson.length} restaurants");
        setState(() {
          _availableRestaurants = restaurantsJson.map((json) {
            try {
              return Restaurant.fromJson(json);
            } catch (e) {
              print("DEBUG: Error parsing restaurant: $e");
              return null;
            }
          }).whereType<Restaurant>().toList();
          _isRestaurantsLoading = false;
        });
        print("DEBUG: Updated _availableRestaurants, length: ${_availableRestaurants.length}");
      } else {
        throw Exception('Failed to load restaurants: ${response.statusCode} ${response.reasonPhrase}');
      }
    } catch (e, stackTrace) {
      print("Error fetching restaurants: $e");
      print("Stack trace: $stackTrace");
      if (retryCount > 0) {
        print("Retrying... (${retryCount - 1} attempts left)");
        await Future.delayed(Duration(seconds: 2));
        return _fetchRestaurants(retryCount: retryCount - 1);
      } else {
        setState(() {
          _isRestaurantsLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load restaurants. Please try again.')),
        );
      }
    }
  }

  Future<void> _fetchPackagesForRestaurant(String restaurantId) async {
    print("DEBUG: Fetching packages for restaurant $restaurantId");
    setState(() {
      _isPackagesLoading = true;
    });
    try {
      final url = '${Env.apiUrl}/api/restaurants/$restaurantId/packages';
      print("DEBUG: Sending request to $url");
      final response = await http.get(Uri.parse(url));

      print("DEBUG: Received response with status code: ${response.statusCode}");
      print("DEBUG: Response headers: ${response.headers}");
      print("DEBUG: Raw response body: ${response.body}");

      if (response.statusCode == 200) {
        final List<dynamic> packagesJson = json.decode(response.body);
        print("DEBUG: Received ${packagesJson.length} packages");
        setState(() {
          _availablePackages = packagesJson.map((json) {
            try {
              return Package.fromJson(json);
            } catch (e) {
              print("DEBUG: Error parsing package: $e");
              return null;
            }
          }).whereType<Package>().toList();
          _isPackagesLoading = false;
        });
        print("DEBUG: _availablePackages updated, length: ${_availablePackages.length}");

        if (_availablePackages.isEmpty) {
          print("DEBUG: No packages found for this restaurant");
          // You can show a message to the user here if needed
        }
      } else {
        throw Exception('Failed to load packages: ${response.statusCode}');
      }
    } catch (e) {
      print("DEBUG: Error fetching packages: $e");
      setState(() {
        _isPackagesLoading = false;
        _availablePackages = []; // Ensure the list is empty in case of an error
      });
      // Show an error message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat paket. Silakan coba lagi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BurgerMenu(
      topBarTitle: "Pendaftaran Order",
      activePage: ActivePage.salesCustomerEnrollment,
      child: LoadingOverlay(
        isLoading: _isSubmitting,
        loadingText: "Menyimpan pesanan...",
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCustomerSearchField(),
                  _buildCustomerDetails(),
                  SizedBox(height: 20),
                  _buildRestaurantDropdown(),
                  SizedBox(height: 20),
                  _buildPackageSelection(),
                  SizedBox(height: 20),
                  _buildSelectedPackages(),
                  SizedBox(height: 20),
                  _buildTotalPrice(),
                  SizedBox(height: 20),
                  _buildDeliveryDateTime(),
                  SizedBox(height: 20),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerSearchField() {
    return Focus(
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
      ),
    );
  }

  Widget _buildCustomerDetails() {
    return Column(
      children: [
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
        ),
        TextFormField(
          controller: _phoneController,
          decoration: InputDecoration(labelText: 'Nomor Telepon'),
          keyboardType: TextInputType.phone,
          validator: (value) => value?.isEmpty ?? true
              ? 'Mohon masukkan nomor telepon'
              : null,
        ),
      ],
    );
  }

  Widget _buildRestaurantDropdown() {
    return RestaurantDropdown(
      availableRestaurants: _availableRestaurants,
      selectedRestaurant: _selectedRestaurant,
      onChanged: _selectRestaurant,
      isLoading: _isRestaurantsLoading,
    );
  }

  Widget _buildPackageSelection() {
    return Row(
      children: [
        Expanded(
          child: PackageDropdown(
            availablePackages: _availablePackages,
            selectedPackage: _selectedPackage,
            onChanged: (Package? newValue) {
              setState(() {
                _selectedPackage = newValue;
                if (newValue != null) _addPackage(newValue);
              });
            },
            isLoading: _isPackagesLoading,
            showDescription: _showDescription, // Add this line
          ),
        ),
        SizedBox(width: 10),
        IconButton(
          icon: Icon(Icons.search),
          onPressed: _selectedRestaurant != null ? _showSearchDialog : null,
        ),
      ],
    );
  }

  Widget _buildSelectedPackages() {
    return Column(
      children: _selectedPackages.asMap().entries.map((entry) {
        final index = entry.key;
        final selectedPackage = entry.value;
        final isEven = index % 2 == 0;
        return Container(
          color: isEven ? Colors.grey[200] : Colors.white,
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedPackage.package.name,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.info_outline, size: 20),
                    onPressed: () => _showDescription(context, selectedPackage.package.description),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_formatPrice(selectedPackage.package.priceInCents)}',
                    style: TextStyle(fontSize: 14),
                  ),
                  Row(
                    children: [
                      Text('Jumlah: ${selectedPackage.quantity}'),
                      IconButton(
                        icon: Icon(Icons.remove, size: 20),
                        onPressed: () => _removePackage(selectedPackage),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                      IconButton(
                        icon: Icon(Icons.add, size: 20),
                        onPressed: () => _addPackage(selectedPackage.package),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTotalPrice() {
    return Text(
      'Total Harga: ${_formatPrice(_calculateTotalPrice())}',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildDeliveryDateTime() {
    return FormField<DateTime>(
      validator: (value) {
        if (_deliveryDateTime == null) {
          return 'Mohon pilih tanggal dan waktu pengiriman';
        }
        return null;
      },
      builder: (FormFieldState<DateTime> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => _selectDateTime(context),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Tanggal dan Waktu Pengiriman',
                  hintText: 'Pilih tanggal dan waktu',
                  errorText: state.errorText,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_deliveryDateTime != null
                        ? DateFormat('dd/MM/yyyy HH:mm').format(_deliveryDateTime!)
                        : 'Pilih tanggal dan waktu'),
                    Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubmitButton() {
    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.5,
        child: ElevatedButton(
          onPressed: _submitForm,
          child: Text('Kirim'),
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
    _restaurantController.dispose();
    super.dispose();
  }
}
class Package {
  final String id;
  final String name;
  final String description;
  final int priceInCents;

  Package({
    required this.id,
    required this.name,
    required this.priceInCents,
    required this.description
  });

  factory Package.fromJson(Map<String, dynamic> json) {
    return Package(
      id: json['id'],
      name: json['package_name'],
      description: json['description'],
      priceInCents: json['price'],
    );
  }

  String get formattedPrice {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(priceInCents / 100);
  }
}

class SelectedPackage {
  final Package package;
  int quantity;

  SelectedPackage({required this.package, this.quantity = 1});
}

class OrderConfirmationModal extends StatelessWidget {
  final String customerName;
  final String restaurantName;
  final List<SelectedPackage> selectedPackages;
  final DateTime deliveryDateTime;
  final int totalPrice;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  OrderConfirmationModal({
    required this.customerName,
    required this.restaurantName,
    required this.selectedPackages,
    required this.deliveryDateTime,
    required this.totalPrice,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final TextStyle defaultTextStyle = Theme.of(context).textTheme.labelLarge ?? TextStyle();
    final TextStyle smallerTextStyle = defaultTextStyle.copyWith(
      fontSize: (defaultTextStyle.fontSize ?? 14) - 2,
    );

    return AlertDialog(
      title: Text('Konfirmasi Pesanan', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Pelanggan', customerName),
            _buildInfoRow('Restoran', restaurantName),
            SizedBox(height: 16),
            Text('Paket yang dipesan:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            ...selectedPackages.map((sp) => _buildPackageRow(sp)),
            SizedBox(height: 16),
            _buildDeliveryDateTime(),
            SizedBox(height: 16),
            _buildTotalPrice(),
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: onCancel,
                child: Text('Batal', style: smallerTextStyle.copyWith(color: Colors.white)),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey[600],
                  minimumSize: Size(double.infinity, 36),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: onConfirm,
                child: Text('Konfirmasi', style: smallerTextStyle.copyWith(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: Size(double.infinity, 36),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageRow(SelectedPackage sp) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 16),
          Expanded(
            child: Text(sp.package.name),
          ),
          SizedBox(width: 8),
          Text('${sp.quantity}x'),
          SizedBox(width: 8),
          Text(_formatPrice(sp.package.priceInCents * sp.quantity)),
        ],
      ),
    );
  }

  Widget _buildDeliveryDateTime() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Waktu Pengiriman:', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Padding(
          padding: EdgeInsets.only(left: 16),
          child: Text(DateFormat('dd/MM/yyyy HH:mm').format(deliveryDateTime)),
        ),
      ],
    );
  }

  Widget _buildTotalPrice() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Total Harga', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(_formatPrice(totalPrice), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }

  String _formatPrice(int priceInCents) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(priceInCents / 100);
  }
}

class PackageDropdown extends StatelessWidget {
  final List<Package> availablePackages;
  final Package? selectedPackage;
  final Function(Package?) onChanged;
  final bool isLoading;
  final Function(BuildContext, String) showDescription;

  PackageDropdown({
    required this.availablePackages,
    this.selectedPackage,
    required this.onChanged,
    required this.isLoading,
    required this.showDescription,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DropdownButtonFormField<Package>(
          value: selectedPackage,
          items: availablePackages.isEmpty
              ? []
              : availablePackages.map((package) => DropdownMenuItem<Package>(
            value: package,
            child: Row(
              children: [
                Container(
                  width: 40,
                  child: IconButton(
                    icon: Icon(Icons.info_outline, size: 20),
                    onPressed: () => showDescription(context, package.description),
                    alignment: Alignment.center,
                    padding: EdgeInsets.zero,
                  ),
                ),
                SizedBox(width: 8), // Add some space between the icon and text
                Expanded(
                  child: Text('${package.name} - ${package.formattedPrice}'),
                ),
              ],
            ),
          )).toList(),
          onChanged: (isLoading || availablePackages.isEmpty) ? null : onChanged,
          hint: Text(
              isLoading
                  ? 'Memuat paket...'
                  : availablePackages.isEmpty
                  ? 'Tidak ada paket terdaftar'
                  : 'Pilih paket'
          ),
          isExpanded: true,
          decoration: InputDecoration(
            enabled: !isLoading && availablePackages.isNotEmpty,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black12,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }
}

class Restaurant {
  final String id;
  final String name;

  Restaurant({required this.id, required this.name});

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    print("DEBUG: Parsing restaurant JSON: $json");
    return Restaurant(
      id: json['id'] as String? ?? '',
      name: json['restaurant_name'] as String? ?? '',
    );
  }
}

class RestaurantDropdown extends StatelessWidget {
  final List<Restaurant> availableRestaurants;
  final Restaurant? selectedRestaurant;
  final Function(Restaurant?) onChanged;
  final bool isLoading;

  RestaurantDropdown({
    required this.availableRestaurants,
    this.selectedRestaurant,
    required this.onChanged,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DropdownButtonFormField<Restaurant>(
          value: selectedRestaurant,
          items: availableRestaurants.isEmpty
              ? []
              : availableRestaurants.map((restaurant) => DropdownMenuItem<Restaurant>(
            value: restaurant,
            child: Text(restaurant.name),
          )).toList(),
          onChanged: (isLoading || availableRestaurants.isEmpty) ? null : onChanged,
          hint: Text(
              isLoading
                  ? 'Memuat restoran...'
                  : availableRestaurants.isEmpty
                  ? 'Tidak ada restoran terdaftar'
                  : 'Pilih restoran'
          ),
          isExpanded: true,
          decoration: InputDecoration(
            // Remove the labelText
            enabled: !isLoading && availableRestaurants.isNotEmpty,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: (value) => value == null ? 'Mohon pilih restoran' : null,
        ),
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black12,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }
}