import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../main.dart';
import '../../Organismo Certificador/candidatos.dart' show OCColors;

class AcreditacionDetalleScreen extends StatefulWidget {
  final String accreditationUuid;
  final String? logoUrl;

  const AcreditacionDetalleScreen({
    super.key,
    required this.accreditationUuid,
    this.logoUrl,
  });

  @override
  State<AcreditacionDetalleScreen> createState() =>
      _AcreditacionDetalleScreenState();
}

class _AcreditacionDetalleScreenState extends State<AcreditacionDetalleScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _errorMessage;
  String? _openingDocId;

  @override
  void initState() {
    super.initState();
    _fetchDetalle();
  }

  Future<void> _fetchDetalle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final path = '/api/v1/my-accreditations/${widget.accreditationUuid}';

    debugPrint('--- DETALLE ACREDITACIÓN REQUEST ---');
    debugPrint('URL: $path');

    try {
      final response = await dio.get(path);

      debugPrint('--- DETALLE ACREDITACIÓN RESPONSE ---');
      debugPrint('Status code: ${response.statusCode}');
      debugPrint('Body: ${response.data}');

      final body = response.data as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        setState(() {
          _data = body['data'] as Map<String, dynamic>;
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
      debugPrint('--- DETALLE ACREDITACIÓN ERROR ---');
      debugPrint(e.toString());
      setState(() {
        _errorMessage = 'Error de conexión: $e';
        _isLoading = false;
      });
    }
  }

  /// NOTA: ruta asumida siguiendo el mismo patrón usado en Centros
  /// Evaluadores. Ajustar si el backend usa otro endpoint para
  /// documentos de acreditaciones.
  Future<void> _openDocument(String documentUuid) async {
    setState(() => _openingDocId = documentUuid);

    final path =
        '/api/v1/my-accreditations/${widget.accreditationUuid}/documents/$documentUuid/open';

    debugPrint('--- ABRIR DOCUMENTO REQUEST ---');
    debugPrint('URL: $path');

    try {
      final response = await dio.post(path);

      debugPrint('--- ABRIR DOCUMENTO RESPONSE ---');
      debugPrint('Status code: ${response.statusCode}');
      debugPrint('Body: ${response.data}');

      final body = response.data as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        final temporaryUrl = data['temporary_url'] as String?;

        if (temporaryUrl == null || temporaryUrl.isEmpty) {
          _showSnack('No se encontró la URL del documento');
          return;
        }

        final uri = Uri.parse(temporaryUrl);
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (!launched && mounted) {
          _showSnack('No se pudo abrir el documento');
        }
      } else if (response.statusCode == 401) {
        await clearSession();
        _showSnack('Tu sesión expiró. Vuelve a iniciar sesión.');
      } else {
        _showSnack(
          body['message'] ?? 'No se pudo generar el acceso al documento',
        );
      }
    } catch (e) {
      debugPrint('--- ABRIR DOCUMENTO ERROR ---');
      debugPrint(e.toString());
      _showSnack('Error de conexión: $e');
    } finally {
      if (mounted) setState(() => _openingDocId = null);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
          'Detalle de la acreditación',
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
                onPressed: _fetchDetalle,
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

    final data = _data!;
    final origin = data['origin'] as Map<String, dynamic>?;
    final status = data['status'] as Map<String, dynamic>?;
    final operationalStatus =
        data['operational_status'] as Map<String, dynamic>?;
    final certifyingBody = data['certifying_body'] as Map<String, dynamic>?;
    final competenceStandard =
        data['competence_standard'] as Map<String, dynamic>?;
    final registrationKey = data['registration_key'] as String? ?? '';
    final contract = data['contract'] as Map<String, dynamic>?;
    final submittedAt = data['submitted_at'] as String? ?? '';
    final approvedAt = data['approved_at'] as String? ?? '';
    final review = data['review'] as Map<String, dynamic>?;
    final documents = (data['documents'] as List<dynamic>?) ?? [];

    return RefreshIndicator(
      onRefresh: _fetchDetalle,
      color: OCColors.mediumBlue,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ENCABEZADO
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    competenceStandard != null
                        ? '${competenceStandard['code'] ?? ''} - ${competenceStandard['name'] ?? ''}'
                        : '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: OCColors.darkBlue,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (status != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _colorForStatus(
                              status['code']?.toString(),
                            ).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status['name']?.toString() ?? '',
                            style: TextStyle(
                              color: _colorForStatus(
                                status['code']?.toString(),
                              ),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (operationalStatus != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00796B).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            operationalStatus['name']?.toString() ?? '',
                            style: const TextStyle(
                              color: Color(0xFF00796B),
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
          ),

          const SizedBox(height: 20),

          _sectionTitle('Información general'),
          _infoCard([
            _infoRow('Clave de registro', registrationKey),
            if (origin != null)
              _infoRow('Origen', origin['name']?.toString() ?? ''),
            if (certifyingBody != null)
              _infoRow(
                'Organismo certificador',
                certifyingBody['legal_name']?.toString() ?? '',
              ),
          ]),

          if (contract != null) ...[
            const SizedBox(height: 20),
            _sectionTitle('Vigencia del contrato'),
            _infoCard([
              _infoRow('Desde', contract['valid_from']?.toString() ?? ''),
              _infoRow('Hasta', contract['valid_until']?.toString() ?? ''),
            ]),
          ],

          const SizedBox(height: 20),
          _sectionTitle('Fechas'),
          _infoCard([
            _infoRow('Enviado', submittedAt),
            _infoRow('Aprobado', approvedAt),
          ]),

          if (review != null) ...[
            const SizedBox(height: 20),
            _sectionTitle('Revisión'),
            _infoCard([
              _infoRow('Ronda', review['round']?.toString() ?? ''),
              _infoRow('Decisión', review['decision']?.toString() ?? ''),
              _infoRow('Decidido el', review['decided_at']?.toString() ?? ''),
              if (review['general_note'] != null)
                _infoRow('Notas', review['general_note'].toString()),
            ]),
          ],

          if (documents.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionTitle('Documentos'),
            ...documents.map((d) {
              final doc = d as Map<String, dynamic>;
              final docUuid = doc['uuid'] as String?;
              final isOpening = _openingDocId == docUuid;

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
                  onTap: (docUuid == null || isOpening)
                      ? null
                      : () => _openDocument(docUuid),
                  child: ListTile(
                    leading: isOpening
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: OCColors.mediumBlue,
                            ),
                          )
                        : const Icon(
                            Icons.description_outlined,
                            color: OCColors.mediumBlue,
                            size: 28,
                          ),
                    title: Text(
                      doc['type_name']?.toString() ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: OCColors.darkBlue,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        doc['original_name']?.toString() ?? '',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    trailing: Icon(
                      Icons.open_in_new,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              );
            }),
          ],

          const SizedBox(height: 32),
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

  Widget _infoCard(List<Widget> rows) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: OCColors.cardBorder, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: OCColors.mediumBlue,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: OCColors.darkBlue),
            ),
          ),
        ],
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
