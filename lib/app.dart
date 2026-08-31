import 'package:flutter/material.dart';

/// Root widget for Taxi Pay.
class TaxiPayApp extends StatelessWidget {
  const TaxiPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taxi Pay',
      theme: ThemeData(useMaterial3: true),
      home: const Scaffold(
        body: Center(child: Text('Taxi Pay')),
      ),
    );
  }
}
