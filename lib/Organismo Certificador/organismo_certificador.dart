import 'package:flutter/material.dart';
import 'centros_evaluadores.dart';
import 'candidatos.dart';
import 'diagnostica.dart';
import 'newcurso.dart';
import 'evaluador.dart';

// Paleta centralizada para consistencia en toda la app
class OCColors {
  static const darkBlue = Color(0xFF0A2342);
  static const mediumBlue = Color(0xFF1B6CA8);
  static const cyan = Color(0xFF38C9D6);
  static const bgLight = Color(0xFFF5F7FA);
  static const cardBorder = Color(0xFFE1E8ED);
}

class OrganismoScreen extends StatelessWidget {
  final String? logoUrl;

  const OrganismoScreen({super.key, this.logoUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OCColors.bgLight,
      appBar: AppBar(
        backgroundColor: OCColors.darkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Organismo Certificador',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Panel de gestión y control',
              style: TextStyle(
                fontSize: 12,
                color: OCColors.cyan.withOpacity(0.9),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          if (logoUrl != null && logoUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  logoUrl!,
                  height: 36,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio:
                0.85, // Tarjetas ligeramente más altas para mejor balance
            children: [
              _MenuCard(
                icon: Icons.apartment_rounded,
                label: 'Centros Evaluadores',
                description: 'CE / EI',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CentrosEvaluadoresScreen(logoUrl: logoUrl),
                    ),
                  );
                },
              ),
              _MenuCard(
                icon: Icons.person,
                label: 'Solicitudes de Candidatos',
                description: '',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CandidatosScreen(logoUrl: logoUrl),
                    ),
                  );
                },
              ),
              // Placeholder para futuro módulo (ej. Documentación)
              _MenuCard(
                icon: Icons.format_list_bulleted_add,
                label: 'Evaluación Diagnóstica',
                description:
                    'La evaluación diagnóstica de cada Estándar de Competencia que acredita tu Organismo.',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DiagnosticaScreen(logoUrl: logoUrl),
                    ),
                  );
                },
              ),
              _MenuCard(
                icon: Icons.format_list_bulleted_add,
                label: 'Gestión de Cursos',
                description:
                    'Los cursos de alineación y capacitación que tu Organismo ofrece antes de la evaluación.',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NewCursoScreen(logoUrl: logoUrl),
                    ),
                  );
                },
              ),
              _MenuCard(
                icon: Icons.format_list_bulleted_add,
                label: 'Evaluadores',
                description:
                    'Registro de evaluadores del centro Evaluador y sus estándares certificados.',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EvaluadorScreen(logoUrl: logoUrl),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? description;
  final VoidCallback onTap;
  final bool enabled;

  const _MenuCard({
    required this.icon,
    required this.label,
    this.description,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = enabled ? 1.0 : 0.5;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OCColors.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: OCColors.darkBlue.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Contenedor circular para el icono
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: OCColors.cyan.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: OCColors.mediumBlue.withOpacity(opacity),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: OCColors.darkBlue.withOpacity(opacity),
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade500.withOpacity(opacity),
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
