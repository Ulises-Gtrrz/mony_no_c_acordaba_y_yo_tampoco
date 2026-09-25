import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../Organismo Certificador/candidatos.dart' show OCColors;

class ProcesoDetalleCandidatoScreen extends StatefulWidget {
  final String processUuid;
  final String? logoUrl;

  const ProcesoDetalleCandidatoScreen({
    super.key,
    required this.processUuid,
    this.logoUrl,
  });

  @override
  State<ProcesoDetalleCandidatoScreen> createState() =>
      _ProcesoDetalleCandidatoScreenState();
}

class _ProcesoDetalleCandidatoScreenState
    extends State<ProcesoDetalleCandidatoScreen> {
  Map<String, dynamic>? _proceso;
  Map<String, dynamic>? _portfolio;
  bool _isLoading = true;
  bool _isLoadingPortfolio = true;
  bool _isLoadingCedula = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProceso();
    _fetchPortfolio();
  }

  Future<void> _fetchProceso() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final url = '/api/v1/candidates/me/processes/${widget.processUuid}';
    debugPrint('--- DETALLE PROCESO REQUEST ---');
    debugPrint('URL: https://ocmax.mx$url');

    try {
      final response = await dio.get(url);

      debugPrint('--- DETALLE PROCESO RESPONSE ---');
      debugPrint('Status code: ${response.statusCode}');
      debugPrint('Body: ${response.data}');

      final body = response.data as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        setState(() {
          _proceso = body['data'] as Map<String, dynamic>;
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
          _errorMessage = body['message'] ?? 'No se pudo obtener el proceso';
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

  Future<void> _fetchPortfolio() async {
    setState(() => _isLoadingPortfolio = true);

    final url =
        '/api/v1/candidates/me/processes/${widget.processUuid}/portfolio';
    debugPrint('--- PORTAFOLIO REQUEST ---');
    debugPrint('URL: https://ocmax.mx$url');

    try {
      final response = await dio.get(url);

      debugPrint('--- PORTAFOLIO RESPONSE ---');
      debugPrint('Status code: ${response.statusCode}');
      debugPrint('Body: ${response.data}');

      final body = response.data as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        setState(() {
          _portfolio = body['data'] as Map<String, dynamic>;
          _isLoadingPortfolio = false;
        });
      } else {
        setState(() => _isLoadingPortfolio = false);
      }
    } catch (e) {
      debugPrint('--- PORTAFOLIO ERROR ---');
      debugPrint(e.toString());
      setState(() => _isLoadingPortfolio = false);
    }
  }

  Future<void> _abrirCedulaEvaluacion() async {
    final delivery = _portfolio?['delivery'] as Map<String, dynamic>?;
    final deliveryUuid = delivery?['uuid']?.toString();

    if (deliveryUuid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay una cédula disponible todavía.')),
      );
      return;
    }

    setState(() => _isLoadingCedula = true);

    final url =
        '/api/v1/candidates/me/processes/${widget.processUuid}/portfolio/deliveries/$deliveryUuid/open';

    debugPrint('--- ABRIR CÉDULA REQUEST ---');
    debugPrint('URL: https://ocmax.mx$url');

    try {
      final response = await dio.get(url);
      final body = response.data as Map<String, dynamic>;

      debugPrint('--- ABRIR CÉDULA RESPONSE ---');
      debugPrint('Status code: ${response.statusCode}');
      debugPrint('Body: $body');

      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        final temporaryUrl = data['temporary_url']?.toString();

        if (temporaryUrl != null && temporaryUrl.isNotEmpty) {
          final uri = Uri.parse(temporaryUrl);
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (!launched && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se pudo abrir el documento.')),
            );
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El documento no está disponible por el momento.'),
            ),
          );
        }
      } else if (response.statusCode == 401) {
        await clearSession();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tu sesión expiró. Vuelve a iniciar sesión.'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                body['message'] ?? 'No se pudo obtener el documento.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('--- ABRIR CÉDULA ERROR ---');
      debugPrint(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoadingCedula = false);
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

  Color _colorForStepStatus(String? status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF00796B);
      case 'in_progress':
        return Colors.orange.shade800;
      case 'blocked':
        return Colors.grey.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  IconData _iconForStepStatus(String? status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.autorenew;
      case 'blocked':
        return Icons.lock_outline;
      default:
        return Icons.radio_button_unchecked;
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
          'Detalle del Proceso',
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
                onPressed: () {
                  _fetchProceso();
                  _fetchPortfolio();
                },
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

    final proceso = _proceso!;
    final standard = proceso['competence_standard'] as Map<String, dynamic>?;
    final center = proceso['center'] as Map<String, dynamic>?;
    final status = proceso['status'] as Map<String, dynamic>?;
    final statusCode = status?['code']?.toString();
    final colorEstado = _colorForStatus(statusCode);
    final publicRef = proceso['public_reference']?.toString() ?? '';

    final steps = proceso['process_steps'] as Map<String, dynamic>?;
    final percent = (steps?['percent'] as num?)?.toInt() ?? 0;
    final stepsList = (steps?['steps'] as List<dynamic>?) ?? [];

    final payment = proceso['payment'] as Map<String, dynamic>?;
    final evaluator = proceso['evaluator'] as Map<String, dynamic>?;
    final evaluationPlan = proceso['evaluation_plan'] as Map<String, dynamic>?;
    final documents = (proceso['documents'] as List<dynamic>?) ?? [];
    final formats = (proceso['available_formats'] as List<dynamic>?) ?? [];

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchProceso();
        await _fetchPortfolio();
      },
      color: OCColors.mediumBlue,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ENCABEZADO
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: OCColors.darkBlue,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  standard?['name']?.toString() ?? 'Estándar sin nombre',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if ((standard?['code'] ?? '').toString().isNotEmpty)
                      standard!['code'].toString(),
                    if (publicRef.isNotEmpty) publicRef,
                  ].join(' · '),
                  style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
                ),
                if (center?['name'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    center!['name'].toString(),
                    style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorEstado.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status?['name']?.toString() ?? '',
                        style: TextStyle(
                          color: colorEstado == const Color(0xFF00796B)
                              ? Colors.greenAccent.shade100
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$percent% completado',
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: percent / 100,
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(OCColors.cyan),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // PASOS DEL PROCESO
          _sectionTitle('Avance del proceso'),
          const SizedBox(height: 10),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: OCColors.cardBorder, width: 0.5),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: stepsList.map((s) {
                  final step = s as Map<String, dynamic>;
                  final stepStatus = step['status']?.toString();
                  final reason = step['reason']?.toString();
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _iconForStepStatus(stepStatus),
                          color: _colorForStepStatus(stepStatus),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${step['number']}. ${step['name'] ?? ''}',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: stepStatus == 'in_progress'
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: stepStatus == 'blocked'
                                      ? Colors.grey.shade500
                                      : OCColors.darkBlue,
                                ),
                              ),
                              if (reason != null && reason.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    reason,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // PORTAFOLIO DE EVIDENCIAS
          _sectionTitle('Portafolio de evidencias'),
          const SizedBox(height: 10),
          _buildPortfolioCard(),

          const SizedBox(height: 20),

          // EVALUADOR Y PLAN
          if (evaluator != null || evaluationPlan != null) ...[
            _sectionTitle('Evaluación'),
            const SizedBox(height: 10),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: OCColors.cardBorder, width: 0.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (evaluator != null) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 18,
                            color: OCColors.mediumBlue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              evaluator['full_name']?.toString() ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: OCColors.darkBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (evaluationPlan?['agreement'] != null) ...[
                      _infoRow(
                        Icons.place_outlined,
                        'Sede de evaluación',
                        evaluationPlan!['agreement']['evaluation_location']
                                ?.toString() ??
                            '',
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (evaluationPlan?['scheduled_at'] != null)
                      _infoRow(
                        Icons.event_outlined,
                        'Fecha programada',
                        _formatDate(
                          evaluationPlan!['scheduled_at']?.toString(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // PAGO
          if (payment != null) ...[
            _sectionTitle('Pago'),
            const SizedBox(height: 10),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: OCColors.cardBorder, width: 0.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      color: OCColors.mediumBlue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        payment['status']?['name']?.toString() ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: OCColors.darkBlue,
                        ),
                      ),
                    ),
                    if (payment['receipt']?['original_name'] != null)
                      Text(
                        payment['receipt']['original_name'].toString(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // DOCUMENTOS
          if (documents.isNotEmpty) ...[
            _sectionTitle('Documentos'),
            const SizedBox(height: 10),
            ...documents.map((d) {
              final doc = d as Map<String, dynamic>;
              final verdict = doc['verdict']?.toString();
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(
                    color: OCColors.cardBorder,
                    width: 0.5,
                  ),
                ),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    verdict == 'valid'
                        ? Icons.check_circle_outline
                        : Icons.insert_drive_file_outlined,
                    color: verdict == 'valid'
                        ? const Color(0xFF00796B)
                        : OCColors.mediumBlue,
                  ),
                  title: Text(
                    doc['type_name']?.toString() ?? '',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    doc['original_name']?.toString() ?? '',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
              );
            }),
            const SizedBox(height: 10),
          ],

          // FORMATOS DISPONIBLES
          if (formats.isNotEmpty) ...[
            _sectionTitle('Formatos disponibles'),
            const SizedBox(height: 10),
            ...formats.map((f) {
              final format = f as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(
                    color: OCColors.cardBorder,
                    width: 0.5,
                  ),
                ),
                child: ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.picture_as_pdf_outlined,
                    color: OCColors.mediumBlue,
                  ),
                  title: Text(
                    format['name']?.toString() ?? '',
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: format['downloadable'] == true
                      ? Icon(
                          Icons.download_outlined,
                          color: OCColors.mediumBlue,
                          size: 20,
                        )
                      : null,
                  onTap: format['downloadable'] == true
                      ? () {
                          // Aquí puedes implementar la descarga real
                        }
                      : null,
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildPortfolioCard() {
    if (_isLoadingPortfolio) {
      return const Card(
        elevation: 1,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: OCColors.mediumBlue,
              ),
            ),
          ),
        ),
      );
    }

    if (_portfolio == null) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: OCColors.cardBorder, width: 0.5),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No se pudo obtener el estatus del portafolio.'),
        ),
      );
    }

    final status = _portfolio!['status'] as Map<String, dynamic>?;
    final label = status?['label']?.toString() ?? '';
    final lockedMessage = _portfolio!['locked_message']?.toString();
    final contentAvailable = _portfolio!['content_available'] == true;
    final delivery = _portfolio!['delivery'] as Map<String, dynamic>?;

    Color statusColor;
    switch (status?['code']?.toString()) {
      case 'completed':
      case 'delivered':
        statusColor = const Color(0xFF00796B);
        break;
      case 'in_integration':
        statusColor = Colors.orange.shade800;
        break;
      default:
        statusColor = OCColors.mediumBlue;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: OCColors.cardBorder, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.folder_shared_outlined, color: statusColor),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            if (!contentAvailable && lockedMessage != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lockedMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (delivery != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: OCColors.cardBorder),
              const SizedBox(height: 10),
              _infoRow(
                Icons.check_circle_outline,
                'Estatus de entrega',
                delivery['status']?['label']?.toString() ?? '',
              ),
              if (delivery['delivered_at'] != null) ...[
                const SizedBox(height: 8),
                _infoRow(
                  Icons.schedule_outlined,
                  'Entregado',
                  _formatDate(delivery['delivered_at']?.toString()),
                ),
              ],
              if (delivery['can_open'] == true) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoadingCedula ? null : _abrirCedulaEvaluacion,
                    icon: _isLoadingCedula
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: Text(
                      _isLoadingCedula
                          ? 'Abriendo...'
                          : 'Ver Cédula de Evaluación',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OCColors.mediumBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: OCColors.darkBlue,
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: OCColors.mediumBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              Text(
                value.isEmpty ? '—' : value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: OCColors.darkBlue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '—';
    try {
      final date = DateTime.parse(isoDate);
      const meses = [
        'ene',
        'feb',
        'mar',
        'abr',
        'may',
        'jun',
        'jul',
        'ago',
        'sep',
        'oct',
        'nov',
        'dic',
      ];
      final hora = date.hour.toString().padLeft(2, '0');
      final min = date.minute.toString().padLeft(2, '0');
      return '${date.day} ${meses[date.month - 1]} ${date.year}, $hora:$min';
    } catch (_) {
      return isoDate;
    }
  }
}
