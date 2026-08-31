import 'package:flutter/material.dart';

/// Home screen placeholder — becomes the live session screen in a later step.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Taxi Pay')),
      body: const Center(child: Text('Home')),
    );
  }
}
