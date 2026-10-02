import 'package:flutter/material.dart';
import '../main.dart';
import '../Organismo Certificador/candidatos.dart';
import 'acreditacion_detalle.dart';
import 'candidatos_ce.dart';
import 'nueva_acreditacion.dart';

class CentroEvaluadorHomeScreen extends StatefulWidget {
  final String? logoUrl;
  final String userName;
  final String role;

  const CentroEvaluadorHomeScreen({
    super.key,
    this.logoUrl,
    required this.userName,
    required this.role,
  });

  @override
  State<CentroEvaluadorHomeScreen> createState() =>
      _CentroEvaluadorHomeScreenState();
}

class _CentroEvaluadorHomeScreenState extends State<CentroEvaluadorHomeScreen> {
  // Datos de elegibilidad (can_request, blockers)
  Map<String, dynamic>? _eligibilityData;
  // Lista real de acreditaciones (con uuid correcto para el detalle)
  List<Map<String, dynamic>> _accreditations = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.wait([_fetchEligibility(), _fetchAccreditations()]);
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchEligibility() async {
    const path = '/api/v1/my-accreditations/eligibility';

    debugPrint('--- ELEGIBILIDAD REQUEST ---');
    debugPrint('URL: $path');

    try {
      final response = await dio.get(path);

      debugPrint('--- ELEGIBILIDAD RESPONSE ---');
      debugPrint('Status code: ${response.statusCode}');
      debugPrint('Body: ${response.data}');

      final body = response.data as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        _eligibilityData = body['data'] as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        await clearSession();
        _errorMessage = 'Tu sesión expiró. Vuelve a iniciar sesión.';
      } else {
        _errorMessage = body['message'] ?? 'No se pudo obtener la elegibilidad';
      }
    } catch (e) {
      debugPrint('--- ELEGIBILIDAD ERROR ---');
      debugPrint(e.toString());
      rethrow;
    }
  }

  Future<void> _fetchAccreditations() async {
    const path = '/api/v1/my-accreditations/get';

    debugPrint('--- ACREDITACIONES REQUEST ---');
    debugPrint('URL: $path');

    try {
      final response = await dio.get(path);

      debugPrint('--- ACREDITACIONES RESPONSE ---');
      debugPrint('Status code: ${response.statusCode}');
      debugPrint('Body: ${response.data}');

      final body = response.data as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> data = body['data'] as List<dynamic>;
        _accreditations = data.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 401) {
        await clearSession();
        _errorMessage = 'Tu sesión expiró. Vuelve a iniciar sesión.';
      } else {
        _errorMessage =
            body['message'] ?? 'No se pudieron obtener las acreditaciones';
      }
    } catch (e) {
      debugPrint('--- ACREDITACIONES ERROR ---');
      debugPrint(e.toString());
      rethrow;
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
          'Mis Acreditaciones',
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
                onPressed: _fetchAll,
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

    final canRequest = _eligibilityData?['can_request'] as bool? ?? false;
    final blockers = (_eligibilityData?['blockers'] as List<dynamic>?) ?? [];

    return RefreshIndicator(
      onRefresh: _fetchAll,
      color: OCColors.mediumBlue,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // TARJETA DE USUARIO / ROL
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: OCColors.cyan.withOpacity(0.18),
                    child: const Icon(
                      Icons.verified_user_outlined,
                      color: OCColors.mediumBlue,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: OCColors.darkBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: OCColors.mediumBlue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.role,
                            style: const TextStyle(
                              color: OCColors.mediumBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CandidatosCEScreen(logoUrl: widget.logoUrl),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: OCColors.darkBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.people_outline),
              label: const Text('Gestión de Candidatos'),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        NuevaAcreditacionScreen(logoUrl: widget.logoUrl),
                  ),
                );
                if (result == true) {
                  _fetchAll();
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: OCColors.mediumBlue,
                side: const BorderSide(color: OCColors.mediumBlue),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Nueva Solicitud'),
            ),
          ),
          const SizedBox(height: 16),

          // ESTATUS DE ELEGIBILIDAD
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: canRequest
                  ? const Color(0xFF00796B).withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: canRequest
                    ? const Color(0xFF00796B)
                    : Colors.orange.shade800,
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  canRequest ? Icons.check_circle : Icons.info_outline,
                  color: canRequest
                      ? const Color(0xFF00796B)
                      : Colors.orange.shade800,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    canRequest
                        ? 'Puedes solicitar una nueva acreditación'
                        : 'No puedes solicitar una acreditación por ahora',
                    style: TextStyle(
                      color: canRequest
                          ? const Color(0xFF00796B)
                          : Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (blockers.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionTitle('Impedimentos'),
            ...blockers.map((b) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8.0),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(
                    color: OCColors.cardBorder,
                    width: 0.5,
                  ),
                ),
                child: ListTile(
                  leading: const Icon(Icons.block, color: Colors.red),
                  title: Text(
                    b.toString(),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              );
            }),
          ],

          if (_accreditations.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionTitle('Estándares ya acreditados'),
            ..._accreditations.map((accreditation) {
              final accreditationUuid = accreditation['uuid']?.toString();
              final competenceStandard =
                  accreditation['competence_standard'] as Map<String, dynamic>?;
              final code = competenceStandard?['code']?.toString() ?? '';
              final name = competenceStandard?['name']?.toString() ?? '';
              final certifyingBody =
                  accreditation['certifying_body'] as Map<String, dynamic>?;
              final certifyingBodyName =
                  certifyingBody?['legal_name']?.toString() ?? '';
              final status = accreditation['status'] as Map<String, dynamic>?;
              final statusName = status?['name']?.toString() ?? '';
              final statusCode = status?['code']?.toString();

              return Card(
                margin: const EdgeInsets.only(bottom: 8.0),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(
                    color: OCColors.cardBorder,
                    width: 0.5,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: accreditationUuid == null
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AcreditacionDetalleScreen(
                                accreditationUuid: accreditationUuid,
                                logoUrl: widget.logoUrl,
                              ),
                            ),
                          );
                        },
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$code - $name',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: OCColors.darkBlue,
                                ),
                              ),
                            ),
                            if (statusName.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
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
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.grey,
                              size: 18,
                            ),
                          ],
                        ),
                        if (certifyingBodyName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              certifyingBodyName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: OCColors.mediumBlue,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Color _colorForStatus(String? code) {
    switch (code) {
      case 'approved':
        return const Color(0xFF00796B);
      case 'in_review':
        return OCColors.mediumBlue;
      case 'rejected':
        return const Color(0xFFC62828);
      case 'pending':
        return Colors.orange.shade800;
      default:
        return OCColors.mediumBlue;
    }
  }
}
