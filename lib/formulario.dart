import 'package:flutter/material.dart';
import 'registro_oc.dart';
import 'registro_ce.dart';
import 'registro_candidato.dart';

class FormScreen extends StatelessWidget {
  const FormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF0A2342),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Comienza tu registro en OCMAX',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0A2342),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Selecciona el tipo de perfil que deseas dar de alta en '
                'nuestra plataforma y completa el formulario correspondiente.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 24),
              _PerfilCard(
                icon: Icons.shield_outlined,
                titulo: 'Organismo Certificador (OC)',
                descripcion:
                    'Para instituciones reguladoras autorizadas para evaluar '
                    'y acreditar a Centros de Evaluación propios.',
                nota:
                    'Tu solicitud será enviada directamente al equipo de '
                    'administración de Alfa PCS Max para su correspondiente '
                    'aprobación y validación de RFC.',
                textoBoton: 'Registrar OC',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegistroOcScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _PerfilCard(
                icon: Icons.workspace_premium_outlined,
                titulo: 'Centro / Evaluador (CE/EI)',
                descripcion:
                    'Para Centros de Evaluación independientes o Evaluadores '
                    'que operan bajo el patrocinio de un OC acreditado.',
                nota:
                    'Requiere especificar el tipo de acreditación y el '
                    'folio/UUID de la institución superior (Organismo '
                    'Certificador) que respalda su operación.',
                textoBoton: 'Registrar CE / EI',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegistroCEScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _PerfilCard(
                icon: Icons.person_outline,
                titulo: 'Candidato / Alumno',
                descripcion:
                    'Para usuarios individuales que buscan inscribirse y '
                    'evaluarse en algún estándar de competencia.',
                nota:
                    'Permite ligar de forma directa tu perfil a un estándar '
                    'de competencia del catálogo para que un evaluador tome '
                    'tu solicitud de inmediato.',
                textoBoton: 'Registrar Candidato',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegistroCandtoScreen(),
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

class _PerfilCard extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String descripcion;
  final String nota;
  final String textoBoton;
  final VoidCallback onPressed;

  const _PerfilCard({
    required this.icon,
    required this.titulo,
    required this.descripcion,
    required this.nota,
    required this.textoBoton,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0E6E8C);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0F3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: teal),
          ),
          const SizedBox(height: 16),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            descripcion,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Text(
            nota,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: teal,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                textoBoton,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
