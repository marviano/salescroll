import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:salescroll/main.dart';

void main() {
  testWidgets('SalesCustomerEnrollmentPage smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp());

    // Verify that the SalesCustomerEnrollmentPage is rendered
    expect(find.text('Customer Enrollment'), findsOneWidget);

    // Verify that the form fields are present
    expect(find.widgetWithText(TextFormField, 'Customer Name'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Address'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Phone Number'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Restaurant Name'), findsOneWidget);

    // Verify that the submit button is present
    expect(find.widgetWithText(ElevatedButton, 'Submit'), findsOneWidget);
  });
}