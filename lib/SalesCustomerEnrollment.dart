import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'widgets/burger_menu.dart';
import 'package:salescroll/services/env.dart';
import 'dart:async';
import 'widgets/loading_overlay.dart';
import 'widgets/network_error_handler.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

class SalesCustomerEnrollmentPage extends StatefulWidget {
  @override
  _SalesCustomerEnrollmentPageState createState() => _SalesCustomerEnrollmentPageState();
}

class _SalesCustomerEnrollmentPageState extends State<SalesCustomerEnrollmentPage> {
  final GlobalKey<_SalesCustomerEnrollmentFormState> _formKey = GlobalKey<_SalesCustomerEnrollmentFormState>();

  void _refreshPage() {
    _formKey.currentState?.resetForm();
    // Add any additional refresh logic here
  }

  @override
  Widget build(BuildContext context) {
    return NetworkErrorHandler(
      child: BurgerMenu(
        topBarTitle: "Pendaftaran Order",
        activePage: ActivePage.salesCustomerEnrollment,
        onRefresh: _refreshPage,
        child: SalesCustomerEnrollmentForm(key: _formKey),
      ),
    );
  }
}

class SalesCustomerEnrollmentForm extends StatefulWidget {
  SalesCustomerEnrollmentForm({Key? key}) : super(key: key);

  @override
  _SalesCustomerEnrollmentFormState createState() => _SalesCustomerEnrollmentFormState();
}

