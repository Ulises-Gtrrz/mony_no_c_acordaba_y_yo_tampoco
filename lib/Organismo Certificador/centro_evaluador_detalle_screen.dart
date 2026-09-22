import 'package:flutter/material.dart';
import '../main.dart';
import 'package:url_launcher/url_launcher.dart';

// PALETA OC MAX
class OCColors {
  static const darkBlue = Color(0xFF0A2342); // Principal / Textos fuertes
  static const mediumBlue = Color(0xFF1B6CA8); // Secundario / Títulos / Acentos
  static const cyan = Color(0xFF38C9D6); // Acento / Chips / Detalles
  static const bgLight = Color(0xFFF5F7FA); // Fondo general suave
  static const cardBorder = Color(0xFFE1E8ED); // Bordes de tarjetas
}

class CentroEvaluadorDetalleScreen extends StatefulWidget {
  final String applicationUuid;
  final String? logoUrl;

  const CentroEvaluadorDetalleScreen({
    super.key,
    required this.applicationUuid,
    this.logoUrl,
  });

  @override
  State<CentroEvaluadorDetalleScreen> createState() =>
      _CentroEvaluadorDetalleScreenState();
}

class _CentroEvaluadorDetalleScreenState
    extends State<CentroEvaluadorDetalleScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _errorMessage;
  String? _openingDocId;

  @override
  void initState() {
    super.initState();
    _fetchDetalle();
  }

  Future<void> _openDocument(String documentUuid) async {
    setState(() => _openingDocId = documentUuid);

    final path =
        '/api/v1/centers-evaluators/requests/${widget.applicationUuid}/documents/$documentUuid/open';

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

  Future<void> _fetchDetalle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final path =
        '/api/v1/centers-evaluators/requests/${widget.applicationUuid}';

    debugPrint('--- DETALLE CE/EI REQUEST ---');
    debugPrint('URL: $path');

    try {
      final response = await dio.get(path);

      debugPrint('--- DETALLE CE/EI RESPONSE ---');
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
      debugPrint('--- DETALLE CE/EI ERROR ---');
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
          'Detalle de la solicitud',
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
    final legalName = data['legal_name'] as String? ?? '';
    final commercialName = data['commercial_name'] as String?;
    final rfc = data['rfc'] as String? ?? '';
    final type = data['type'] as String? ?? '';
    final registrationKey = data['registration_key'] as String? ?? '';

    final status = data['status'] as Map<String, dynamic>?;
    final statusName = status?['name'] as String? ?? '';

    final operationalStatus =
        data['operational_status'] as Map<String, dynamic>?;
    final operationalStatusName = operationalStatus?['name'] as String?;

    final competenceStandard =
        data['competence_standard'] as Map<String, dynamic>?;
    final standardCode = competenceStandard?['code'] as String?;
    final standardName = competenceStandard?['name'] as String?;

    final certifyingBody = data['certifying_body'] as Map<String, dynamic>?;
    final certifyingBodyName = certifyingBody?['legal_name'] as String?;

    final contract = data['contract'] as Map<String, dynamic>?;
    final validFrom = contract?['valid_from'] as String?;
    final validUntil = contract?['valid_until'] as String?;

    final applicant = data['applicant'] as Map<String, dynamic>?;
    final applicantName = applicant?['name'] as String?;
    final applicantEmail = applicant?['email'] as String?;

    final address = data['address'] as Map<String, dynamic>?;
    final logo = data['logo'] as Map<String, dynamic>?;
    final logoUrl = logo?['url'] as String?;

    final contacts = (data['contacts'] as List<dynamic>?) ?? [];
    final documents = (data['documents'] as List<dynamic>?) ?? [];

    return RefreshIndicator(
      onRefresh: _fetchDetalle,
      color: OCColors.mediumBlue,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ENCABEZADO CON TARJETA DESTACADA
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
                    child: (logoUrl != null && logoUrl.isNotEmpty)
                        ? Image.network(
                            logoUrl,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholderLogo(),
                          )
                        : _placeholderLogo(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          commercialName?.isNotEmpty == true
                              ? commercialName!
                              : legalName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: OCColors.darkBlue,
                          ),
                        ),
                        if (commercialName?.isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              legalName,
                              style: const TextStyle(
                                color: OCColors.mediumBlue,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (statusName.isNotEmpty)
                              Chip(
                                label: Text(statusName),
                                backgroundColor: OCColors.cyan.withOpacity(
                                  0.18,
                                ),
                                labelStyle: const TextStyle(
                                  color: OCColors.darkBlue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            if (operationalStatusName != null &&
                                operationalStatusName.isNotEmpty)
                              Chip(
                                label: Text(operationalStatusName),
                                backgroundColor: const Color(
                                  0xFF00796B,
                                ).withOpacity(0.12),
                                labelStyle: const TextStyle(
                                  color: Color(0xFF00796B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          _sectionTitle('Información general'),
          _infoCard([
            _infoRow('RFC', rfc),
            _infoRow('Tipo', type),
            _infoRow('Clave de registro', registrationKey),
            if (standardCode != null || standardName != null)
              _infoRow(
                'Estándar',
                '${standardCode ?? ''} ${standardName ?? ''}',
              ),
            if (certifyingBodyName != null)
              _infoRow('Organismo certificador', certifyingBodyName),
          ]),

          if (validFrom != null || validUntil != null) ...[
            const SizedBox(height: 20),
            _sectionTitle('Vigencia del contrato'),
            _infoCard([
              if (validFrom != null) _infoRow('Desde', validFrom),
              if (validUntil != null) _infoRow('Hasta', validUntil),
            ]),
          ],

          if (applicantName != null || applicantEmail != null) ...[
            const SizedBox(height: 20),
            _sectionTitle('Solicitante'),
            _infoCard([
              if (applicantName != null) _infoRow('Nombre', applicantName),
              if (applicantEmail != null) _infoRow('Correo', applicantEmail),
            ]),
          ],

          if (address != null) ...[
            const SizedBox(height: 20),
            _sectionTitle('Domicilio'),
            _infoCard([
              _infoRow(
                'Calle',
                '${address['street'] ?? ''} #${address['ext_num'] ?? ''}'
                    '${address['int_num'] != null ? ' Int. ${address['int_num']}' : ''}',
              ),
              _infoRow('Colonia', address['neighborhood']?.toString() ?? ''),
              _infoRow(
                'Localidad',
                '${address['locality'] ?? ''}, ${address['municipality'] ?? ''}',
              ),
              _infoRow('Estado', address['state']?.toString() ?? ''),
              _infoRow('C.P.', address['zip_code']?.toString() ?? ''),
            ]),
          ],

          if (contacts.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionTitle('Contactos'),
            ...contacts.map((c) {
              final contact = c as Map<String, dynamic>;
              return _infoCard([
                _infoRow('Nombre', contact['full_name']?.toString() ?? ''),
                _infoRow('Tipo', _translateContactType(contact['type'])),
                _infoRow('Correo', contact['email']?.toString() ?? ''),
                _infoRow('Teléfono', contact['phone']?.toString() ?? ''),
              ]);
            }),
          ],

          if (documents.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionTitle('Documentos'),
            if (documents.isNotEmpty) ...[
              const SizedBox(height: 20),
              _sectionTitle('Documentos'),
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
                    side: BorderSide(color: OCColors.cardBorder, width: 0.5),
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
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          doc['original_name']?.toString() ?? '',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
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
                                color: _colorForVerdict(
                                  verdict,
                                ).withOpacity(0.1),
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
                          : null,
                    ),
                  ),
                );
              }),
            ],
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
        side: BorderSide(color: OCColors.cardBorder, width: 0.5),
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
            width: 130,
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

  String _translateContactType(dynamic type) {
    switch (type) {
      case 'director':
        return 'Director';
      case 'legal_representative':
        return 'Representante legal';
      case 'technical_representative':
        return 'Representante técnico';
      default:
        return type?.toString() ?? '';
    }
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
        return Icons.hourglass_empty;
    }
  }

  Color _colorForVerdict(String? verdict) {
    switch (verdict) {
      case 'valid':
        return const Color(0xFF00796B); // Verde azulado armonioso
      case 'invalid':
        return const Color(0xFFC62828); // Rojo profundo
      default:
        return OCColors.mediumBlue; // Pendiente usa azul medio de la marca
    }
  }

  Widget _placeholderLogo() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: OCColors.cyan.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.apartment, color: OCColors.mediumBlue, size: 32),
    );
  }
}
