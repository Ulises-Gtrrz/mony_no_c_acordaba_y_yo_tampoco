import 'package:flutter/material.dart';

class CandidatoScreen extends StatefulWidget {
  final String? logoUrl;
  final String userName;
  final String role;
  const CandidatoScreen({
    super.key,
    this.logoUrl,
    required this.userName,
    required this.role,
  });

  @override
  State<CandidatoScreen> createState() => _CandidatoScreenState();
}

class _CandidatoScreenState extends State<CandidatoScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Candidatos'), centerTitle: true),

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gestión de Candidatos',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            const Text(
              'Bienvenido al módulo de candidatos.',
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // Aquí puedes agregar la funcionalidad
                },
                child: const Text(
                  'Agregar candidato',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
