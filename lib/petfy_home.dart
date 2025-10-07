import 'package:flutter/material.dart';

class PetfyHome extends StatefulWidget {
  const PetfyHome({super.key}); // <- importante que sea const
  @override
  State<PetfyHome> createState() => _PetfyHomeState();
}

class _PetfyHomeState extends State<PetfyHome> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PetfyCo')),
      body: const Center(child: Text('Home listo 🐾')),
    );
  }
}
