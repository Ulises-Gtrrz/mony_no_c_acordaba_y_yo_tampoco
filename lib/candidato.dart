import 'package:flutter/material.dart';
import 'catalogos.dart';
import 'miscursos.dart';
import 'miproceso.dart';

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
  static const Color _navy = Color(0xFF0A2342);
  static const Color _blue = Color(0xFF1B6CA8);
  static const Color _cyan = Color(0xFF38C9D6);
  static const Color _purple = Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Candidatos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado con saludo
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _navy,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _navy.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: _cyan,
                    child: Text(
                      widget.userName.isNotEmpty
                          ? widget.userName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hola, ${widget.userName}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.role,
                          style: TextStyle(
                            color: _cyan,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // CARDS
            Expanded(
              child: ListView(
                children: [
                  _OperationCard(
                    icon: Icons.storefront_outlined,
                    iconColor: _purple,
                    title: 'Catálogo de Cursos',
                    description:
                        'Los cursos que tu Organismo Certificador ofrece, con lo que incluye cada plan.',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              CatalogScreen(logoUrl: widget.logoUrl),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _OperationCard(
                    icon: Icons.menu_book_outlined,
                    iconColor: _blue,
                    title: 'Mis Cursos',
                    description:
                        'Los cursos de alineación y capacitación en los que estás inscrito.',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              MisCursosScreen(logoUrl: widget.logoUrl),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _OperationCard(
                    icon: Icons.checklist_rtl_outlined,
                    iconColor: _cyan,
                    title: 'Mi Proceso',
                    description:
                        'El avance paso a paso de tus procesos de certificación, tu expediente y tus formatos.',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              MiProcesoScreen(logoUrl: widget.logoUrl),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card reutilizable estilo "operaciones" con icono, título y descripción.
class _OperationCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _OperationCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.onTap,
  });

  static const Color _navy = Color(0xFF0A2342);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _navy,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: iconColor.withOpacity(0.15),
        highlightColor: Colors.white.withOpacity(0.03),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade500, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pantalla de relleno para "Mis Cursos" y "Mi Proceso" mientras
/// construyes esas pantallas reales.
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF0A2342),
        foregroundColor: Colors.white,
      ),
      body: Center(child: Text('Pantalla de "$title" (por construir)')),
    );
  }
}
