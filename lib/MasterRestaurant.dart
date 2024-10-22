import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'widgets/burger_menu.dart';
import 'widgets/loading_overlay.dart';
import 'package:salescroll/services/env.dart';
import 'services/alternating_color_listview.dart';
import 'RestaurantPackages.dart';
import 'widgets/network_error_handler.dart';

class MasterRestaurantPage extends StatefulWidget {
  @override
  _MasterRestaurantPageState createState() => _MasterRestaurantPageState();
}

class _MasterRestaurantPageState extends State<MasterRestaurantPage> {
  final GlobalKey<_MasterRestaurantFormState> _formKey = GlobalKey<_MasterRestaurantFormState>();

  @override
  Widget build(BuildContext context) {
    return NetworkErrorHandler(
      child: BurgerMenu(
        topBarTitle: "Master Restaurant",
        activePage: ActivePage.masterRestaurant,
        onRefresh: _refreshPage,
        child: MasterRestaurantForm(key: _formKey),
        backgroundColor: Colors.white,
      ),
    );
  }

  void _refreshPage() {
    _formKey.currentState?.refreshPage();
  }
}

class MasterRestaurantForm extends StatefulWidget {
  MasterRestaurantForm({Key? key}) : super(key: key);
  @override
  _MasterRestaurantFormState createState() => _MasterRestaurantFormState();
}

class _MasterRestaurantFormState extends State<MasterRestaurantForm> {
  final _formKey = GlobalKey<FormState>();
  final _restaurantNameController = TextEditingController();
  final _searchController = TextEditingController();
  List<MeetingRoomForm> _meetingRooms = [];
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isEditing = false;
  bool _isFormVisible = false;
  List<Map<String, dynamic>> _restaurants = [];
  String? _selectedRestaurantId;
  String _selectedStatus = 'active';
  Timer? _debounce;

  List<Map<String, dynamic>> _roomShapes = [];

  // @override
  // void initState() {
  //   super.initState();
  //   _fetchRoomShapes().then((_) {
  //     _addMeetingRoom();
  //     _fetchRestaurants();
  //   });
  // }

  @override
  void initState() {
    super.initState();
    _fetchRoomShapes().then((_) {
      _fetchRestaurants();
    });
  }

  // @override
  // void dispose() {
  //   _restaurantNameController.dispose();
  //   _searchController.dispose();
  //   _debounce?.cancel();
  //   for (var room in _meetingRooms) {
  //     room.dispose();
  //   }
  //   super.dispose();
  // }

  @override
  void dispose() {
    _restaurantNameController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    for (var room in _meetingRooms) {
      room.dispose();
    }
    super.dispose();
  }

  void _showForm({Map<String, dynamic>? restaurant}) {
    setState(() {
      _isFormVisible = true;
      if (restaurant != null) {
        _populateFormForEditing(restaurant);
      } else {
        _resetForm();
      }
    });
  }

  void _hideForm() {
    setState(() {
      _isFormVisible = false;
      _isEditing = false;
      _resetForm();
    });
  }

  void _populateFormForEditing(Map<String, dynamic> restaurant) {
    setState(() {
      _isEditing = true;
      _selectedRestaurantId = restaurant['id'];
      _restaurantNameController.text = restaurant['restaurant_name'];
      _meetingRooms = (restaurant['meeting_rooms'] as List<dynamic>?)
          ?.map((roomData) {
        final meetingRoom = MeetingRoomForm(
          onRemove: _removeMeetingRoom,
          supportedLayouts: _roomShapes,
        );
        meetingRoom.populate(roomData);
        print('DEBUG: Room ${roomData['room_name']} populated with layouts: ${meetingRoom.selectedLayouts}');
        return meetingRoom;
      }).toList() ?? [];
      if (_meetingRooms.isEmpty) _addMeetingRoom();
    });
  }

  void _addMeetingRoom() {
    setState(() {
      _meetingRooms.add(MeetingRoomForm(
        onRemove: _removeMeetingRoom,
        supportedLayouts: _roomShapes,
      ));
    });
  }

