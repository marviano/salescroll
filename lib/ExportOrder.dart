import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import '../services/env.dart';

class ExportOrderPage extends StatefulWidget {
  const ExportOrderPage({Key? key}) : super(key: key);

  @override
  _ExportOrderPageState createState() => _ExportOrderPageState();
}

class _ExportOrderPageState extends State<ExportOrderPage> {
  DateTime? startDate;
  DateTime? endDate;
  String? selectedStatus;
  bool isLoading = false;

  final List<String> statusOptions = [
    'All',
    'pending',
    'confirmed',
    'completed',
    'cancelled'
  ];

  Future<void> exportOrders() async {
    setState(() => isLoading = true);

    try {
      final dio = Dio();

      // Build query parameters
      final queryParams = {
        if (startDate != null)
          'start_date': DateFormat('yyyy-MM-dd').format(startDate!),
        if (endDate != null)
          'end_date': DateFormat('yyyy-MM-dd').format(endDate!),
        if (selectedStatus != null && selectedStatus != 'All')
          'status': selectedStatus,
      };

      // Get temporary directory
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'orders_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final savePath = '${dir.path}/$fileName';

      // Download file
      await dio.download(
        '${Env.apiUrl}/api/export/orders',
        savePath,
        queryParameters: queryParams,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: false,
        ),
      );

      // Open the file
      await OpenFile.open(savePath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export completed successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: ${e.toString()}')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Export Order Data'),
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date Range Selection
            // Replace your Row and Cards section with this:
            Row(
              children: [
                Expanded(  // Added this
                  child: Card(
                    elevation: 2,
                    margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: ListTile(
                      leading: Icon(Icons.calendar_today),
                      title: Text('Tanggal Mulai'),
                      subtitle: Text(startDate != null ?
                      DateFormat('dd MMM yyyy').format(startDate!) : 'Not set'),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) setState(() => startDate = date);
                      },
                    ),
                  ),
                ),

                Expanded(  // Added this
                  child: Card(
                    elevation: 2,
                    margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: ListTile(
                      leading: Icon(Icons.calendar_today),
                      title: Text('Tanggal Akhir'),
                      subtitle: Text(endDate != null ?
                      DateFormat('dd MMM yyyy').format(endDate!) : 'Not set'),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: endDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) setState(() => endDate = date);
                      },
                    ),
                  ),
                ),
              ],
            ),

            // Status Dropdown
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Order Status',
                border: OutlineInputBorder(),
              ),
              value: selectedStatus,
              items: statusOptions.map((status) => DropdownMenuItem(
                value: status,
                child: Text(status),
              )).toList(),
              onChanged: (value) => setState(() => selectedStatus = value),
            ),

            SizedBox(height: 20),

            // Export Button
            ElevatedButton(
              onPressed: isLoading ? null : exportOrders,
              child: isLoading
                  ? CircularProgressIndicator()
                  : Text('Export to Excel'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}