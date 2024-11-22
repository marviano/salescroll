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
  dynamic _selectedRoom;

  int _duration = 60;

  String _memo = '';
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
  bool _isPackageBooking = true;
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isTyping = false;
  bool _isFieldFocused = false;
  bool _isRestaurantsLoading = true;
  bool _isCustomerSelected = false;

  bool _validateOrder() {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return false;
    }

    if (_selectedCustomer == null) {
      showTopSnackBar('Mohon pilih pelanggan dari daftar');
      return false;
    }

    if (_selectedPurpose == null) {
      showTopSnackBar('Mohon pilih keperluan');
      return false;
    }

    if (_selectedRestaurant == null) {
      showTopSnackBar('Mohon pilih restoran');
      return false;
    }

    if (_selectedRoom == null) {
      showTopSnackBar('Mohon pilih ruangan');
      return false;
    }

    if (_selectedLayout == null) {
      showTopSnackBar('Mohon pilih layout ruangan');
      return false;
    }

    if (_numberOfPeople <= 0) {
      showTopSnackBar('Mohon masukkan jumlah orang');
      return false;
    }

    if (_deliveryDateTime == null) {
      showTopSnackBar('Mohon pilih tanggal dan waktu');
      return false;
    }

    // Separate validation for package booking and room-only booking
    if (_isPackageBooking) {
      if (_selectedPackages.isEmpty) {
        showTopSnackBar('Mohon pilih minimal satu paket');
        return false;
      }
    } else {
      // Room-only booking validations
      if (_duration <= 0) {
        showTopSnackBar('Durasi harus lebih dari 0 menit');
        return false;
      }
      if (_duration > 1440) { // 24 hours in minutes
        showTopSnackBar('Durasi maksimal 24 jam (1440 menit)');
        return false;
      }
    }

    return true;
  }


  Restaurant? _selectedRestaurant;
  Package? _selectedPackage;
  DateTime? _deliveryDateTime;
  Timer? _debounce;
  OrderPurpose? _selectedPurpose;
  RoomShape? _selectedLayout;

  int _numberOfPeople = 0;

  // Helper function to calculate ceiling hours
  int calculateCeilingHours(int minutes) {
    // Always round up to the next hour
    // For example: 62 minutes -> 2 hours, 121 minutes -> 3 hours
    return (minutes + 59) ~/ 60; // Using integer division with roundup
  }

