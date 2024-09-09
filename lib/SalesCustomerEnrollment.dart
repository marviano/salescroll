import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SalesCustomerEnrollmentPage extends StatefulWidget {
  @override
  _SalesCustomerEnrollmentPageState createState() => _SalesCustomerEnrollmentPageState();
}

class _SalesCustomerEnrollmentPageState extends State<SalesCustomerEnrollmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _packageController = TextEditingController();
  final _searchController = TextEditingController();
  String _name = '', _address = '', _phoneNumber = '';
  String? _selectedRestaurant;
  Package? _selectedPackage;
  List<SelectedPackage> _selectedPackages = [];
  DateTime? _deliveryDateTime;

  final List<String> _restaurants = ['Lombok Idjoe', 'IClub', '2 Fat Guys', 'Ueno'];
  final Map<String, List<Package>> _restaurantPackages = {
    'Lombok Idjoe': [
      Package(id: 'L1', name: 'Lombok Dasar', price: 100, description: 'Fitur dasar untuk Lombok'),
      Package(id: 'L2', name: 'Lombok Premium', price: 200, description: 'Fitur premium untuk Lombok'),
    ],
    'IClub': [
      Package(id: 'I1', name: 'IClub Standar', price: 150, description: 'Fitur standar untuk IClub'),
      Package(id: 'I2', name: 'IClub VIP', price: 250, description: 'Fitur VIP untuk IClub'),
    ],
  };

  List<Package> get _availablePackages => _selectedRestaurant != null ? _restaurantPackages[_selectedRestaurant!] ?? [] : [];

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      _showDialog('Formulir Terkirim', 'Data pelanggan berhasil disimpan');
    }
  }

  void _showDialog(String title, String content) => showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [TextButton(child: Text('OK'), onPressed: () => Navigator.pop(context))],
    ),
  );

  void _addPackage(Package package) {
    setState(() {
      var existingPackage = _selectedPackages.firstWhere(
            (element) => element.package.id == package.id,
        orElse: () => SelectedPackage(package: package, quantity: 0),
      );
      if (existingPackage.quantity == 0) _selectedPackages.add(existingPackage);
      existingPackage.quantity++;
    });
  }

  void _removePackage(SelectedPackage selectedPackage) {
    setState(() {
      if (selectedPackage.quantity > 1) selectedPackage.quantity--;
      else _selectedPackages.remove(selectedPackage);
    });
  }

  void _showSearchDialog() {
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
                decoration: InputDecoration(hintText: 'Masukkan nama paket', suffixIcon: Icon(Icons.search)),
                onChanged: (value) => setState(() {}),
              ),
              SizedBox(height: 10),
              Container(
                height: 200,
                width: double.maxFinite,
                child: ListView(
                  children: _availablePackages
                      .where((package) => package.name.toLowerCase().contains(_searchController.text.toLowerCase()))
                      .map((package) => ListTile(
                    title: Text(package.name),
                    subtitle: Text('Rp${package.price}'),
                    onTap: () {
                      _addPackage(package);
                      Navigator.pop(context);
                    },
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _deliveryDateTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_deliveryDateTime ?? DateTime.now()),
      );
      if (pickedTime != null) {
        setState(() {
          _deliveryDateTime = DateTime(
            pickedDate.year, pickedDate.month, pickedDate.day,
            pickedTime.hour, pickedTime.minute,
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _packageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pendaftaran Pelanggan')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Nama Pelanggan'),
                validator: (value) => value?.isEmpty ?? true ? 'Mohon masukkan nama pelanggan' : null,
                onSaved: (value) => _name = value!,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Alamat'),
                validator: (value) => value?.isEmpty ?? true ? 'Mohon masukkan alamat' : null,
                onSaved: (value) => _address = value!,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Nomor Telepon'),
                keyboardType: TextInputType.phone,
                validator: (value) => value?.isEmpty ?? true ? 'Mohon masukkan nomor telepon' : null,
                onSaved: (value) => _phoneNumber = value!,
              ),
              SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Nama Restoran'),
                value: _selectedRestaurant,
                items: _restaurants.map((restaurant) => DropdownMenuItem(value: restaurant, child: Text(restaurant))).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedRestaurant = newValue;
                    _selectedPackage = null;
                    _selectedPackages.clear();
                    _packageController.clear();
                  });
                },
                validator: (value) => value == null ? 'Mohon pilih restoran' : null,
                onSaved: (value) => _selectedRestaurant = value,
              ),
              SizedBox(height: 20),
              Text('Pilih Paket:', style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<Package>(
                      value: _selectedPackage,
                      items: _availablePackages.map((package) => DropdownMenuItem(
                        value: package,
                        child: Text('${package.name} - Rp${package.price}'),
                      )).toList(),
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
                        enabled: _selectedRestaurant != null,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  IconButton(
                    icon: Icon(Icons.search),
                    onPressed: _selectedRestaurant != null ? _showSearchDialog : null,
                  ),
                ],
              ),
              ..._selectedPackages.map((selectedPackage) => ListTile(
                title: Text(selectedPackage.package.name),
                subtitle: Text('${selectedPackage.package.description} - Rp${selectedPackage.package.price}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Jumlah: ${selectedPackage.quantity}'),
                    IconButton(icon: Icon(Icons.add), onPressed: () => _addPackage(selectedPackage.package)),
                    IconButton(icon: Icon(Icons.remove), onPressed: () => _removePackage(selectedPackage)),
                  ],
                ),
              )),
              SizedBox(height: 20),
              InkWell(
                onTap: () => _selectDateTime(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Tanggal dan Waktu Pengiriman',
                    hintText: 'Pilih tanggal dan waktu',
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
              SizedBox(height: 20),
              Center(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.5,
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    child: Text('Kirim'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Package {
  final String id, name, description;
  final double price;
  Package({required this.id, required this.name, required this.price, required this.description});
}

class SelectedPackage {
  final Package package;
  int quantity;
  SelectedPackage({required this.package, this.quantity = 1});
}