  void _removeMeetingRoom(MeetingRoomForm room) {
    setState(() {
      _meetingRooms.remove(room);
    });
    print('DEBUG: Room removed. Remaining rooms: ${_meetingRooms.length}');
    print('DEBUG: Remaining room IDs: ${_meetingRooms.map((r) => r.id).toList()}');
  }

  Future<void> _fetchRoomShapes() async {
    try {
      final response = await http.get(
          Uri.parse('${Env.apiUrl}/api/room-shapes')
      ).timeout(Duration(seconds: 10));
      if (response.statusCode == 200) {
        setState(() {
          _roomShapes = List<Map<String, dynamic>>.from(json.decode(response.body));
        });
        print('DEBUG: Fetched ${_roomShapes.length} room shapes');
      } else {
        throw Exception('Failed to load room shapes');
      }
    } catch (e) {
      print('DEBUG: Error fetching room shapes: $e');
      NetworkErrorNotifier.instance.notifyError();
    }
  }

  Future<void> _fetchRestaurants() async {
    setState(() => _isSearching = true);
    try {
      final response = await http.get(
          Uri.parse('${Env.apiUrl}/api/restaurants?status=$_selectedStatus&search=${_searchController.text}')
      ).timeout(Duration(seconds: 10));
      if (response.statusCode == 200) {
        setState(() {
          _restaurants = List<Map<String, dynamic>>.from(json.decode(response.body));
        });
        print('DEBUG: Fetched restaurants: ${json.encode(_restaurants)}');
      } else {
        throw Exception('Failed to load restaurants');
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
      _fetchRestaurants();
    });
  }

  void refreshPage() {
    _refreshPage();
  }