// Helper function to calculate total room price with ceiling hours
  int calculateRoomPrice(int pricePerHour, int durationMinutes) {
    final ceilingHours = calculateCeilingHours(durationMinutes);
    return pricePerHour * ceilingHours;
  }

  int _calculateTotalPrice() {
    if (_isPackageBooking) {
      return _selectedPackages.fold(0, (total, selectedPackage) {
        final packagePrice = selectedPackage.package.priceInCents;
        final quantity = selectedPackage.quantity;
        return total + (packagePrice * quantity);
      });
    } else {
      // Room-only booking
      if (_selectedRoom != null) {
        try {
          final pricePerHour = _parsePrice(_selectedRoom['price_per_hour']);
          final ceilingHours = calculateCeilingHours(_duration);
          return pricePerHour * ceilingHours;
        } catch (e) {
          print("DEBUG: Error calculating room price: $e");
          return 0;
        }
      }
      return 0;
    }
  }

  int _parsePrice(dynamic price) {
    if (price == null) {
      print("Price is null");
      return 0;
    }

    try {
      if (price is int) {
        return price;
      } else if (price is double) {
        return price.toInt();
      } else if (price is String) {
        // Remove any non-numeric characters except decimal point
        final cleanedPrice = price.replaceAll(RegExp(r'[^0-9.]'), '');
        if (cleanedPrice.isEmpty) {
          print("Cleaned price string is empty");
          return 0;
        }
        if (cleanedPrice.contains('.')) {
          return double.parse(cleanedPrice).toInt();
        }
        return int.parse(cleanedPrice);
      } else {
        print("Unexpected price type: ${price.runtimeType}");
        return 0;
      }
    } catch (e) {
      print("Error parsing price '$price': $e");
      return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _fetchRestaurants();
    _fetchPurposes();
  }

  Widget _buildBookingTypeToggle() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isPackageBooking ? 'Booking dengan Paket' : 'Booking Ruangan Saja',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Switch(
                  value: _isPackageBooking,
                  onChanged: (bool value) {
                    setState(() {
                      _isPackageBooking = value;
                      if (!value) {
                        _selectedPackages.clear();
                      }
                    });
                  },
                  activeColor: Colors.green,
                ),
              ],
            ),
            if (!_isPackageBooking && _selectedRoom != null) ...[
              Divider(height: 24),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Room rate per hour:'),
                        Text(
                          _formatPrice(_parsePrice(_selectedRoom['price_per_hour'] ?? 0)),
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Duration:'),
                        Text(
                          '${(_duration / 60).toStringAsFixed(1)} hours',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Room Cost:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _formatPrice(_calculateRoomCost()),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _calculateRoomCost() {
    if (_selectedRoom == null) return 0;

    final pricePerHour = _parsePrice(_selectedRoom['price_per_hour'] ?? 0);
    final ceilingHours = calculateCeilingHours(_duration);
    return pricePerHour * ceilingHours; // Use ceiling hours instead of raw division
  }

  Widget _buildNumberOfPeopleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          decoration: InputDecoration(
            labelText: 'Jumlah Orang',
            border: OutlineInputBorder(),
            suffixText: _selectedRoom != null ? 'Kapasitas: ${_selectedRoom['capacity']}' : null,
            fillColor: _selectedRoom != null && _numberOfPeople > _selectedRoom['capacity']
                ? Colors.yellow[50]
                : null,
            filled: _selectedRoom != null && _numberOfPeople > _selectedRoom['capacity'],
            enabledBorder: _selectedRoom != null && _numberOfPeople > _selectedRoom['capacity']
                ? OutlineInputBorder(borderSide: BorderSide(color: Colors.yellow[700]!))
                : null,
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Mohon masukkan jumlah orang';
            }
            final number = int.tryParse(value);
            if (number == null || number <= 0) {
              return 'Jumlah orang harus lebih dari 0';
            }
            return null;
          },
          onChanged: (value) {
            setState(() {
              _numberOfPeople = int.tryParse(value) ?? 0;
            });
          },
        ),
        if (_selectedRoom != null && _numberOfPeople > _selectedRoom['capacity'])
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: Colors.yellow[700]
                ),
                SizedBox(width: 8),
                Text(
                  'Jumlah orang melebihi kapasitas ruangan',
                  style: TextStyle(
                    color: Colors.yellow[700],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRestaurantDropdown() {
    return RestaurantDropdown(
      availableRestaurants: _availableRestaurants,
      selectedRestaurant: _selectedRestaurant,
      onChanged: (Restaurant? restaurant) {
        _selectRestaurant(restaurant);
        setState(() {
          _selectedLayout = null;
          _numberOfPeople = 0;
          _selectedRoom = null;
        });
      },
      isLoading: _isRestaurantsLoading,
      onDateTimeChanged: (DateTime? dateTime) {
        setState(() {
          _deliveryDateTime = dateTime;
          _selectedRoom = null;
          _selectedLayout = null;
        });
      },
      onRoomSelected: (dynamic room) {
        setState(() {
          _selectedRoom = room;
          _selectedLayout = null;
        });
      },
      onLayoutSelected: (RoomShape? layout) {
        setState(() {
          _selectedLayout = layout;
        });
      },
      showMemoModal: _showMemoModal,  // Add this
      memo: _memo,  // Add this
    );
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
                _buildDurationAndPeopleFields(),
                SizedBox(height: 20),
                _buildPackageSection(),
                SizedBox(height: 20),
                _buildTotalPrice(),
                SizedBox(height: 20),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMemoModal() {
    final TextEditingController memoController = TextEditingController(text: _memo);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Tambah Memo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: memoController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Tulis memo/catatan di sini...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _memo = memoController.text;
                });
                Navigator.of(context).pop();
                if (_memo.isNotEmpty) {
                  showTopSnackBar('Memo berhasil disimpan');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void resetForm() {
    setState(() {
      _duration = 60;
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
    print("DEBUG: Selected customer data: $customer"); // Add this line
    setState(() {
      _selectedCustomer = customer;
      _selectedCustomerId = customer['id'];
      _nameController.text = customer['name'];
      _addressController.clear(); // Clear first
      _phoneController.clear(); // Clear first
      _addressController.text = customer['address'] ?? '';
      _phoneController.text = customer['phone_number'] ?? '';
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

  void _submitForm() {
    print("DEBUG: Submit button pressed");

    if (!_validateOrder()) {
      return;
    }

    print("DEBUG: Showing confirmation dialog");
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return OrderConfirmationModal(
          isPackageBooking: _isPackageBooking,
          roomPricePerHour: _selectedRoom['price_per_hour'] ?? 0,
          customerName: _nameController.text,
          restaurantName: _selectedRestaurant?.name ?? '',
          selectedPackages: _selectedPackages,
          duration: _duration,
          deliveryDateTime: _deliveryDateTime!,
          totalPrice: _calculateTotalPrice(),
          purpose: _selectedPurpose!,
          roomName: _selectedRoom['room_name'] ?? '',
          roomShape: _selectedLayout?.shapeName ?? '',
          numberOfPeople: _numberOfPeople,
          memo: _memo,
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


  void _addSelectedPackage() {
    if (_selectedPackage != null) {
      setState(() {
        _addPackage(_selectedPackage!);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedPackage!.name} added to the order'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating, // Add this
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 100,
            left: 10,
            right: 10,
          ), // Add this to position at top
        ),
      );
    }
  }

  void showTopSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 100,
          left: 10,
          right: 10,
        ),
      ),
    );
  }

  void _processOrder() async {
    print("DEBUG: Starting order submission process");

    if (!_validateOrder()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final User? user = FirebaseAuth.instance.currentUser;
    final String? firebaseUid = user?.uid;

    if (firebaseUid == null) {
      showTopSnackBar('User not logged in');
      setState(() {
        _isSubmitting = false;
      });
      return;
    }

    // Calculate room price for room-only bookings
    final roomPricePerHour = _selectedRoom != null ? _parsePrice(_selectedRoom['price_per_hour']) : 0;
    final ceilingHours = calculateCeilingHours(_duration);
    final totalRoomPrice = !_isPackageBooking ? (roomPricePerHour * ceilingHours) : 0;

    final orderItems = _isPackageBooking ? _selectedPackages.map((sp) => {
      'id_package': sp.package.id,
      'quantity': sp.quantity,
      'price_per_item': sp.package.priceInCents
    }).toList() : [];

    // Prepare order data
    final orderData = {
      'id_customer': _selectedCustomerId,
      'id_restaurant': _selectedRestaurantId,
      'id_room_shape': _selectedLayout!.id,
      'meeting_room_id': _selectedRoom['id'],
      'number_of_people': _numberOfPeople,
      'id_order_purpose': _selectedPurpose!.id,
      'delivery_datetime': _deliveryDateTime!.toIso8601String(),
      'memo': _memo,
      'firebase_uid': firebaseUid,
      'duration_minutes': _duration,
      'is_room_only': !_isPackageBooking,
      'order_items': orderItems,
      'room_price_per_hour': roomPricePerHour,
      'total_room_price': totalRoomPrice,
    };

    print("DEBUG: Order data prepared: ${json.encode(orderData)}");

    try {
      final response = await http.post(
        Uri.parse('${Env.apiUrl}/api/orders'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(orderData),
      );

      print("DEBUG: Order submission response status: ${response.statusCode}");
      print("DEBUG: Order submission response body: ${response.body}");

      setState(() {
        _isSubmitting = false;
      });

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        print("DEBUG: Order saved with ID: ${responseData['id']}");

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Order Submitted'),
            content: !_isPackageBooking
                ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Booking ruangan berhasil disimpan.'),
                SizedBox(height: 8),
                Text('Durasi: $_duration menit'),
                Text('Dibebankan: ${calculateCeilingHours(_duration)} jam'),
                Text('Total: ${NumberFormat.currency(
                  locale: 'id_ID',
                  symbol: 'Rp ',
                  decimalDigits: 0,
                ).format(totalRoomPrice)}'),
              ],
            )
                : Text('Pemesanan paket berhasil disimpan.'),
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
      }
    } catch (e) {
      print("DEBUG: Error during order submission: $e");
      NetworkErrorNotifier.instance.notifyError();
      setState(() {
        _isSubmitting = false;
      });
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Error'),
          content: Text('Failed to submit order: $e'),
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
      // Add status=active to the query parameters
      final url = '${Env.apiUrl}/api/restaurants?status=active';
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
        print("DEBUG: Search results: $results"); // Add this line
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

  Widget _buildPackageSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Booking Type Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isPackageBooking ? 'Booking dengan Paket' : 'Booking Ruangan Saja',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Switch(
                value: _isPackageBooking,
                onChanged: (bool value) {
                  setState(() {
                    _isPackageBooking = value;
                    if (!value) {
                      _selectedPackages.clear();
                    }
                  });
                },
                activeColor: Colors.green,
              ),
            ],
          ),

          // Room Price Info (when room-only booking)
          if (!_isPackageBooking && _selectedRoom != null)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Harga per jam:'),
                        Text(
                          _formatPrice(_parsePrice(_selectedRoom['price_per_hour'] ?? 0)),
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total (${(_duration / 60).toStringAsFixed(1)} jam):',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          _formatPrice(_calculateRoomCost()),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Package Selection Section
          if (_isPackageBooking) ...[
            Divider(height: 24),
            Row(
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
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            if (_selectedPackages.isEmpty && _isPackageBooking)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Pilih minimal satu paket',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 12,
                  ),
                ),
              ),
            if (_selectedPackages.isNotEmpty) ...[
              SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _selectedPackages.length,
                itemBuilder: (context, index) {
                  final selectedPackage = _selectedPackages[index];
                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedPackage.package.name,
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Text(
                                _formatPrice(selectedPackage.package.priceInCents * selectedPackage.quantity),
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove),
                              onPressed: () => _removePackage(selectedPackage),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '${selectedPackage.quantity}',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.add),
                              onPressed: () => _addPackage(selectedPackage.package),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildRoomPriceCard({required int pricePerHour, required int duration}) {
    final ceilingHours = calculateCeilingHours(duration);
    final totalPrice = pricePerHour * ceilingHours;

    return Container(
      width: double.infinity,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Harga per jam',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      )),
                  Text(_formatPrice(pricePerHour),
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      )),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Durasi',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      )),
                  Text('$duration menit ($ceilingHours jam)',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      )),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      )),
                  Text(_formatPrice(totalPrice),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.blue[800],
                      )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationAndPeopleFields() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Jumlah Orang',
                  border: OutlineInputBorder(),
                  suffixText: _selectedRoom != null ? 'Kapasitas: ${_selectedRoom['capacity']}' : null,
                  fillColor: _selectedRoom != null && _numberOfPeople > _selectedRoom['capacity']
                      ? Colors.yellow[50]
                      : null,
                  filled: _selectedRoom != null && _numberOfPeople > _selectedRoom['capacity'],
                  enabledBorder: _selectedRoom != null && _numberOfPeople > _selectedRoom['capacity']
                      ? OutlineInputBorder(borderSide: BorderSide(color: Colors.yellow[700]!))
                      : null,
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Mohon masukkan jumlah orang';
                  }
                  final number = int.tryParse(value);
                  if (number == null || number <= 0) {
                    return 'Jumlah orang harus lebih dari 0';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    _numberOfPeople = int.tryParse(value) ?? 0;
                  });
                },
              ),
              if (_selectedRoom != null && _numberOfPeople > _selectedRoom['capacity'])
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: Colors.yellow[700]
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Jumlah orang melebihi kapasitas ruangan',
                        style: TextStyle(
                          color: Colors.yellow[700],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Durasi (Menit)',
                  border: OutlineInputBorder(),
                  suffixText: 'menit',
                ),
                initialValue: '60',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Mohon masukkan durasi';
                  }
                  final number = int.tryParse(value);
                  if (number == null || number <= 0) {
                    return 'Durasi harus lebih dari 0';
                  }
                  if (number > 1440) {  // 24 hours in minutes
                    return 'Maksimal 1440 menit (24 jam)';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    _duration = int.tryParse(value) ?? 60;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerSearchField() {
    return Stack(
      children: [
        TypeAheadFormField<Map<String, dynamic>>(
          textFieldConfiguration: TextFieldConfiguration(
            controller: _nameController,
            onTap: () {
              setState(() {
                _isFieldFocused = true;  // Add this
              });
            },
            onChanged: (value) {
              if (value.isEmpty) {
                setState(() {
                  _isCustomerSelected = false;
                  _selectedCustomer = null;
                });
              }
            },
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
            return _searchCustomers(pattern);
          },
          itemBuilder: (context, suggestion) {
            print("DEBUG: Building suggestion item: $suggestion"); // Add this debug print
            return ListTile(
              title: Text(suggestion['name'] ?? ''),
              subtitle: Text('${suggestion['address'] ?? ''} - ${suggestion['phone_number'] ?? ''}'),
            );
          },
          onSuggestionSelected: (suggestion) {
            print("DEBUG: Suggestion selected: $suggestion"); // Add this debug print
            setState(() {
              _selectedCustomer = suggestion;
              _selectedCustomerId = suggestion['id'];
              _nameController.text = suggestion['name'] ?? '';
              _addressController.text = suggestion['address'] ?? '';
              _phoneController.text = suggestion['phone_number'] ?? '';
              _searchResults = [];
              _isTyping = false;
              _isCustomerSelected = true;
              _isFieldFocused = false;  // Add this
            });
            FocusScope.of(context).unfocus();
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
                  _isFieldFocused = false;  // Add this
                });
              },
              child: Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
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

  Widget _buildPackageSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        if (_selectedPackages.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Pilih minimal satu paket',
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 12,
              ),
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
    final totalPrice = _calculateTotalPrice();
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total Harga:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _formatPrice(totalPrice),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
        ],
      ),
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
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.lightGreen, // Light green background
            foregroundColor: Colors.black, // Black text
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
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
  final String roomName;
  final int duration;
  final String roomShape;
  final String? memo;  // Add this
  final int roomPricePerHour;
  final int numberOfPeople;
  final bool isPackageBooking;

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours > 0 && remainingMinutes > 0) {
      return '$hours jam $remainingMinutes menit';
    } else if (hours > 0) {
      return '$hours jam';
    } else {
      return '$minutes menit';
    }
  }

  OrderConfirmationModal({
    required this.customerName,
    required this.duration,
    required this.restaurantName,
    required this.selectedPackages,
    required this.deliveryDateTime,
    required this.totalPrice,
    required this.onConfirm,
    required this.purpose,
    required this.onCancel,
    required this.roomName,
    required this.roomShape,
    required this.numberOfPeople,
    this.memo,
    required this.roomPricePerHour,
    required this.isPackageBooking,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.08,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Text(
                    'Konfirmasi Pesanan',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Informasi Pelanggan'),
                    _buildInfoCard([
                      _buildInfoRow('Nama', customerName),
                      _buildInfoRow('Keperluan', purpose.name),
                    ]),
                    SizedBox(height: 12),

                    _buildSectionHeader('Informasi Ruangan'),
                    _buildInfoCard([
                      _buildInfoRow('Restoran', restaurantName),
                      _buildInfoRow('Ruangan', roomName),
                      _buildInfoRow('Layout', roomShape),
                      _buildInfoRow('Kapasitas', '$numberOfPeople orang'),
                      _buildInfoRow('Durasi', _formatDuration(duration)),
                    ]),
                    SizedBox(height: 12),

                    _buildSectionHeader('Waktu Pengiriman'),
                    _buildInfoCard([
                      _buildInfoRow(
                        'Tanggal & Jam',
                        DateFormat('dd MMMM yyyy, HH:mm').format(deliveryDateTime),
                      ),
                    ]),
                    SizedBox(height: 12),

                    if (selectedPackages.isNotEmpty) ...[
                      _buildSectionHeader('Paket yang Dipesan'),
                      _buildPackageListCard(
                        selectedPackages.map((sp) => _buildPackageRow(sp)).toList(),
                      ),
                    ] else ...[
                      _buildSectionHeader('Biaya Ruangan'),
                      _buildRoomPriceCard(roomPricePerHour, duration),  // Pass parameters directly
                    ],

                    SizedBox(height: 12),

                    if (memo != null && memo!.isNotEmpty) ...[
                      _buildSectionHeader('Memo'),
                      _buildMemoCard(memo!),
                      SizedBox(height: 12),
                    ],

                    _buildTotalPriceCard(totalPrice),
                  ],
                ),
              ),
            ),

            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: onCancel,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Batal', style: TextStyle(color: Colors.black54)),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Konfirmasi', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomPriceCard(int pricePerHour, int duration) {
    final hours = duration / 60;
    final totalPrice = (pricePerHour * hours).round();

    return Container(
      width: double.infinity,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Harga per jam',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      )),
                  Text(_formatPrice(pricePerHour),
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      )),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total ($hours jam)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      )),
                  Text(_formatPrice(totalPrice),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.blue[800],
                      )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      child: Card(
        margin: EdgeInsets.zero,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          child: Column(
            children: List.generate(children.length * 2 - 1, (index) {
              if (index.isOdd) {
                return Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Colors.grey[300],
                );
              }
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: children[index ~/ 2],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildPackageListCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      child: Card(
        margin: EdgeInsets.zero,
        child: Container(
          width: double.infinity,
          child: Column(
            children: List.generate(children.length * 2 - 1, (index) {
              if (index.isOdd) {
                return Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Colors.grey[300],
                );
              }
              return children[index ~/ 2];
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildMemoCard(String memoText) {
    return Container( // Add this container
      width: double.infinity,
      child: Card(
        margin: EdgeInsets.zero,
        child: ExpansionTile(
          title: Text('Lihat Memo',
            style: TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          children: [
            Container( // Add this container
              width: double.infinity,
              padding: EdgeInsets.all(12),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                padding: EdgeInsets.all(8),
                child: Text(memoText, style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildTotalPriceCard(int totalPrice) {
    return Container( // Add this container
      width: double.infinity,
      child: Card(
        margin: EdgeInsets.zero,
        color: Colors.green[50],
        child: Container( // Add this container
          width: double.infinity,
          padding: EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Harga',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  )),
              Text(_formatPrice(totalPrice),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.green[800],
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(title,
        style: TextStyle(
          fontSize: 15, // Smaller font
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100, // Fixed width for labels to align them
          child: Text(label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                fontSize: 13,
              )),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              )),
        ),
      ],
    );
  }

  Widget _buildPackageRow(SelectedPackage sp) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Increased horizontal padding
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3, // Increased flex for more space
            child: Text(sp.package.name,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13, // Smaller font
                )),
          ),
          SizedBox(width: 12), // Increased spacing
          Text('${sp.quantity}x',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                fontSize: 13, // Smaller font
              )),
          SizedBox(width: 20), // Increased spacing
          Text(_formatPrice(sp.package.priceInCents * sp.quantity),
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13, // Smaller font
              )),
        ],
      ),
    );
  }

  String _formatPrice(dynamic price) {
    // Convert to int if it's a double
    final priceAsInt = price is double ? price.toInt() : price as int;

    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(priceAsInt);
  }
}

class MeetingRoom {
  final String id;
  final String name;
  final int capacity;
  List<RoomShape> supportedLayouts = [];

  MeetingRoom({required this.id, required this.name, required this.capacity});

  factory MeetingRoom.fromJson(Map<String, dynamic> json) {
    return MeetingRoom(
      id: json['id'],
      name: json['room_name'],
      capacity: json['capacity'],
    );
  }
}

class Restaurant {
  final String id;
  final String name;

  Restaurant({required this.id, required this.name});

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] as String? ?? '',
      name: json['restaurant_name'] as String? ?? '',
    );
  }
}

class RestaurantDropdown extends StatefulWidget {
  final List<Restaurant> availableRestaurants;
  final Restaurant? selectedRestaurant;
  final Function(Restaurant?) onChanged;
  final Function(RoomShape?) onLayoutSelected;
  final bool isLoading;
  final Function(DateTime?) onDateTimeChanged;
  final Function(dynamic) onRoomSelected;
  final Function() showMemoModal;
  final String memo;

  RestaurantDropdown({
    required this.availableRestaurants,
    this.selectedRestaurant,
    required this.onChanged,
    required this.isLoading,
    required this.onDateTimeChanged,
    required this.onRoomSelected,
    required this.onLayoutSelected,
    required this.showMemoModal,
    required this.memo,
  });

  @override
  _RestaurantDropdownState createState() => _RestaurantDropdownState();
}

class _RestaurantDropdownState extends State<RestaurantDropdown> {
  DateTime? selectedDateTime;
  List<dynamic> rooms = [];
  bool isLoadingRooms = false;
  String? selectedRoomId;
  RoomShape? selectedLayout;
  List<RoomShape> availableLayouts = [];

  int _parsePrice(dynamic price) {
    if (price == null) {
      print("Price is null");
      return 0;
    }

    try {
      if (price is int) {
        return price;
      } else if (price is double) {
        return price.toInt();
      } else if (price is String) {
        // Remove any non-numeric characters except decimal point
        final cleanedPrice = price.replaceAll(RegExp(r'[^0-9.]'), '');
        if (cleanedPrice.isEmpty) {
          print("Cleaned price string is empty");
          return 0;
        }
        if (cleanedPrice.contains('.')) {
          return double.parse(cleanedPrice).toInt();
        }
        return int.parse(cleanedPrice);
      } else {
        print("Unexpected price type: ${price.runtimeType}");
        return 0;
      }
    } catch (e) {
      print("Error parsing price '$price': $e");
      return 0;
    }
  }

  Widget _buildRoomItem(dynamic room) {
    final bool hasOrders = room['orders'] != null && room['orders'].isNotEmpty;
    final bool isSelected = selectedRoomId == room['id'];
    final List<dynamic> supportedLayouts = room['supported_layouts'] ?? [];
    final int pricePerHour = _parsePrice(room['price_per_hour']);

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      margin: EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          // Main Room Info Row
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Room Info Column (Name, Price, Capacity)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Room Name
                      Text(
                        room['room_name'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      // Price
                      Text(
                        NumberFormat.currency(
                          locale: 'id_ID',
                          symbol: 'Rp ',
                          decimalDigits: 0,
                        ).format(pricePerHour),
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 2),
                      // Capacity
                      Text(
                        'Kapasitas: ${room['capacity']} orang',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Buttons Column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Status Button
                    ElevatedButton(
                      onPressed: () => _showAvailability(context, room),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasOrders ? Colors.yellow : Colors.green,
                        foregroundColor: hasOrders ? Colors.black : Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        hasOrders ? 'Check' : 'Available',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    SizedBox(height: 8),
                    // Select Button
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          selectedRoomId = room['id'];
                          selectedLayout = null;
                          availableLayouts = supportedLayouts
                              .map((layout) => RoomShape.fromJson(layout))
                              .toList();
                        });
                        widget.onRoomSelected(room);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected ? Colors.blue : Colors.white,
                        foregroundColor: isSelected ? Colors.white : Colors.black,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        elevation: 0,
                        side: BorderSide(
                          color: isSelected ? Colors.blue : Colors.grey[300]!,
                        ),
                      ),
                      child: Text(
                        'Select',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Layout Selection (when room is selected)
          if (isSelected) ...[
            Divider(height: 1),
            if (supportedLayouts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: _buildLayoutDropdown(supportedLayouts),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildLayoutDropdown(List<dynamic> supportedLayouts) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: DropdownButtonFormField<RoomShape>(
        value: selectedLayout,
        items: supportedLayouts.map((layout) => DropdownMenuItem<RoomShape>(
          value: RoomShape.fromJson(layout),
          child: Text(layout['shape_name']),
        )).toList(),
        onChanged: (RoomShape? newValue) {
          setState(() {
            selectedLayout = newValue;
          });
          widget.onLayoutSelected(newValue);
        },
        decoration: InputDecoration(
          labelText: 'Room Layout',
          border: OutlineInputBorder(),
        ),
        validator: (value) => value == null ? 'Please select a layout' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            DropdownButtonFormField<Restaurant>(
              value: widget.selectedRestaurant,
              items: widget.availableRestaurants.isEmpty
                  ? []
                  : widget.availableRestaurants.map((restaurant) => DropdownMenuItem<Restaurant>(
                value: restaurant,
                child: Text(restaurant.name),
              )).toList(),
              onChanged: (Restaurant? newValue) {
                widget.onChanged(newValue);
                setState(() {
                  rooms = [];
                });
                if (newValue != null && selectedDateTime != null) {
                  _fetchRoomDetails(newValue.id);
                }
              },
              hint: Text(
                  widget.isLoading
                      ? 'Memuat restoran...'
                      : widget.availableRestaurants.isEmpty
                      ? 'Tidak ada restoran terdaftar'
                      : 'Pilih restoran'
              ),
              isExpanded: true,
              decoration: InputDecoration(
                enabled: !widget.isLoading && widget.availableRestaurants.isNotEmpty,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: (value) => value == null ? 'Mohon pilih restoran' : null,
            ),
            if (widget.isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black12,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _selectDateTime(context),
                child: Text(selectedDateTime != null
                    ? DateFormat('dd/MM/yyyy HH:mm').format(selectedDateTime!)
                    : 'Pilih Tanggal dan Waktu'),
              ),
            ),
            SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => widget.showMemoModal(),
              icon: Icon(Icons.note_add),
              label: Text('Memo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.memo.isNotEmpty ? Colors.green : Colors.grey,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        if (selectedDateTime != null && widget.selectedRestaurant != null)
          isLoadingRooms
              ? CircularProgressIndicator()
              : ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: rooms.length,
            itemBuilder: (context, index) => _buildRoomItem(rooms[index]),
          ),
      ],
    );
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: selectedDateTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (date != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(selectedDateTime ?? DateTime.now()),
      );
      if (time != null) {
        setState(() {
          selectedDateTime = DateTime(
              date.year, date.month, date.day, time.hour, time.minute
          );
        });
        widget.onDateTimeChanged(selectedDateTime);
        if (widget.selectedRestaurant != null) {
          _fetchRoomDetails(widget.selectedRestaurant!.id);
        }
      }
    }
  }

  Future<void> _fetchRoomDetails(String restaurantId) async {
    setState(() {
      isLoadingRooms = true;
    });
    try {
      final url = '${Env.apiUrl}/api/restaurants/$restaurantId/room-details?date=${selectedDateTime!.toIso8601String()}';
      print("DEBUG: Fetching room details from: $url");

      final response = await http.get(Uri.parse(url));
      print("DEBUG: Room details response status: ${response.statusCode}");
      print("DEBUG: Raw response: ${response.body}");

      if (response.statusCode == 200) {
        final List<dynamic> roomsData = json.decode(response.body);

        // Add debug prints for room prices
        roomsData.forEach((room) {
          print("DEBUG: Room ${room['room_name']} raw price: ${room['price_per_hour']}");
        });

        setState(() {
          rooms = roomsData;
          isLoadingRooms = false;
        });
      } else {
        throw Exception('Failed to load room details');
      }
    } catch (e) {
      print('Error fetching room details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load room details. Please try again.')),
      );
      setState(() {
        isLoadingRooms = false;
      });
    }
  }

  void _showAvailability(BuildContext context, dynamic room) {
    final bool hasOrders = room['orders'] != null && room['orders'].isNotEmpty;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Ketersediaan Ruangan: ${room['room_name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasOrders) ...[
                Text('Pesanan yang ada:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                ...room['orders'].map<Widget>((order) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pelanggan: ${order['customer_name']}'),
                        Text('Keperluan: ${order['order_purpose']}'),
                        Text('Waktu: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(order['delivery_datetime']))}'),
                        Text('Jumlah Orang: ${order['number_of_people']}'),
                        Divider(),
                      ],
                    ),
                  );
                }).toList(),
              ] else
                Text('Tidak ada booking pada ruangan ${room['room_name']} pada hari ${DateFormat('dd/MM/yyyy').format(selectedDateTime!)}'),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Tutup'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class RoomShape {
  final String id;
  final String shapeName;

  RoomShape({required this.id, required this.shapeName});

  factory RoomShape.fromJson(Map<String, dynamic> json) {
    return RoomShape(
      id: json['id'] as String,
      shapeName: json['shape_name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shape_name': shapeName,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is RoomShape &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              shapeName == other.shapeName;

  @override
  int get hashCode => id.hashCode ^ shapeName.hashCode;
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