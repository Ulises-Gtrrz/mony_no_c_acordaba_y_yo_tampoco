import 'package:flutter/material.dart';
import '../main.dart';
import '../Organismo Certificador/candidatos.dart' show OCColors;

class EvaluadorScreen extends StatefulWidget {
  final String? logoUrl;
  const EvaluadorScreen({super.key, this.logoUrl});

  @override
  State<EvaluadorScreen> createState() => _EvaluadorScreenState();
}

class _EvaluadorScreenState extends State<EvaluadorScreen> {
  List<Map<String, dynamic>> _evaluadores = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchEvaluadores();
  }

  Future<void> _fetchEvaluadores() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    debugPrint('--- EVALUADORES REQUEST ---');
    debugPrint(
      'URL: https://ocmax.mx/api/v1/evaluators/get?page=1&per_page=15',
    );

    try {
      final response = await dio.get(
        '/api/v1/evaluators/get',
        queryParameters: {'page': 1, 'per_page': 15},
      );

      debugPrint('--- EVALUADORES RESPONSE ---');
      debugPrint('Status code: ${response.statusCode}');
      debugPrint('Body: ${response.data}');

      final body = response.data as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> data = body['data'] as List<dynamic>;
        setState(() {
          _evaluadores = data.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        await clearSession();
        setState(() {
          _errorMessage = 'Tu sesión expiró. Vuelve a iniciar sesión.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              body['message'] ?? 'No se pudo obtener la información';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('--- EVALUADORES ERROR ---');
      debugPrint(e.toString());
      setState(() {
        _errorMessage = 'Error de conexión: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OCColors.bgLight,
      appBar: AppBar(
        backgroundColor: OCColors.darkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Evaluadores',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        actions: [
          if (widget.logoUrl != null && widget.logoUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  widget.logoUrl!,
                  height: 36,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: OCColors.mediumBlue),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: OCColors.darkBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchEvaluadores,
                style: ElevatedButton.styleFrom(
                  backgroundColor: OCColors.mediumBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_evaluadores.isEmpty) {
      return const Center(child: Text('No hay evaluadores disponibles'));
    }

    return RefreshIndicator(
      onRefresh: _fetchEvaluadores,
      color: OCColors.mediumBlue,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _evaluadores.length,
        itemBuilder: (context, index) =>
            _buildEvaluadorCard(_evaluadores[index]),
      ),
    );
  }

  Widget _buildEvaluadorCard(Map<String, dynamic> evaluador) {
    final fullName = evaluador['full_name'] as String? ?? '';
    final curp = evaluador['curp'] as String? ?? '';
    final rfc = evaluador['rfc'] as String? ?? '';
    final evaluatorKey = evaluador['evaluator_key'] as String? ?? '';
    final email = evaluador['email'] as String? ?? '';
    final phone = evaluador['phone'] as String? ?? '';

    final institution = evaluador['institution'] as Map<String, dynamic>?;
    final institutionName = institution?['name'] as String? ?? '';
    final institutionLogo = institution?['logo_url'] as String?;

    final operationalStatus =
        evaluador['operational_status'] as Map<String, dynamic>?;
    final statusName = operationalStatus?['name'] as String? ?? '';
    final statusCode = operationalStatus?['code'] as String?;

    final competenceStandards =
        (evaluador['competence_standards'] as List<dynamic>?) ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: OCColors.cardBorder, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: OCColors.cyan.withOpacity(0.18),
                  child: Text(
                    fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: OCColors.mediumBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: OCColors.darkBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (evaluatorKey.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: OCColors.mediumBlue.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Clave: $evaluatorKey',
                                style: const TextStyle(
                                  color: OCColors.mediumBlue,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (statusName.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _colorForStatus(
                                  statusCode,
                                ).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusName,
                                style: TextStyle(
                                  color: _colorForStatus(statusCode),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (institutionLogo != null && institutionLogo.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      institutionLogo,
                      height: 32,
                      width: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: OCColors.cardBorder),
            const SizedBox(height: 10),

            if (curp.isNotEmpty) _infoRow(Icons.badge_outlined, 'CURP: $curp'),
            if (rfc.isNotEmpty)
              _infoRow(Icons.receipt_long_outlined, 'RFC: $rfc'),
            if (institutionName.isNotEmpty)
              _infoRow(Icons.apartment_outlined, institutionName),
            if (email.isNotEmpty) _infoRow(Icons.email_outlined, email),
            if (phone.isNotEmpty) _infoRow(Icons.phone_outlined, phone),

            if (competenceStandards.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Estándares acreditados',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: OCColors.darkBlue,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: competenceStandards.map((cs) {
                  final entry = cs as Map<String, dynamic>;
                  final standard =
                      entry['competence_standard'] as Map<String, dynamic>?;
                  final code = standard?['code'] as String? ?? '';
                  final name = standard?['name'] as String? ?? '';
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: OCColors.cyan.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: OCColors.cyan.withOpacity(0.35),
                      ),
                    ),
                    child: Text(
                      name.isNotEmpty ? '$code — $name' : code,
                      style: const TextStyle(
                        color: OCColors.darkBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForStatus(String? code) {
    switch (code) {
      case 'active':
        return const Color(0xFF00796B);
      case 'suspended':
        return const Color(0xFFC62828);
      case 'pending':
        return Colors.orange.shade800;
      default:
        return OCColors.mediumBlue;
    }
  }
}
