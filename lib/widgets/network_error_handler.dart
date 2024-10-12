import 'package:flutter/material.dart';
import 'dart:async';

class NetworkErrorHandler extends StatelessWidget {
  final Widget child;

  const NetworkErrorHandler({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          child,
          StreamBuilder<bool>(
            stream: NetworkErrorNotifier.instance.errorStream,
            builder: (context, snapshot) {
              if (snapshot.data == true) {
                return Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Network Error',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 16),
                            Text('Please check your internet connection and try again.'),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                NetworkErrorNotifier.instance.clearError();
                                // Add any additional retry logic here
                              },
                              child: Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
              return SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}

class NetworkErrorNotifier {
  static final NetworkErrorNotifier instance = NetworkErrorNotifier._internal();

  factory NetworkErrorNotifier() {
    return instance;
  }

  NetworkErrorNotifier._internal();

  final _errorStreamController = StreamController<bool>.broadcast();

  Stream<bool> get errorStream => _errorStreamController.stream;

  void notifyError() {
    _errorStreamController.add(true);
  }

  void clearError() {
    _errorStreamController.add(false);
  }

  void dispose() {
    _errorStreamController.close();
  }
}