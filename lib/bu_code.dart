import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:salescroll/widgets/network_error_handler.dart';
import 'dart:convert';
import 'widgets/burger_menu.dart';
import 'widgets/loading_overlay.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:salescroll/services/env.dart';

class CheckOrderEdit extends StatefulWidget {
  final Map<String, dynamic> orderData;

  CheckOrderEdit({required this.orderData});

  @override
  _CheckOrderEditState createState() => _CheckOrderEditState();
}

class _CheckOrderEditState extends State<CheckOrderEdit> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _numberOfPeopleController = TextEditingController();
  final _durationController = TextEditingController();
  Future<List<OrderPurpose>>? _purposesFuture;
  bool _isPurposesLoading = false;
  Map<String, Future<List<RoomShape>>> _layoutCache = {};
  Map<String, List<RoomShape>> _layoutResults = {};

  String _memo = '';
  String? _selectedCustomerId;
  String? _selectedRestaurantId;
  dynamic _selectedRoom;
  List<Restaurant> _availableRestaurants = [];
  List<Package> _availablePackages = [];
  List<SelectedPackage> _selectedPackages = [];
  List<OrderPurpose> _purposeOptions = [];
  Map<String, dynamic>? _selectedCustomer;
  Restaurant? _selectedRestaurant;
  Package? _selectedPackage;
  DateTime? _deliveryDateTime;
  OrderPurpose? _selectedPurpose;
  RoomShape? _selectedLayout;

  bool _isPackagesLoading = false;
  bool _isSubmitting = false;

  int _numberOfPeople = 0;
  int _duration = 60;

  @override
  void initState() {
    super.initState();
    _numberOfPeopleController.text = widget.orderData['number_of_people']?.toString() ?? '0';
    _durationController.text = widget.orderData['duration_minutes']?.toString() ?? '60';

    // Initialize selected purpose from order data first
    if (widget.orderData['id_order_purpose'] != null) {
      _selectedPurpose = OrderPurpose(
        id: int.tryParse(widget.orderData['id_order_purpose'].toString()) ?? 0,
        name: widget.orderData['purpose']?.toString() ?? '',
        nameEn: widget.orderData['purpose']?.toString() ?? '',
      );
    }

    // Start loading purposes
    _purposesFuture = _fetchPurposes();

    _initializeDataAndSetup();
  }

  Future<void> _initializeDataAndSetup() async {
    await _initializeData();
  }

  Future<void> _initializeData() async {
    print('DEBUG: Starting _initializeData');
    print('DEBUG: Full order data: ${widget.orderData}');

    // Initialize customer data
    _selectedCustomerId = widget.orderData['id_customer']?.toString();
    _nameController.text = widget.orderData['customer_name']?.toString() ?? '';
    _phoneController.text = widget.orderData['customer_phone']?.toString() ?? '';
    _addressController.text = widget.orderData['address']?.toString() ?? '';

    // Restaurant initialization
    _selectedRestaurantId = widget.orderData['restaurant_id']?.toString();
    print('DEBUG: Selected restaurant ID: $_selectedRestaurantId');

    _selectedRestaurant = Restaurant(
        id: widget.orderData['restaurant_id']?.toString() ?? '',
        name: widget.orderData['restaurant_name']?.toString() ?? '',
        meetingRooms: [
          MeetingRoom(
              id: widget.orderData['meeting_room_id']?.toString() ?? '',
              name: widget.orderData['room_name']?.toString() ?? '',
              capacity: int.tryParse(widget.orderData['number_of_people']?.toString() ?? '0') ?? 0,
              supportedLayouts: [
                RoomShape(
                  id: widget.orderData['id_room_shape']?.toString() ?? '',
                  shapeName: widget.orderData['room_layout']?.toString() ?? '',
                )
              ]
          )
        ]
    );

    _availableRestaurants = [_selectedRestaurant!];

    // Initialize delivery datetime
    if (widget.orderData['delivery_datetime'] != null) {
      _deliveryDateTime = DateTime.parse(widget.orderData['delivery_datetime']);
      print('DEBUG: Delivery datetime initialized: $_deliveryDateTime');
    }

    // Fetch and initialize packages
    if (_selectedRestaurantId != null) {
      print('DEBUG: Fetching packages for restaurant: $_selectedRestaurantId');
      await _fetchPackagesForRestaurant(_selectedRestaurantId!);
      print('DEBUG: Available packages count: ${_availablePackages.length}');
    }

    // Initialize selected packages
    _selectedPackages.clear(); // Clear any existing packages
    if (widget.orderData['package_details'] != null &&
        widget.orderData['package_details'].toString().isNotEmpty) {
      try {
        print('DEBUG: Raw package_details: ${widget.orderData['package_details']}');

        final packageLines = widget.orderData['package_details'].toString().split('\n');
        print('DEBUG: Package lines found: ${packageLines.length}');

        for (var line in packageLines) {
          print('DEBUG: Processing package line: $line');
          var match = RegExp(r'(.*?) x(\d+)').firstMatch(line);
          if (match != null) {
            final packageName = match.group(1)?.trim() ?? '';
            final quantity = int.tryParse(match.group(2) ?? '0') ?? 0;

            print('DEBUG: Extracted - Name: $packageName, Quantity: $quantity');

            // Find matching package from available packages
            final matchingPackage = _availablePackages.firstWhere(
                    (p) => p.name == packageName,
                orElse: () {
                  print('DEBUG: No matching package found for: $packageName');
                  return Package(
                      id: 'temp_id_${DateTime.now().millisecondsSinceEpoch}_$packageName',
                      name: packageName,
                      description: '',
                      priceInCents: 0
                  );
                }
            );

            _selectedPackages.add(SelectedPackage(
                package: matchingPackage,
                quantity: quantity,
                uniqueId: 'init_${DateTime.now().millisecondsSinceEpoch}_$packageName'
            ));

            print('DEBUG: Added package to selection: ${matchingPackage.name} (${matchingPackage.id}) x$quantity');
          }
        }

        print('DEBUG: Final selected packages: ${_selectedPackages.map((sp) =>
        '${sp.package.name} (${sp.package.id}) x${sp.quantity}').toList()}');
      } catch (e, stackTrace) {
        print('Error initializing packages: $e');
        print('Stack trace: $stackTrace');
      }
    } else {
      print('DEBUG: No package details found in order data');
    }

    // Room initialization
    if (widget.orderData['meeting_room_id'] != null) {
      _selectedRoom = {
        'id': widget.orderData['meeting_room_id']?.toString() ?? '',
        'room_name': widget.orderData['room_name']?.toString() ?? '',
        'capacity': int.tryParse(widget.orderData['number_of_people']?.toString() ?? '0') ?? 0,
      };
      print('DEBUG: Selected room initialized: ${_selectedRoom['room_name']}');
    }

    // Layout initialization
    if (widget.orderData['id_room_shape'] != null) {
      _selectedLayout = RoomShape(
        id: widget.orderData['id_room_shape']?.toString() ?? '',
        shapeName: widget.orderData['room_layout']?.toString() ?? '',
      );
      print('DEBUG: Selected layout initialized: ${_selectedLayout?.shapeName}');
    }

    // Purpose initialization
    if (widget.orderData['id_order_purpose'] != null) {
      _selectedPurpose = OrderPurpose(
        id: int.tryParse(widget.orderData['id_order_purpose'].toString()) ?? 0,
        name: widget.orderData['purpose']?.toString() ?? '',
        nameEn: widget.orderData['purpose']?.toString() ?? '',
      );
      _purposeOptions = [_selectedPurpose!];
      print('DEBUG: Selected purpose initialized: ${_selectedPurpose?.name}');
    }

    // Other fields
    _numberOfPeople = int.tryParse(widget.orderData['number_of_people']?.toString() ?? '0') ?? 0;
    _duration = int.tryParse(widget.orderData['duration_minutes']?.toString() ?? '60') ?? 60;
    _memo = widget.orderData['memo']?.toString() ?? '';

    print('DEBUG: Initialization complete');
    print('DEBUG: Number of people: $_numberOfPeople');
    print('DEBUG: Duration: $_duration minutes');
    print('DEBUG: Selected packages count: ${_selectedPackages.length}');

    setState(() {}); // Trigger UI update
  }

  Map<String, dynamic> _getChangedFields() {
    final changes = <String, dynamic>{};

    // Add at the beginning
    print('\nDEBUG: Starting _getChangedFields');
    final currentIsRoomOnly = _selectedPackages.isEmpty;
    final originalIsRoomOnly = widget.orderData['is_room_only'] == 1 || widget.orderData['is_room_only'] == true;

    print('DEBUG: Original is_room_only: ${widget.orderData['is_room_only']}');
    print('DEBUG: Current is_room_only: $currentIsRoomOnly');
    print('DEBUG: Current selected packages: ${_selectedPackages.length}');
    print('DEBUG: Original package details: ${widget.orderData['package_details']}');

    // Add is_room_only comparison
    if (originalIsRoomOnly != currentIsRoomOnly) {
      changes['Room Only Status'] = {
        'from': originalIsRoomOnly ? 'Room Only' : 'With Packages',
        'to': currentIsRoomOnly ? 'Room Only' : 'With Packages'
      };
      print('DEBUG: Room only status change detected: $originalIsRoomOnly -> $currentIsRoomOnly');
    }

    // Compare customer details
    if (widget.orderData['customer_name'] != _nameController.text) {
      changes['Customer Name'] = {
        'from': widget.orderData['customer_name'],
        'to': _nameController.text
      };
    }

    if (widget.orderData['customer_phone'] != _phoneController.text) {
      changes['Phone Number'] = {
        'from': widget.orderData['customer_phone'],
        'to': _phoneController.text
      };
    }

    if (widget.orderData['address'] != _addressController.text) {
      changes['Address'] = {
        'from': widget.orderData['address'],
        'to': _addressController.text
      };
    }

    // Compare restaurant
    if (widget.orderData['restaurant_name'] != _selectedRestaurant?.name) {
      changes['Restaurant'] = {
        'from': widget.orderData['restaurant_name'],
        'to': _selectedRestaurant?.name
      };
    }

    // Compare room
    if (widget.orderData['room_name'] != _selectedRoom?['room_name']) {
      changes['Room'] = {
        'from': widget.orderData['room_name'],
        'to': _selectedRoom?['room_name']
      };
    }

    // Compare layout
    if (widget.orderData['room_layout'] != _selectedLayout?.shapeName) {
      changes['Room Layout'] = {
        'from': widget.orderData['room_layout'],
        'to': _selectedLayout?.shapeName
      };
    }

    // Compare number of people
    if (int.parse(widget.orderData['number_of_people'].toString()) != _numberOfPeople) {
      changes['Number of People'] = {
        'from': widget.orderData['number_of_people'].toString(),
        'to': _numberOfPeople.toString()
      };
    }

    // Compare duration
    if (int.parse(widget.orderData['duration_minutes'].toString()) != _duration) {
      changes['Duration'] = {
        'from': '${widget.orderData['duration_minutes']} minutes',
        'to': '$_duration minutes'
      };
    }

    // Compare purpose
    if (widget.orderData['purpose'] != _selectedPurpose?.name) {
      changes['Purpose'] = {
        'from': widget.orderData['purpose'],
        'to': _selectedPurpose?.name
      };
    }

    // Compare datetime
    final originalDateTime = DateTime.parse(widget.orderData['delivery_datetime']);
    if (originalDateTime != _deliveryDateTime) {
      changes['Delivery Date/Time'] = {
        'from': DateFormat('dd/MM/yyyy HH:mm').format(originalDateTime),
        'to': DateFormat('dd/MM/yyyy HH:mm').format(_deliveryDateTime!)
      };
    }

    // Compare memo
    if (widget.orderData['memo'] != _memo) {
      changes['Memo'] = {
        'from': widget.orderData['memo'] ?? 'No memo',
        'to': _memo.isEmpty ? 'No memo' : _memo
      };
    }

    if (_selectedPackages.isNotEmpty || widget.orderData['package_details'] != null) {
      final originalPackageLines = widget.orderData['package_details']?.toString().split('\n') ?? [];
      final currentPackageLines = _selectedPackages.map((sp) =>
      '${sp.package.name} x${sp.quantity}'
      ).join('\n');

      print('DEBUG: Package Comparison:');
      print('DEBUG: Original packages: $originalPackageLines');
      print('DEBUG: Current packages: $currentPackageLines');

      if (originalPackageLines.join('\n') != currentPackageLines || originalIsRoomOnly != currentIsRoomOnly) {
        changes['Packages'] = {
          'from': widget.orderData['package_details'] ?? 'No packages',
          'to': currentPackageLines.isEmpty ? 'No packages' : currentPackageLines
        };
        print('DEBUG: Package changes detected and added to changes map');
      }

      // Calculate original total price directly from widget.orderData
      final originalTotalPrice = int.tryParse(widget.orderData['total_price']?.toString() ?? '0') ?? 0;
      final newTotalPrice = _calculateTotalPrice();

      if (originalTotalPrice != newTotalPrice) {
        changes['Total Price'] = {
          'from': _formatPrice(originalTotalPrice),
          'to': _formatPrice(newTotalPrice)
        };
      }
    }
    print('DEBUG: Final changes detected: ${changes.keys.toList()}');
    return changes;
  }

  // Modify _updateOrder() to show confirmation first
  void _updateOrder() async {
    if (!_validateOrder()) return;

    final changes = _getChangedFields();

    if (changes.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('No Changes'),
          content: Text('No changes were made to the order.'),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Changes'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('The following changes will be made:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              ...changes.entries.map((entry) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.key,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('From: ${entry.value['from']}',
                    style: TextStyle(color: Colors.red),
                  ),
                  Text('To: ${entry.value['to']}',
                    style: TextStyle(color: Colors.green),
                  ),
                  Divider(),
                ],
              )).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text('Confirm Update'),
            onPressed: () {
              Navigator.pop(context);
              _processUpdate();
            },
          ),
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

  int _calculateTotalPrice() {
    return _selectedPackages.fold(0, (total, selectedPackage) =>
    total + (selectedPackage.package.priceInCents * selectedPackage.quantity));
  }

  bool _isValidPhoneNumber(String phone) {
    // Basic phone number validation for Indonesia
    final phoneRegex = RegExp(r'^(\+62|62|0)[2-9][0-9]{7,11}$');
    return phoneRegex.hasMatch(phone);
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
    );
    return emailRegex.hasMatch(email);
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (value.length > 50) {
      return 'Name must not exceed 50 characters';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    if (!_isValidPhoneNumber(value)) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  bool _validateOrder() {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return false;
    }

    if (_deliveryDateTime == null) {
      showTopSnackBar('Please select date and time');
      return false;
    }

    if (_selectedPurpose == null) {
      showTopSnackBar('Please select a purpose');
      return false;
    }

    if (_selectedRoom == null) {
      showTopSnackBar('Please select a room');
      return false;
    }

    if (_selectedLayout == null) {
      showTopSnackBar('Please select a room layout');
      return false;
    }

    // Validate number of people against room capacity
    if (_selectedRoom != null) {
      final roomCapacity = _selectedRoom['capacity'] as int;
      if (_numberOfPeople > roomCapacity) {
        showTopSnackBar('Number of people exceeds room capacity of $roomCapacity');
        return false;
      }
    }

    // Changed validation logic to handle both room-only and package bookings
    final isRoomOnly = _selectedPackages.isEmpty;
    if (!isRoomOnly) {
      // Only validate packages if not room-only
      if (_selectedPackages.isEmpty) {
        showTopSnackBar('Please select at least one package');
        return false;
      }

      // Validate package quantities
      final invalidPackage = _selectedPackages.firstWhere(
            (sp) => sp.quantity <= 0 || sp.quantity > 100,
        orElse: () => SelectedPackage(
            package: Package(id: '', name: '', description: '', priceInCents: 0),
            quantity: 1
        ),
      );

      if (invalidPackage.package.id.isNotEmpty) {
        showTopSnackBar('Invalid quantity for package ${invalidPackage.package.name}');
        return false;
      }
    }

    return true;
  }

  void _processUpdate() async {
    setState(() => _isSubmitting = true);

    print('\nDEBUG: Starting order update process');
    print('DEBUG: Original order details:');
    print('- Is room only: ${widget.orderData['is_room_only']}');
    print('- Package details: ${widget.orderData['package_details']}');
    print('- Original total price: ${widget.orderData['total_price']}');

    final isRoomOnly = _selectedPackages.isEmpty;  // Define once here
    print('\nDEBUG: Current update details:');
    print('- Is room only: $isRoomOnly');
    print('- Selected packages count: ${_selectedPackages.length}');
    print('- Room details: ${_selectedRoom.toString()}');
    print('- Duration: $_duration minutes');

    final User? user = FirebaseAuth.instance.currentUser;
    if (user?.uid == null) {
      showTopSnackBar('User not logged in');
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      final formattedDateTime = DateFormat('yyyy-MM-dd HH:mm:ss')
          .format(_deliveryDateTime!.toLocal());

      // Log package details if any
      if (_selectedPackages.isNotEmpty) {
        print('- Selected packages:');
        _selectedPackages.forEach((sp) =>
            print('  * ${sp.package.name} x${sp.quantity}')
        );
      }

      final orderData = {
        'id_customer': _selectedCustomerId,
        'id_restaurant': _selectedRestaurantId,
        'id_room_shape': _selectedLayout!.id,
        'meeting_room_id': _selectedRoom['id'],
        'number_of_people': _numberOfPeople,
        'id_order_purpose': _selectedPurpose!.id,
        'delivery_datetime': formattedDateTime,
        'memo': _memo,
        'duration_minutes': _duration,
        'is_room_only': isRoomOnly,  // Use the variable defined above
        'order_items': _selectedPackages.map((sp) => {
          'id_package': sp.package.id,
          'quantity': sp.quantity,
          'price_per_item': sp.package.priceInCents
        }).toList(),
        'firebase_uid': user!.uid,
      };

      print('DEBUG: Sending update with order data: ${json.encode(orderData)}');

      final response = await http.put(
        Uri.parse('${Env.apiUrl}/api/orders/${widget.orderData['order_id']}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(orderData),
      );

      print('\nDEBUG: Update response:');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      setState(() => _isSubmitting = false);

      if (response.statusCode == 200) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Success'),
            content: Text('Order has been updated successfully.'),
            actions: [
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pop(context, true);
                },
              ),
            ],
          ),
        );
      } else {
        throw Exception('Failed to update order: ${response.body}');
      }
    } catch (e) {
      print('DEBUG: Error in _processUpdate: $e');
      print('DEBUG: Stack trace: ${StackTrace.current}');
      setState(() => _isSubmitting = false);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Error'),
          content: Text('Failed to update order: $e'),
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

  Future<List<OrderPurpose>> _fetchPurposes() async {
    try {
      final response = await http.get(Uri.parse('${Env.apiUrl}/api/order-purposes'));

      if (response.statusCode == 200) {
        final List<dynamic> purposesJson = json.decode(response.body);
        final purposes = purposesJson.map((json) => OrderPurpose.fromJson(json)).toList();

        // If we have a selected purpose, find the matching one from fetched purposes
        if (_selectedPurpose != null) {
          final matchingPurpose = purposes.firstWhere(
                (p) => p.id == _selectedPurpose!.id,
            orElse: () => purposes.first,
          );
          // Update the selected purpose reference to use the one from the fetched list
          setState(() {
            _selectedPurpose = matchingPurpose;
          });
        }

        return purposes;
      } else {
        throw Exception('Failed to load purposes');
      }
    } catch (e) {
      print('Error fetching purposes: $e');
      // If we have a selected purpose, return it as a single-item list
      if (_selectedPurpose != null) {
        return [_selectedPurpose!];
      }
      return [];
    } finally {
      setState(() => _isPurposesLoading = false);
    }
  }

  Future<void> _fetchPackagesForRestaurant(String restaurantId) async {
    setState(() => _isPackagesLoading = true);

    try {
      final response = await http.get(
        Uri.parse('${Env.apiUrl}/api/restaurants/$restaurantId/packages'),
      );

      print('DEBUG: Package fetch response: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> packagesJson = json.decode(response.body);
        setState(() {
          _availablePackages = packagesJson
              .map((json) => Package.fromJson(json))
              .toList();
          _isPackagesLoading = false;
        });
        print('DEBUG: Fetched ${_availablePackages.length} packages');
        print('DEBUG: Package details: ${_availablePackages.map((p) => '${p.name}: ${p.priceInCents}').toList()}');
      }
    } catch (e) {
      print('Error fetching packages: $e');
      print('Stack trace: ${StackTrace.current}');
      NetworkErrorNotifier.instance.notifyError();
      setState(() => _isPackagesLoading = false);
    }
  }

  void showTopSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 100,
          left: 10,
          right: 10,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NetworkErrorHandler(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Edit Order'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: LoadingOverlay(
          isLoading: _isSubmitting,
          loadingText: "Updating order...",
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCustomerDetails(),
                  SizedBox(height: 20),
                  _buildPurposeDropdown(),
                  SizedBox(height: 20),
                  _buildRestaurantDropdown(),
                  SizedBox(height: 20),
                  _buildDurationAndPeopleFields(),
                  SizedBox(height: 20),
                  _buildPackageSelection(),
                  SizedBox(height: 20),
                  _buildSelectedPackages(),
                  SizedBox(height: 20),
                  _buildTotalPrice(),
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

  Widget _buildCustomerDetails() {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          enabled: false,
          decoration: InputDecoration(
            labelText: 'Customer Name',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.grey[200],
          ),
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _addressController,
          enabled: false,
          decoration: InputDecoration(
            labelText: 'Address',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.grey[200],
          ),
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          enabled: false,
          decoration: InputDecoration(
            labelText: 'Phone Number',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.grey[200],
          ),
        ),
      ],
    );
  }

  Widget _buildPurposeDropdown() {
    return FutureBuilder<List<OrderPurpose>>(
      future: _purposesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || _isPurposesLoading) {
          return Stack(
            children: [
              DropdownButtonFormField<OrderPurpose>(
                value: _selectedPurpose,
                items: _selectedPurpose != null ? [
                  DropdownMenuItem<OrderPurpose>(
                    value: _selectedPurpose,
                    child: Text(_selectedPurpose!.name),
                  )
                ] : [],
                onChanged: null,
                decoration: InputDecoration(
                  labelText: 'Purpose',
                  border: OutlineInputBorder(),
                ),
              ),
              Positioned.fill(
                child: Container(
                  color: Colors.black12,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return DropdownButtonFormField<OrderPurpose>(
            value: _selectedPurpose,
            items: _selectedPurpose != null ? [
              DropdownMenuItem<OrderPurpose>(
                value: _selectedPurpose,
                child: Text(_selectedPurpose!.name),
              )
            ] : [],
            onChanged: (OrderPurpose? newValue) {
              setState(() => _selectedPurpose = newValue);
            },
            decoration: InputDecoration(
              labelText: 'Purpose',
              border: OutlineInputBorder(),
              errorText: 'Error loading purposes',
            ),
          );
        }

        final purposes = snapshot.data ?? [];
        if (purposes.isEmpty) {
          return DropdownButtonFormField<OrderPurpose>(
            value: null,
            items: [],
            onChanged: null,
            decoration: InputDecoration(
              labelText: 'Purpose',
              border: OutlineInputBorder(),
              errorText: 'No purposes available',
            ),
          );
        }

        return DropdownButtonFormField<OrderPurpose>(
          value: _selectedPurpose,
          items: purposes.map((purpose) => DropdownMenuItem<OrderPurpose>(
            value: purpose,
            child: Text(purpose.name),
          )).toList(),
          onChanged: (OrderPurpose? newValue) {
            setState(() => _selectedPurpose = newValue);
          },
          decoration: InputDecoration(
            labelText: 'Purpose',
            border: OutlineInputBorder(),
          ),
          validator: (value) => value == null ? 'Please select a purpose' : null,
        );
      },
    );
  }

  Widget _buildRestaurantDropdown() {
    return Column(
      children: [
        TextFormField(
          initialValue: _selectedRestaurant?.name ?? '',
          decoration: InputDecoration(
            labelText: 'Restaurant',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.grey[200],
          ),
          enabled: false, // Disable the field
        ),
        SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => _selectDateTime(context),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: Text(_deliveryDateTime != null
              ? DateFormat('dd/MM/yyyy HH:mm').format(_deliveryDateTime!)
              : 'Select Date and Time'),
        ),
        if (_selectedRestaurant != null)
          _buildRoomSelection(),
      ],
    );
  }

  Widget _buildRoomSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 16),
        Text('Available Rooms:', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        FutureBuilder(
          future: _roomDetailsFuture ??= _fetchRoomDetails(_selectedRestaurant!.id),
          builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData) {
              return Text('No rooms available');
            }

            return Column(
              children: [
                ...snapshot.data!.map((room) => Card(
                  margin: EdgeInsets.only(bottom: 8),
                  color: _selectedRoom?['id'] == room['id'] ? Colors.blue[50] : Colors.white,
                  child: ListTile(
                    title: Text(room['room_name']),
                    subtitle: Text('Capacity: ${room['capacity']} people'),
                    selected: _selectedRoom?['id'] == room['id'],
                    tileColor: _selectedRoom?['id'] == room['id'] ? Colors.blue[50] : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: _selectedRoom?['id'] == room['id'] ? Colors.blue : Colors.grey[300]!,
                        width: _selectedRoom?['id'] == room['id'] ? 2 : 1,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedRoom = {
                          'id': room['id'],
                          'room_name': room['room_name'],
                          'capacity': room['capacity'],
                        };
                        _selectedLayout = null;
                      });
                      // Layouts will be fetched from cache if available
                      setState(() {}); // Trigger rebuild for layout dropdown
                    },
                  ),
                )).toList(),
                if (_selectedRoom != null) ...[
                  SizedBox(height: 16),
                  FutureBuilder<List<RoomShape>>(
                    future: _fetchSupportedLayouts(_selectedRoom!['id']),
                    builder: (context, AsyncSnapshot<List<RoomShape>> snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !_layoutResults.containsKey(_selectedRoom!['id'])) {
                        return Center(child: CircularProgressIndicator());
                      }

                      final layouts = snapshot.data ?? _layoutResults[_selectedRoom!['id']] ?? [];

                      return DropdownButtonFormField<RoomShape>(
                        value: _selectedLayout,
                        items: layouts.map((layout) => DropdownMenuItem<RoomShape>(
                          value: layout,
                          child: Text(layout.shapeName),
                        )).toList(),
                        onChanged: (RoomShape? newValue) {
                          setState(() {
                            _selectedLayout = newValue;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Room Layout',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value == null ? 'Please select a layout' : null,
                      );
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildDurationAndPeopleFields() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _numberOfPeopleController,
            decoration: InputDecoration(
              labelText: 'Number of People',
              border: OutlineInputBorder(),
              suffixText: _selectedRoom != null
                  ? 'Capacity: ${_selectedRoom['capacity']}'
                  : null,
              helperText: 'Must be between 1 and room capacity',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Required field';
              }
              final number = int.tryParse(value);
              if (number == null || number <= 0) {
                return 'Must be greater than 0';
              }
              if (_selectedRoom != null) {
                final capacity = _selectedRoom['capacity'] as int;
                if (number > capacity) {
                  return 'Exceeds room capacity of $capacity';
                }
              }
              if (number > 9999) {
                return 'Maximum 9999 people allowed';
              }
              return null;
            },
            onChanged: (value) {
              final number = int.tryParse(value);
              if (number != null) {
                setState(() {
                  _numberOfPeople = number;
                });
              }
            },
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            controller: _durationController,
            decoration: InputDecoration(
              labelText: 'Duration (minutes)',
              border: OutlineInputBorder(),
              helperText: 'Between 30 and 1440 minutes (24 hours)',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Required field';
              }
              final number = int.tryParse(value);
              if (number == null || number < 30) {
                return 'Minimum 30 minutes';
              }
              if (number > 1440) {
                return 'Maximum 24 hours (1440 minutes)';
              }
              return null;
            },
            onChanged: (value) {
              final number = int.tryParse(value);
              if (number != null) {
                setState(() {
                  _duration = number;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Future<List<dynamic>>? _roomDetailsFuture;

  Widget _buildPackageSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,  // Make children stretch full width
      children: [
        PackageDropdown(
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
        SizedBox(height: 8),  // Add some spacing between elements
        ElevatedButton.icon(
          onPressed: _selectedPackage != null ? _addSelectedPackage : null,
          icon: Icon(Icons.add, size: 20),
          label: Text('Add Package'),  // Changed text to be more descriptive
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, 48),  // Make button take full width with minimum height
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedPackages() {
    return Column(
      children: _selectedPackages.asMap().entries.map((entry) {
        final sp = entry.value;
        return Card(
          key: ValueKey(sp.uniqueId), // Use the unique ID here
          child: ListTile(
            title: Text(sp.package.name),
            subtitle: Text(_formatPrice(sp.package.priceInCents * sp.quantity)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.remove),
                  onPressed: () => _removePackage(sp),
                ),
                Text('${sp.quantity}'),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () => _incrementPackageQuantity(sp), // New method
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTotalPrice() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total Price:', style: TextStyle(fontSize: 18)),
            Text(
              _formatPrice(_calculateTotalPrice()),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.5,
        child: ElevatedButton(
          onPressed: _updateOrder,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: EdgeInsets.symmetric(vertical: 15),
          ),
          child: Text(
            'Update Order',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }

  void _incrementPackageQuantity(SelectedPackage selectedPackage) {
    final maxQuantity = 100; // Maximum quantity per package

    setState(() {
      final index = _selectedPackages.indexWhere((sp) => sp.uniqueId == selectedPackage.uniqueId);
      if (index != -1) {
        if (_selectedPackages[index].quantity >= maxQuantity) {
          showTopSnackBar('Maximum quantity of $maxQuantity reached for ${selectedPackage.package.name}');
          return;
        }
        _selectedPackages[index].quantity++;
      }
    });
  }

  Future<List<RoomShape>> _fetchSupportedLayouts(String roomId) async {
    // Return cached results if available
    if (_layoutResults.containsKey(roomId)) {
      return _layoutResults[roomId]!;
    }

    // Return existing future if already fetching
    if (_layoutCache.containsKey(roomId)) {
      return _layoutCache[roomId]!;
    }

    // Create new future and cache it
    _layoutCache[roomId] = _fetchAndCacheLayouts(roomId);
    return _layoutCache[roomId]!;
  }

  Future<List<RoomShape>> _fetchAndCacheLayouts(String roomId) async {
    try {
      final response = await http.get(
          Uri.parse('${Env.apiUrl}/api/meeting-rooms/$roomId/supported-layouts')
      );

      if (response.statusCode == 200) {
        final List<dynamic> layouts = json.decode(response.body);
        final results = layouts.map((layout) => RoomShape.fromJson(layout)).toList();

        // Cache the results
        _layoutResults[roomId] = results;
        _layoutCache.remove(roomId); // Remove the future from cache

        return results;
      }
      return [];
    } catch (e) {
      print('Error fetching supported layouts: $e');
      return [];
    }
  }

  Future<List<dynamic>> _fetchRoomDetails(String restaurantId) async {
    try {
      final response = await http.get(
          Uri.parse('${Env.apiUrl}/api/restaurants/$restaurantId/room-details?date=${_deliveryDateTime?.toIso8601String()}')
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      print('Error fetching room details: $e');
      return [];
    }
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
          actions: [
            TextButton(
              child: Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _addSelectedPackage() {
    if (_selectedPackage != null) {
      setState(() {
        _addPackage(_selectedPackage!);
        _selectedPackage = null; // Clear the selection after adding
      });

      // Show different messages based on whether package was incremented or added
      final existingPackage = _selectedPackages.firstWhere(
            (sp) => sp.package.id == _selectedPackage!.id,
        orElse: () => SelectedPackage(package: _selectedPackage!, quantity: 0),
      );

      if (existingPackage.quantity > 1) {
        showTopSnackBar('Increased quantity of ${_selectedPackage!.name}');
      } else {
        showTopSnackBar('${_selectedPackage!.name} added to order');
      }
    }
  }

  void _addPackage(Package package) {
    print('\nDEBUG: Adding package:');
    print('- Package name: ${package.name}');
    print('- Current package count: ${_selectedPackages.length}');
    final maxQuantity = 100; // Maximum quantity per package

    setState(() {
      final existingPackageIndex = _selectedPackages.indexWhere(
              (sp) => sp.package.id == package.id
      );

      if (existingPackageIndex != -1) {
        // Check if adding one more would exceed the maximum
        if (_selectedPackages[existingPackageIndex].quantity >= maxQuantity) {
          showTopSnackBar('Maximum quantity of $maxQuantity reached for ${package.name}');
          return;
        }
        _selectedPackages[existingPackageIndex].quantity++;
      } else {
        _selectedPackages.add(SelectedPackage(
          package: package,
          quantity: 1,
        ));
      }
    });
  }

  void _removePackage(SelectedPackage selectedPackage) {
    print('\nDEBUG: Removing package:');
    print('- Package name: ${selectedPackage.package.name}');
    print('- Current package count: ${_selectedPackages.length}');
    setState(() {
      final index = _selectedPackages.indexWhere((sp) => sp.uniqueId == selectedPackage.uniqueId);
      if (index != -1) {
        if (_selectedPackages[index].quantity > 1) {
          _selectedPackages[index].quantity--;
        } else {
          _selectedPackages.removeAt(index);
        }
      }
    });
  }

  Future<void> _selectDateTime(BuildContext context) async {
    try {
      final now = DateTime.now();
      // For edit orders, we'll use a reasonable past date limit (e.g., 1 year ago)
      final DateTime? date = await showDatePicker(
        context: context,
        initialDate: _deliveryDateTime ?? now,
        firstDate: now.subtract(Duration(days: 365)), // Allow dates up to 1 year in the past
        lastDate: now.add(Duration(days: 365)),
        selectableDayPredicate: (DateTime date) {
          // You can add specific date restrictions here if needed
          return true;
        },
      );

      if (date != null) {
        final TimeOfDay? time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(_deliveryDateTime ?? now),
          builder: (BuildContext context, Widget? child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                alwaysUse24HourFormat: true, // Use 24-hour format
              ),
              child: child!,
            );
          },
        );

        if (time != null) {
          final selectedDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );

          setState(() {
            _deliveryDateTime = selectedDateTime;
          });

          // If selecting a future date, maybe show a warning/info message
          if (selectedDateTime.isAfter(now)) {
            showTopSnackBar('Note: You are scheduling this order for a future date');
          }
        }
      }
    } catch (e) {
      print('Error selecting date time: $e');
      showTopSnackBar('Error selecting date and time');
    }
  }

  @override
  void dispose() {
    _layoutCache.clear();
    _layoutResults.clear();
    _numberOfPeopleController.dispose();
    _durationController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _clearLayoutCache() {
    setState(() {
      _layoutCache.clear();
      _layoutResults.clear();
    });
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
    required this.description,
    required this.priceInCents,
  });

  factory Package.fromJson(Map<String, dynamic> json) {
    return Package(
      id: json['id']?.toString() ?? '',
      name: json['package_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      priceInCents: int.tryParse(json['price']?.toString() ?? '0') ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Package &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class Restaurant {
  final String id;
  final String name;
  final List<MeetingRoom> meetingRooms;

  Restaurant({
    required this.id,
    required this.name,
    this.meetingRooms = const [],
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id']?.toString() ?? '',
      name: json['restaurant_name']?.toString() ?? '',
      meetingRooms: (json['meeting_rooms'] as List<dynamic>?)
          ?.map((room) => MeetingRoom.fromJson(room))
          .where((room) => room != null)
          .toList() ?? [],
    );
  }
}

class MeetingRoom {
  final String id;
  final String name;
  final int capacity;
  final List<RoomShape> supportedLayouts;

  MeetingRoom({
    required this.id,
    required this.name,
    required this.capacity,
    this.supportedLayouts = const [],
  });

  factory MeetingRoom.fromJson(Map<String, dynamic> json) {
    return MeetingRoom(
      id: json['id']?.toString() ?? '',
      name: json['room_name']?.toString() ?? '',
      capacity: int.tryParse(json['capacity']?.toString() ?? '0') ?? 0,
      supportedLayouts: (json['supported_layouts'] as List<dynamic>?)
          ?.map((layout) => RoomShape.fromJson(layout))
          .where((layout) => layout != null)
          .toList() ?? [],
    );
  }
}

class RoomShape {
  final String id;
  final String shapeName;

  RoomShape({required this.id, required this.shapeName});

  factory RoomShape.fromJson(Map<String, dynamic> json) {
    return RoomShape(
      id: json['id']?.toString() ?? '',
      shapeName: json['shape_name']?.toString() ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is RoomShape &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              shapeName == other.shapeName;

  @override
  int get hashCode => Object.hash(id, shapeName);
}

class OrderPurpose {
  final int id;
  final String name;
  final String nameEn;

  OrderPurpose({required this.id, required this.name, required this.nameEn});

  factory OrderPurpose.fromJson(Map<String, dynamic> json) {
    return OrderPurpose(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      nameEn: json['name_en']?.toString() ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is OrderPurpose &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'OrderPurpose(id: $id, name: $name, nameEn: $nameEn)';
}

class SelectedPackage {
  final Package package;
  int quantity;
  final String uniqueId; // Add this field

  SelectedPackage({
    required this.package,
    this.quantity = 1,
    String? uniqueId,
  }) : this.uniqueId = uniqueId ?? DateTime.now().millisecondsSinceEpoch.toString();
}

class PackageDropdown extends StatelessWidget {
  final List<Package> availablePackages;
  final Package? selectedPackage;
  final Function(Package?) onChanged;
  final bool isLoading;
  final Function(BuildContext, String) showDescription;

  PackageDropdown({
    required this.availablePackages,
    required this.selectedPackage,
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
          items: availablePackages.map((package) {
            String displayText = '${package.name} - ${_formatPrice(package.priceInCents)}';

            return DropdownMenuItem<Package>(
              value: package,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.info_outline, size: 20),
                    onPressed: () => showDescription(context, package.description),
                    constraints: BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayText,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: isLoading ? null : (Package? newValue) {
            if (newValue == selectedPackage) {
              onChanged(null);
            } else {
              onChanged(newValue);
            }
          },
          decoration: InputDecoration(
            labelText: 'Select Package',
            border: OutlineInputBorder(),
            suffixIcon: selectedPackage != null ? IconButton(
              icon: Icon(Icons.clear),
              onPressed: () => onChanged(null),
            ) : null,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          isExpanded: true,
          hint: Text('Select a package'),
        ),
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black12,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
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