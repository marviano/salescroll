import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import '../services/env.dart';
import '../widgets/network_error_handler.dart';

class ExportCustomerProfilePage extends StatefulWidget {
  const ExportCustomerProfilePage({Key? key}) : super(key: key);

  @override
  _ExportCustomerProfilePageState createState() => _ExportCustomerProfilePageState();
}

class _ExportCustomerProfilePageState extends State<ExportCustomerProfilePage> {
  DateTime? startDate;
  DateTime? endDate;
  String? selectedLeadSource;
  bool isLoading = false;

  final List<String> leadSourceOptions = [
    'All',
    'Event Marketing',
    'Canvas',
    'Digital Marketing',
    'Referral',
    'PoS'
  ];

  Future<void> exportCustomers() async {
    setState(() => isLoading = true);

    try {
      final dio = Dio();

      // Build query parameters
      final queryParams = {
        if (startDate != null)
          'start_date': DateFormat('yyyy-MM-dd').format(startDate!),
        if (endDate != null)
          'end_date': DateFormat('yyyy-MM-dd').format(endDate!),
        if (selectedLeadSource != null && selectedLeadSource != 'All')
          'lead_source': selectedLeadSource,
      };

      // Get temporary directory
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'customer_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final savePath = '${dir.path}/$fileName';

      // Download file
      await dio.download(
        '${Env.apiUrl}/api/export/customers',
        savePath,
        queryParameters: queryParams,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: false,
        ),
      );

      // Open the file
      await OpenFile.open(savePath);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export completed successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NetworkErrorHandler(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Export Customer Profile'),
          elevation: 2,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Date Range Selection
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        child: ListTile(
                          leading: const Icon(Icons.calendar_today),
                          title: const Text('Tanggal Mulai'),
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
                    Expanded(
                      child: Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        child: ListTile(
                          leading: const Icon(Icons.calendar_today),
                          title: const Text('Tanggal Akhir'),
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

                const SizedBox(height: 16),

                // Lead Source Dropdown
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Lead Source',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedLeadSource,
                  items: leadSourceOptions.map((source) => DropdownMenuItem(
                    value: source,
                    child: Text(source),
                  )).toList(),
                  onChanged: (value) => setState(() => selectedLeadSource = value),
                ),

                const SizedBox(height: 20),

                // Export Button
                ElevatedButton(
                  onPressed: isLoading ? null : exportCustomers,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isLoading
                      ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)
                  )
                      : const Text('Export to Excel'),
                ),

                const SizedBox(height: 20),

                // Information Card
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Export Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• Export will include customer name, phone, address, company, and lead source\n'
                              '• Date range filters apply to customer registration date\n'
                              '• Lead source filter helps identify customer acquisition channels\n'
                              '• Export will be generated as an Excel file (.xlsx)',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}