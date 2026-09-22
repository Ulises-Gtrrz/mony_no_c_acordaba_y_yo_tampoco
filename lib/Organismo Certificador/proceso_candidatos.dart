import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import 'candidatos.dart';

class ProcesoDetalleScreen extends StatefulWidget {
  final String processUuid;
  final String? logoUrl;

  const ProcesoDetalleScreen({
    super.key,
    required this.processUuid,
    this.logoUrl,
  });

  @override
  State<ProcesoDetalleScreen> createState() => _ProcesoDetalleScreenState();
}

class _ProcesoDetalleScreenState extends State<ProcesoDetalleScreen> {
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

    final path = '/api/v1/candidates/processes/${widget.processUuid}';

    debugPrint('--- DETALLE PROCESO REQUEST ---');
    debugPrint('URL: $path');

    try {
      final response = await dio.get(path);

      debugPrint('--- DETALLE PROCESO RESPONSE ---');
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
      debugPrint('--- DETALLE PROCESO ERROR ---');
      debugPrint(e.toString());
      setState(() {
        _errorMessage = 'Error de conexión: $e';
        _isLoading = false;
      });
    }
  }

  /// Abre un documento del expediente usando su URL temporal.
  /// NOTA: la ruta exacta de este endpoint no fue confirmada para
  /// candidatos; se asumió el mismo patrón usado en Centros
  /// Evaluadores. Ajustar `path` si el backend usa otra ruta.
  Future<void> _openDocument(String documentUuid) async {
    setState(() => _openingDocId = documentUuid);

    final path =
        '/api/v1/candidates/processes/${widget.processUuid}/documents/$documentUuid/open';

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
          'Expediente del proceso',
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
    final publicReference = data['public_reference'] as String? ?? '';
    final candidate = data['candidate'] as Map<String, dynamic>?;
    final standard = data['competence_standard'] as Map<String, dynamic>?;
    final center = data['center'] as Map<String, dynamic>?;
    final certifyingBody = data['certifying_body'] as Map<String, dynamic>?;
    final status = data['status'] as Map<String, dynamic>?;
    final reviewProgress = data['review_progress'] as Map<String, dynamic>?;
    final payment = data['payment'] as Map<String, dynamic>?;
    final processSteps = data['process_steps'] as Map<String, dynamic>?;
    final documents = (data['documents'] as List<dynamic>?) ?? [];
    final availableFormats =
        (data['available_formats'] as List<dynamic>?) ?? [];

    final centerLogoUrl = center?['logo_url'] as String?;

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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: (centerLogoUrl != null && centerLogoUrl.isNotEmpty)
                        ? Image.network(
                            centerLogoUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholderLogo(),
                          )
                        : _placeholderLogo(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          candidate?['name']?.toString() ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: OCColors.darkBlue,
                          ),
                        ),
                        if (publicReference.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Referencia: $publicReference',
                              style: const TextStyle(
                                color: OCColors.mediumBlue,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          _sectionTitle('Estándar y organismo'),
          _infoCard([
            if (standard != null)
              _infoRow(
                'Estándar',
                '${standard['code'] ?? ''} - ${standard['name'] ?? ''}',
              ),
            if (center != null)
              _infoRow(
                'Centro Evaluador',
                center['legal_name']?.toString() ?? '',
              ),
            if (certifyingBody != null)
              _infoRow(
                'Organismo certificador',
                certifyingBody['legal_name']?.toString() ?? '',
              ),
          ]),

          if (reviewProgress != null) ...[
            const SizedBox(height: 20),
            _sectionTitle('Progreso de revisión'),
            _infoCard([
              _infoRow(
                'Revisados',
                '${reviewProgress['reviewed']} de ${reviewProgress['total']} (${reviewProgress['percent']}%)',
              ),
            ]),
          ],

          if (payment != null) ...[
            const SizedBox(height: 20),
            _sectionTitle('Pago'),
            _infoCard([
              _infoRow('Estatus', payment['status']?['name']?.toString() ?? ''),
            ]),
          ],

          if (processSteps != null) ...[
            const SizedBox(height: 20),
            _sectionTitle('Etapas del proceso'),
            _buildStepsTimeline(
              (processSteps['steps'] as List<dynamic>?) ?? [],
            ),
          ],

          if (availableFormats.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionTitle('Formatos disponibles'),
            ...availableFormats.map((f) {
              final format = f as Map<String, dynamic>;
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
                  leading: const Icon(
                    Icons.picture_as_pdf_outlined,
                    color: OCColors.mediumBlue,
                  ),
                  title: Text(
                    format['name']?.toString() ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: OCColors.darkBlue,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    format['file_name']?.toString() ?? '',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                ),
              );
            }),
          ],

          if (documents.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionTitle('Documentos del expediente'),
            ...documents.map((d) {
              final doc = d as Map<String, dynamic>;
              final verdict = doc['verdict'] as String?;
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
                        : Icon(
                            _iconForVerdict(verdict),
                            color: _colorForVerdict(verdict),
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
                    trailing: verdict != null
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _colorForVerdict(verdict).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _translateVerdict(verdict),
                              style: TextStyle(
                                color: _colorForVerdict(verdict),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : Icon(
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

  Widget _buildStepsTimeline(List<dynamic> steps) {
    return Column(
      children: steps.map((s) {
        final step = s as Map<String, dynamic>;
        final statusCode = step['status'] as String?;
        final name = step['name']?.toString() ?? '';
        final reason = step['reason']?.toString() ?? '';
        final number = step['number']?.toString() ?? '';

        Color color;
        IconData icon;
        switch (statusCode) {
          case 'completed':
            color = const Color(0xFF00796B);
            icon = Icons.check_circle;
            break;
          case 'in_progress':
            color = OCColors.mediumBlue;
            icon = Icons.hourglass_top;
            break;
          case 'blocked':
            color = Colors.grey;
            icon = Icons.lock_outline;
            break;
          default:
            color = Colors.orange.shade800;
            icon = Icons.radio_button_unchecked;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: color.withOpacity(0.15),
                    child: Icon(icon, size: 16, color: color),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: OCColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$number. $name',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: OCColors.darkBlue,
                        ),
                      ),
                      if (reason.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            reason,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
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

  String _translateVerdict(String verdict) {
    switch (verdict) {
      case 'valid':
        return 'VÁLIDO';
      case 'invalid':
        return 'INVÁLIDO';
      case 'pending':
        return 'PENDIENTE';
      default:
        return verdict.toUpperCase();
    }
  }

  IconData _iconForVerdict(String? verdict) {
    switch (verdict) {
      case 'valid':
        return Icons.check_circle;
      case 'invalid':
        return Icons.cancel;
      default:
        return Icons.description_outlined;
    }
  }

  Color _colorForVerdict(String? verdict) {
    switch (verdict) {
      case 'valid':
        return const Color(0xFF00796B);
      case 'invalid':
        return const Color(0xFFC62828);
      default:
        return OCColors.mediumBlue;
    }
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

  Widget _placeholderLogo() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: OCColors.cyan.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.apartment, color: OCColors.mediumBlue, size: 28),
    );
  }
}