  Future<void> _toggleRestaurantStatus(String id) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${Env.apiUrl}/api/restaurants/$id/toggle-status'),
      ).timeout(Duration(seconds: 10));
      if (response.statusCode == 200) {
        _fetchRestaurants();
      } else {
        throw Exception('Failed to toggle restaurant status');
      }
    } catch (e) {
      NetworkErrorNotifier.instance.notifyError();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      bool allRoomsValid = _meetingRooms.every((room) => room.selectedLayouts.isNotEmpty);
      if (!allRoomsValid) {
        _showDialog('Error', 'Each room must have at least one supported layout.');
        return;
      }

      setState(() => _isLoading = true);

      try {
        final restaurantData = {
          'restaurantName': _restaurantNameController.text,
          'meetingRooms': _meetingRooms.map((room) => room.toJson()).toList(),
        };

        print('DEBUG: Submitting restaurant data:');
        print(json.encode(restaurantData));  // Add this line

        final response = await http.post(
          Uri.parse('${Env.apiUrl}/api/restaurants'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(restaurantData),
        ).timeout(Duration(seconds: 10));

        if (response.statusCode == 201) {
          _showDialog('Success', 'Restaurant added successfully');
          _resetForm();
          _fetchRestaurants();
        } else {
          throw Exception('Failed to add restaurant: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('Error submitting form: $e');
        NetworkErrorNotifier.instance.notifyError();
        _showDialog('Error', 'Failed to add restaurant. Please try again.');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateRestaurant() async {
    if (_formKey.currentState!.validate() && _selectedRestaurantId != null) {
      setState(() => _isLoading = true);
      try {
        final restaurantData = {
          'restaurantName': _restaurantNameController.text,
          'meetingRooms': _meetingRooms.map((room) => room.toJson()).toList(),
        };

        final response = await http.put(
          Uri.parse('${Env.apiUrl}/api/restaurants/$_selectedRestaurantId'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(restaurantData),
        ).timeout(Duration(seconds: 10));

        if (response.statusCode == 200) {
          _showDialog('Success', 'Restaurant updated successfully');
          _hideForm(); // Close the form
          _resetForm(); // Reset the form
          _fetchRestaurants(); // Refresh the restaurant list
        } else {
          final errorMessage = json.decode(response.body)['error'] ?? 'Unknown error occurred';
          throw Exception('Failed to update restaurant: $errorMessage');
        }
      } catch (e) {
        print('Error updating restaurant: $e');
        NetworkErrorNotifier.instance.notifyError();
        _showDialog('Error', 'Failed to update restaurant. Please try again.');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _cancelUpdate() {
    setState(() {
      _isEditing = false;
      _selectedRestaurantId = null;
      _restaurantNameController.clear();
      _meetingRooms.clear();
      _addMeetingRoom();
    });
  }

  void _resetForm() {
    setState(() {
      _isEditing = false;
      _selectedRestaurantId = null;
      _restaurantNameController.clear();
      _meetingRooms.clear();
      _addMeetingRoom(); // Add one empty meeting room form
    });
    _formKey.currentState?.reset(); // Reset the form validators
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

  void _refreshPage() {
    setState(() {
      _isLoading = false;
      _isSearching = false;
      _isEditing = false;
      _restaurants = [];
      _selectedRestaurantId = null;
      _selectedStatus = 'active';
      _restaurantNameController.clear();
      _searchController.clear();
      _meetingRooms.clear();
      _addMeetingRoom();
    });
    _fetchRestaurants();
  }

  Widget _buildButton({
    required VoidCallback onPressed,
    required String label,
    required Color color,
    IconData? icon, // Make icon optional
    Color textColor = Colors.black,
  }) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.35,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, color: textColor),
        ),
      ),
    );
  }

  Widget _buildRestaurantList() {
    return _isSearching
        ? Center(child: CircularProgressIndicator())
        : AlternatingColorListView(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      children: _restaurants.map((restaurant) => ListTile(
        title: Text(restaurant['restaurant_name']),
        subtitle: Text('Status: ${restaurant['status']} | Meeting Rooms: ${restaurant['meeting_rooms']?.length ?? 0}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: restaurant['status'] == 'active',
              onChanged: (value) => _toggleRestaurantStatus(restaurant['id']),
            ),
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () => _showForm(restaurant: restaurant),
            ),
            IconButton(
              icon: Icon(Icons.inventory),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RestaurantPackages(
                      restaurantId: restaurant['id'],
                      restaurantName: restaurant['restaurant_name'],
                    ),
                  ),
                );
              },
              tooltip: 'View Restaurant Packages',
            ),
          ],
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
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isFormVisible) ...[
              Container(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.add),
                  label: Text('Tambah Restoran'),
                  onPressed: () => _showForm(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFADFF2F),
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search Restaurants',
                  suffixIcon: Icon(Icons.search),
                ),
                onChanged: _onSearchChanged,
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FilterChip(
                    label: Text('All'),
                    selected: _selectedStatus == 'all',
                    onSelected: (selected) {
                      setState(() => _selectedStatus = 'all');
                      _fetchRestaurants();
                    },
                  ),
                  FilterChip(
                    label: Text('Active'),
                    selected: _selectedStatus == 'active',
                    onSelected: (selected) {
                      setState(() => _selectedStatus = 'active');
                      _fetchRestaurants();
                    },
                  ),
                  FilterChip(
                    label: Text('Inactive'),
                    selected: _selectedStatus == 'inactive',
                    onSelected: (selected) {
                      setState(() => _selectedStatus = 'inactive');
                      _fetchRestaurants();
                    },
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text('Restaurants:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              _buildRestaurantList(),
            ],
            if (_isFormVisible)
              Card(
                color: Color(0xFFFFF8F3),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          decoration: InputDecoration(labelText: 'Restaurant Name'),
                          controller: _restaurantNameController,
                          validator: (value) => value?.isEmpty ?? true ? 'Please enter restaurant name' : null,
                        ),
                        SizedBox(height: 10),
                        Divider(thickness: 1, color: Colors.grey[300]),
                        SizedBox(height: 10),
                        Text('Meeting Rooms:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ..._meetingRooms,
                        Container(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.add_circle, size: 18),
                            label: Text('Room', style: TextStyle(fontSize: 12)),
                            onPressed: _addMeetingRoom,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFFFD700),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        Divider(thickness: 1, color: Colors.grey[300]),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildButton(
                              onPressed: _isEditing ? _updateRestaurant : _submitForm,
                              label: _isEditing ? 'Update' : 'Tambah Restoran',
                              color: Color(0xFFADFF2F),
                            ),
                            _buildButton(
                              onPressed: _hideForm,
                              label: 'Cancel',
                              color: Colors.red,
                              textColor: Colors.white,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MeetingRoomForm extends StatefulWidget {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController capacityController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final List<Map<String, dynamic>> supportedLayouts; // Changed from Map<String, String> to Map<String, dynamic>
  final Function(MeetingRoomForm) onRemove;
  List<String> selectedLayouts = [];
  String? id;

  MeetingRoomForm({
    Key? key,
    required this.onRemove,
    required this.supportedLayouts,
  }) : super(key: key) {
    print('DEBUG: MeetingRoomForm created with supported layouts: $supportedLayouts');
  }

  void dispose() {
    nameController.dispose();
    capacityController.dispose();
    priceController.dispose();
  }

  void populate(Map<String, dynamic> data) {
    print('DEBUG: Populating MeetingRoomForm with data: $data');
    id = data['id'];
    nameController.text = data['room_name'] ?? '';
    capacityController.text = data['capacity']?.toString() ?? '';
    priceController.text = data['price_per_hour']?.toString() ?? '';
    selectedLayouts = List<String>.from(data['supported_layout_names'] ?? []);
    print('DEBUG: Populated layouts for ${data['room_name']}: $selectedLayouts');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': nameController.text,
      'capacity': int.tryParse(capacityController.text) ?? 0,
      'pricePerHour': int.tryParse(priceController.text) ?? 0,
      'supportedLayouts': selectedLayouts.map((name) =>
      supportedLayouts.firstWhere((layout) => layout['shape_name'] == name)['id']
      ).toList(),
    };
  }

  @override
  _MeetingRoomFormState createState() => _MeetingRoomFormState();
}

class _MeetingRoomFormState extends State<MeetingRoomForm> {
  @override
  Widget build(BuildContext context) {
    print('DEBUG: Building MeetingRoomForm widget for ${widget.nameController.text}');
    print('DEBUG: Current selected layouts: ${widget.selectedLayouts}');
    return Card(
      margin: EdgeInsets.symmetric(vertical: 10),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              decoration: InputDecoration(labelText: 'Room Name'),
              controller: widget.nameController,
              validator: (value) =>
              value?.isEmpty ?? true ? 'Please enter room name' : null,
              onChanged: (_) => setState(() {}),
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Capacity'),
              controller: widget.capacityController,
              keyboardType: TextInputType.number,
              validator: (value) =>
              value?.isEmpty ?? true ? 'Please enter room capacity' : null,
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Price per Hour (IDR)'),
              controller: widget.priceController,
              keyboardType: TextInputType.number,
              validator: (value) =>
              value?.isEmpty ?? true ? 'Please enter price per hour' : null,
            ),
            SizedBox(height: 10),
            Text('Supported Layouts:', style: TextStyle(fontSize: 16)),
            Wrap(
              spacing: 8,
              children: widget.supportedLayouts.map((layout) {
                print('DEBUG: Creating FilterChip for layout: ${layout['shape_name']}');
                return FilterChip(
                  label: Text(layout['shape_name']!),
                  selected: widget.selectedLayouts.contains(layout['shape_name']),
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        widget.selectedLayouts.add(layout['shape_name']!);
                      } else {
                        widget.selectedLayouts.remove(layout['shape_name']);
                      }
                    });
                    print('DEBUG: Layout ${layout['shape_name']} ${selected ? 'selected' : 'deselected'} for ${widget.nameController.text}');
                    print('DEBUG: Updated selected layouts: ${widget.selectedLayouts}');
                  },
                );
              }).toList(),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => widget.onRemove(widget),
              child: Text('Remove Room'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}