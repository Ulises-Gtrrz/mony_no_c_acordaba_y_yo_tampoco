import 'package:flutter/material.dart';

class OrganismoScreen extends StatelessWidget {
  final String? logoUrl;

  const OrganismoScreen({super.key, this.logoUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Desarrollo')),
      body: Stack(
        children: [
          const Center(child: Text('Pantalla de Desarrollo')),
          if (logoUrl != null && logoUrl!.isNotEmpty)
            Positioned(
              top: 12,
              right: 12,
              child: Image.network(
                logoUrl!,
                height: 48,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }
}