class _SalesCustomerEnrollmentFormState extends State<SalesCustomerEnrollmentForm> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedCustomerId;
  String? _selectedRestaurantId;
  String _formatPrice(int priceInCents) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(priceInCents);
  }

  List<Restaurant> _availableRestaurants = [];
  List<Package> _availablePackages = [];
  List<SelectedPackage> _selectedPackages = [];
  List<Map<String, dynamic>> _searchResults = [];
  List<OrderPurpose> _purposeOptions = [];

  Map<String, dynamic>? _selectedCustomer;

  bool _isPackagesLoading = false;
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isTyping = false;
  bool _isFieldFocused = false;
  bool _isRestaurantsLoading = true;
  bool _isCustomerSelected = false;

  Restaurant? _selectedRestaurant;
  Package? _selectedPackage;
  DateTime? _deliveryDateTime;
  Timer? _debounce;
  OrderPurpose? _selectedPurpose;

  int _calculateTotalPrice() {
    return _selectedPackages.fold(0, (total, selectedPackage) =>
    total + (selectedPackage.package.priceInCents * selectedPackage.quantity));
  }

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _fetchRestaurants();
    _fetchPurposes();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
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
                _buildPurposeDropdown(),
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
    );
  }

  void resetForm() {
    setState(() {
      _selectedCustomerId = null;
      _selectedRestaurantId = null;
      _selectedPackages.clear();
      _searchResults.clear();
      _deliveryDateTime = null;
      _nameController.clear();
      _addressController.clear();
      _phoneController.clear();
      _searchController.clear();
      _selectedRestaurant = null;
      _selectedPackage = null;
      _selectedPurpose = null;
      _isPackagesLoading = false;
      _isLoading = false;
      _isSubmitting = false;
      _isTyping = false;
      _isFieldFocused = false;
      _isRestaurantsLoading = true;
      _isCustomerSelected = false;
      _selectedCustomer = null;
      _availablePackages.clear();
    });
    _formKey.currentState?.reset();
    _fetchRestaurants();
    _fetchPurposes();
  }

  void _setupListeners() {
    _nameController.addListener(() {
      print("DEBUG: Name listener triggered with text: ${_nameController.text}");
      _onSearchChanged(_nameController.text);
    });
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

  void _selectCustomer(Map<String, dynamic> customer) {
    setState(() {
      _selectedCustomer = customer;
      _selectedCustomerId = customer['id'];
      _nameController.text = customer['name'];
      _addressController.text = customer['address'];
      _phoneController.text = customer['phone_number'];
      _searchResults = [];
      _isTyping = false;
      _isCustomerSelected = true;
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
      _availablePackages = [];
      _isPackagesLoading = true;
    });
    if (restaurant != null) {
      print("DEBUG: Calling _fetchPackagesForRestaurant with ID: ${restaurant.id}");
      _fetchPackagesForRestaurant(restaurant.id);
    } else {
      print("DEBUG: No restaurant selected, clearing packages");
      setState(() {
        _isPackagesLoading = false;
      });
    }
  }

  void _submitForm() async {
    print("DEBUG: _submitForm called");
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (_selectedCustomer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mohon pilih pelanggan dari daftar')),
        );
        return;
      }

      if (_selectedPurpose == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mohon pilih keperluan')),
        );
        return;
      }

      if (_deliveryDateTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mohon pilih tanggal dan waktu pengiriman')),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return OrderConfirmationModal(
            customerName: _nameController.text,
            restaurantName: _selectedRestaurant?.name ?? '',
            selectedPackages: _selectedPackages,
            deliveryDateTime: _deliveryDateTime!,
            totalPrice: _calculateTotalPrice(),
            purpose: _selectedPurpose!,
            onConfirm: () {
              Navigator.of(context).pop();
              _processOrder();
            },
            onCancel: () {
              Navigator.of(context).pop();
            },
          );
        },
      );
    }
  }

  void _addSelectedPackage() {
    if (_selectedPackage != null) {
      setState(() {
        _addPackage(_selectedPackage!);
        // Optionally, reset _selectedPackage to null after adding
        // _selectedPackage = null;
      });
      // Show a snackbar to confirm the package was added
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedPackage!.name} added to the order'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _processOrder() async {
    setState(() {
      _isSubmitting = true;
    });

    // Get the current user's UID
    final User? user = FirebaseAuth.instance.currentUser;
    final String? firebaseUid = user?.uid;

    if (firebaseUid == null) {
      // Handle the case where the user is not logged in
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not logged in. Please log in and try again.')),
      );
      setState(() {
        _isSubmitting = false;
      });
      return;
    }

    final orderData = {
      'id_customer': _selectedCustomerId,
      'id_restaurant': _selectedRestaurantId,
      'id_order_purpose': _selectedPurpose!.id.toString(),
      'delivery_datetime': _deliveryDateTime!.toIso8601String(),
      'order_items': _selectedPackages.map((sp) => {
        'id_package': sp.package.id,
        'quantity': sp.quantity,
        'price': sp.package.priceInCents,
      }).toList(),
      'firebase_uid': firebaseUid, // Add the Firebase UID to the order data
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
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => SalesCustomerEnrollmentPage()),
                  );
                },
              ),
            ],
          ),
        );
      } else {
        throw Exception('Failed to save order');
      }
    } catch (e) {
      NetworkErrorNotifier.instance.notifyError();
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

  Future<void> _fetchPurposes() async {
    print("DEBUG: Starting to fetch purposes");
    try {
      final response = await http.get(Uri.parse('${Env.apiUrl}/api/order-purposes'));
      print("DEBUG: Received response with status code: ${response.statusCode}");
      print("DEBUG: Response body: ${response.body}");

      if (response.statusCode == 200) {
        final List<dynamic> purposesJson = json.decode(response.body);
        print("DEBUG: Parsed ${purposesJson.length} purposes");
        setState(() {
          _purposeOptions = purposesJson.map((json) {
            try {
              return OrderPurpose.fromJson(json);
            } catch (e) {
              print("DEBUG: Error parsing purpose JSON: $e");
              print("DEBUG: Problematic JSON: $json");
              return null;
            }
          }).whereType<OrderPurpose>().toList();
        });
        print("DEBUG: _purposeOptions updated, length: ${_purposeOptions.length}");
      } else {
        throw Exception('Failed to load purposes: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching purposes: $e');
    }
  }

  Future<void> _onSearchChanged(String query) async {
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
        NetworkErrorNotifier.instance.notifyError();
        setState(() {
          _isLoading = false;
          _isTyping = false;
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> _debouncedSearch(String pattern) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    final completer = Completer<List<Map<String, dynamic>>>();

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final results = await _searchCustomers(pattern);
        completer.complete(results);
      } catch (e) {
        completer.completeError(e);
      }
    });

    return completer.future;
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
      NetworkErrorNotifier.instance.notifyError();
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

  Future<List<Map<String, dynamic>>> _searchCustomers(String pattern) async {
    setState(() {
      _isTyping = true;
    });

    try {
      final url = '${Env.apiUrl}/api/customers/search?query=$pattern';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        setState(() {
          _searchResults = results.cast<Map<String, dynamic>>();
          _isTyping = false;
        });
        return _searchResults;
      } else {
        throw Exception('Failed to load search results: ${response.statusCode} ${response.reasonPhrase}');
      }
    } catch (e) {
      print("Error in _searchCustomers: $e");
      NetworkErrorNotifier.instance.notifyError();
      setState(() {
        _isTyping = false;
      });
      return [];
    }
  }

  Future<void> _fetchPackagesForRestaurant(String restaurantId) async {
    print("DEBUG: Fetching packages for restaurant $restaurantId");
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

        final List<Package> newPackages = packagesJson.map((json) {
          try {
            return Package.fromJson(json);
          } catch (e) {
            print("DEBUG: Error parsing package: $e");
            return null;
          }
        }).whereType<Package>().toList();

        setState(() {
          _availablePackages = newPackages;
          _isPackagesLoading = false;
        });

        print("DEBUG: _availablePackages updated, length: ${_availablePackages.length}");

        if (_availablePackages.isEmpty) {
          print("DEBUG: No packages found for this restaurant");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tidak ada paket tersedia untuk restoran ini.')),
          );
        }
      } else {
        throw Exception('Failed to load packages: ${response.statusCode}');
      }
    } catch (e) {
      print("DEBUG: Error fetching packages: $e");
      NetworkErrorNotifier.instance.notifyError();
      setState(() {
        _isPackagesLoading = false;
        _availablePackages = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat paket. Silakan coba lagi.')),
      );
    }
  }

  Widget _buildCustomerSearchField() {
    return Stack(
      children: [
        TypeAheadFormField<Map<String, dynamic>>(
          textFieldConfiguration: TextFieldConfiguration(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Nama Pelanggan',
              hintText: _isCustomerSelected ? '' : 'Ketik untuk mulai mencari',
              suffixIcon: _isTyping && !_isCustomerSelected
                  ? Container(
                width: 20,
                height: 20,
                margin: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : null,
              filled: _isCustomerSelected,
              fillColor: _isCustomerSelected ? Colors.green[50] : null,
              border: OutlineInputBorder(),
              enabledBorder: _isCustomerSelected
                  ? OutlineInputBorder(borderSide: BorderSide(color: Colors.green))
                  : null,
            ),
            enabled: !_isCustomerSelected,
          ),
          suggestionsCallback: (pattern) async {
            if (pattern.isEmpty || _isCustomerSelected) {
              return [];
            }
            return _debouncedSearch(pattern);
          },
          itemBuilder: (context, suggestion) {
            return ListTile(
              title: Text(suggestion['name']),
              subtitle: Text('${suggestion['address']} - ${suggestion['phone_number']}'),
            );
          },
          onSuggestionSelected: (suggestion) {
            _selectCustomer(suggestion);
          },
          noItemsFoundBuilder: (context) {
            return _isTyping && !_isCustomerSelected
                ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Center(child: CircularProgressIndicator()),
            )
                : Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text('No items found', textAlign: TextAlign.center),
            );
          },
          validator: (value) {
            if (_selectedCustomer == null) {
              return 'Mohon pilih pelanggan dari daftar';
            }
            return null;
          },
        ),
        if (_isCustomerSelected)
          Positioned(
            right: 8,
            top: 8,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isCustomerSelected = false;
                  _selectedCustomer = null;
                  _selectedCustomerId = null;
                  _nameController.clear();
                  _addressController.clear();
                  _phoneController.clear();
                });
              },
              child: Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPurposeDropdown() {
    print("DEBUG: Building purpose dropdown. Options count: ${_purposeOptions.length}");
    return _purposeOptions.isEmpty
        ? Center(child: CircularProgressIndicator())
        : DropdownButtonFormField<OrderPurpose>(
      value: _selectedPurpose,
      items: _purposeOptions.map((purpose) => DropdownMenuItem<OrderPurpose>(
        value: purpose,
        child: Text(purpose.name),
      )).toList(),
      onChanged: (OrderPurpose? newValue) {
        setState(() {
          _selectedPurpose = newValue;
        });
      },
      decoration: InputDecoration(
        labelText: 'Keperluan/Purpose',
        border: OutlineInputBorder(),
      ),
      validator: (value) => value == null ? 'Mohon pilih keperluan' : null,
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
    print("DEBUG: Building package selection");
    print("DEBUG: _isPackagesLoading: $_isPackagesLoading");
    print("DEBUG: _availablePackages length: ${_availablePackages.length}");
    return Row(
      children: [
        Expanded(
          child: PackageDropdown(
            availablePackages: _availablePackages,
            selectedPackage: _selectedPackage,
            onChanged: (Package? newValue) {
              setState(() {
                _selectedPackage = newValue;
              });
            },
            isLoading: _isPackagesLoading,
            showDescription: _showDescription,
          ),
        ),
        SizedBox(width: 10),
        ElevatedButton(
          onPressed: _selectedPackage != null ? _addSelectedPackage : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 20),
              SizedBox(width: 4),
              Text('Add'),
            ],
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green, // Replaces primary
            foregroundColor: Colors.white, // Replaces onPrimary
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 2,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
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
    _debounce?.cancel();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
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
    return formatter.format(priceInCents);
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
  final OrderPurpose purpose;
  final VoidCallback onCancel;

  OrderConfirmationModal({
    required this.customerName,
    required this.restaurantName,
    required this.selectedPackages,
    required this.deliveryDateTime,
    required this.totalPrice,
    required this.onConfirm,
    required this.purpose,
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
            _buildInfoRow('Keperluan', purpose.name),
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
    return formatter.format(priceInCents);
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
    print("DEBUG: Building PackageDropdown");
    print("DEBUG: Available packages: ${availablePackages.length}");
    print("DEBUG: Is loading: $isLoading");

    return Stack(
      children: [
        DropdownButtonFormField<Package>(
          value: selectedPackage,
          items: availablePackages.map((package) => DropdownMenuItem<Package>(
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
                SizedBox(width: 8),
                Expanded(
                  child: Text('${package.name} - ${package.formattedPrice}'),
                ),
              ],
            ),
          )).toList(),
          onChanged: isLoading ? null : onChanged,
          hint: Text(
              isLoading
                  ? 'Memuat paket...'
                  : availablePackages.isEmpty
                  ? 'Tidak ada paket terdaftar'
                  : 'Pilih paket'
          ),
          isExpanded: true,
          decoration: InputDecoration(
            enabled: !isLoading,
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

class OrderPurpose {
  final int id;
  final String name;
  final String nameEn;

  OrderPurpose({required this.id, required this.name, required this.nameEn});

  factory OrderPurpose.fromJson(Map<String, dynamic> json) {
    return OrderPurpose(
      id: json['id'] as int,
      name: json['name'] as String,
      nameEn: json['name_en'] as String,
    );
  }
}