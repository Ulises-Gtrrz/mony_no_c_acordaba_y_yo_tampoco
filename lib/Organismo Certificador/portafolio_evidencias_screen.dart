import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'candidatos.dart'; // Asegúrate de que esta ruta sea correcta
import '../main.dart'; // Asegúrate de que esta ruta sea correcta

class PortafolioEvidenciasScreen extends StatefulWidget {
  final String processUuid;
  final String? logoUrl;

  const PortafolioEvidenciasScreen({
    super.key,
    required this.processUuid,
    this.logoUrl,
  });

  @override
  State<PortafolioEvidenciasScreen> createState() =>
      _PortafolioEvidenciasScreenState();
}

class _PortafolioEvidenciasScreenState
    extends State<PortafolioEvidenciasScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _errorMessage;
  String? _openingFileUuid;
  bool _isSubmitting = false;
  bool _isLoadingConsolidated = false;

  @override
  void initState() {
    super.initState();
    _fetchPortafolio();
  }

  // --- LÓGICA (Sin cambios funcionales, solo limpieza visual en UI) ---

  Future<void> _submitForReview() async {
    setState(() => _isSubmitting = true);
    final path =
        '/api/v1/candidates/processes/${widget.processUuid}/portfolio/submit';
    debugPrint('--- ENVIAR A REVISION REQUEST --- URL: $path');

    try {
      final response = await dio.post(path);
      final body = response.data as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        setState(() => _data = body['data'] as Map<String, dynamic>);
        _showSnack(
          body['message']?.toString() ?? 'Portafolio enviado a revisión',
        );
      } else if (response.statusCode == 401) {
        await clearSession();
        _showSnack('Tu sesión expiró. Vuelve a iniciar sesión.');
      } else if (response.statusCode == 409) {
        _showSnack(
          body['message']?.toString() ?? 'El portafolio ya cambió de estado',
        );
        await _fetchPortafolio();
      } else {
        _showSnack(
          body['message']?.toString() ?? 'No se pudo enviar a revisión',
        );
      }
    } catch (e) {
      debugPrint('--- ENVIAR A REVISION ERROR --- $e');
      _showSnack('Error de conexión: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _viewConsolidatedPortfolio() async {
    setState(() => _isLoadingConsolidated = true);
    final path =
        '/api/v1/candidates/processes/${widget.processUuid}/portfolio/consolidated';

    try {
      final response = await dio.post(path);
      final body = response.data as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        if (data['status'] == 'ready') {
          final temporaryUrl = data['temporary_url'] as String?;
          if (temporaryUrl != null && temporaryUrl.isNotEmpty) {
            final launched = await launchUrl(
              Uri.parse(temporaryUrl),
              mode: LaunchMode.externalApplication,
            );
            if (!launched && mounted) _showSnack('No se pudo abrir el PDF');
          } else {
            _showSnack('No se encontró la url del PDF');
          }
        } else {
          final blockers = (data['blockers'] as List<dynamic>?) ?? [];
          _showSnack(
            blockers.isNotEmpty
                ? blockers.join(', ')
                : 'El PDF consolidado aún no está disponible',
          );
        }
      } else if (response.statusCode == 401) {
        await clearSession();
        _showSnack('Tu sesión expiró.');
      } else {
        _showSnack(body['message'] ?? 'No se pudo generar el PDF');
      }
    } catch (e) {
      _showSnack('Error de conexión: $e');
    } finally {
      if (mounted) setState(() => _isLoadingConsolidated = false);
    }
  }

  Future<void> _fetchPortafolio() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final path = '/api/v1/candidates/processes/${widget.processUuid}/portfolio';

    try {
      final response = await dio.get(path);
      final body = response.data as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        setState(() {
          _data = body['data'] as Map<String, dynamic>;
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        await clearSession();
        setState(() {
          _errorMessage = 'Sesión expirada.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = body['message'] ?? 'Error al cargar';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión';
        _isLoading = false;
      });
    }
  }

  Future<void> _openFile(String fileUuid) async {
    setState(() => _openingFileUuid = fileUuid);
    final path =
        '/api/v1/candidates/processes/${widget.processUuid}/portfolio/files/$fileUuid/open';

    try {
      final response = await dio.post(path);
      final body = response.data as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        final temporaryUrl = data['temporary_url'] as String?;
        if (temporaryUrl != null && temporaryUrl.isNotEmpty) {
          final launched = await launchUrl(
            Uri.parse(temporaryUrl),
            mode: LaunchMode.externalApplication,
          );
          if (!launched && mounted) _showSnack('No se pudo abrir el archivo');
        } else {
          _showSnack('URL no disponible');
        }
      } else if (response.statusCode == 401) {
        await clearSession();
      } else {
        _showSnack(body['message'] ?? 'Error al abrir archivo');
      }
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _openingFileUuid = null);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // --- INTERFAZ DE USUARIO MEJORADA ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Fondo gris muy suave moderno
      appBar: AppBar(
        backgroundColor: OCColors.darkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Mi Portafolio',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        actions: [
          if (widget.logoUrl != null && widget.logoUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.logoUrl!,
                  height: 32,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildSubmitBar(),
    );
  }

  Widget? _buildSubmitBar() {
    if (_isLoading || _errorMessage != null || _data == null) return null;

    final capabilities = _data!['capabilities'] as Map<String, dynamic>? ?? {};
    final canSubmit = capabilities['can_submit'] as bool? ?? false;
    final canViewConsolidated =
        capabilities['can_view_consolidated_pdf'] as bool? ?? false;
    final blockers = (capabilities['blockers'] as List<dynamic>?) ?? [];
    final statusCode = (_data!['status'] as Map<String, dynamic>?)?['code'];
    final alreadySubmitted = statusCode != 'in_integration';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16,
      ), // SafeArea handled by padding usually or wrap in SafeArea
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canViewConsolidated)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoadingConsolidated
                      ? null
                      : _viewConsolidatedPortfolio,
                  icon: _isLoadingConsolidated
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Ver PDF Consolidado'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OCColors.mediumBlue,
                    side: BorderSide(
                      color: OCColors.mediumBlue.withOpacity(0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

            if (canViewConsolidated) const SizedBox(height: 10),

            if (!alreadySubmitted)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (canSubmit && !_isSubmitting)
                      ? _submitForReview
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canSubmit
                        ? OCColors.mediumBlue
                        : Colors.grey.shade300,
                    disabledBackgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    elevation: canSubmit ? 2 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          canSubmit
                              ? 'Enviar a Revisión'
                              : (blockers.isNotEmpty
                                    ? blockers.first.toString()
                                    : 'Completa las evidencias'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      (_data!['status'] as Map<String, dynamic>?)?['label']
                              ?.toString() ??
                          'Enviado',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
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
              Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchPortafolio,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OCColors.mediumBlue,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final data = _data!;
    final status = data['status'] as Map<String, dynamic>?;
    final progress = data['progress'] as Map<String, dynamic>?;
    final process = data['process'] as Map<String, dynamic>?;
    final candidate = process?['candidate'] as Map<String, dynamic>?;
    final standard = process?['competence_standard'] as Map<String, dynamic>?;
    final sections = (data['sections'] as List<dynamic>?) ?? [];
    final timeline = (data['timeline'] as List<dynamic>?) ?? [];

    return RefreshIndicator(
      onRefresh: _fetchPortafolio,
      color: OCColors.mediumBlue,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24), // Espacio extra al final
        children: [
          // HEADER CARD
          _buildHeaderCard(candidate, standard, status, progress),

          const SizedBox(height: 20),

          // TIMELINE (Si existe)
          if (timeline.isNotEmpty) _buildTimelineCard(timeline),

          if (timeline.isNotEmpty) const SizedBox(height: 20),

          // SECTIONS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Evidencias Requeridas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: OCColors.darkBlue,
              ),
            ),
          ),
          const SizedBox(height: 10),

          ...sections.map((s) {
            final section = s as Map<String, dynamic>;
            return _buildSectionCard(section);
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(
    Map<String, dynamic>? candidate,
    Map<String, dynamic>? standard,
    Map<String, dynamic>? status,
    Map<String, dynamic>? progress,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [OCColors.darkBlue, OCColors.mediumBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: OCColors.mediumBlue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    candidate?['name']?.toString() ?? 'Candidato',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (status != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status['label']?.toString() ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (standard != null) ...[
              const SizedBox(height: 8),
              Text(
                '${standard['code'] ?? ''} • ${standard['name'] ?? ''}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                ),
              ),
            ],
            if (progress != null) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value:
                            ((progress['percent'] as num?)?.toDouble() ?? 0) /
                            100,
                        minHeight: 10,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${progress['percent']}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${progress['delivered']} de ${progress['total']} entregadas',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(List<dynamic> timeline) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, size: 18, color: OCColors.mediumBlue),
                const SizedBox(width: 8),
                const Text(
                  'Historial de Actividad',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: OCColors.darkBlue,
                  ),
                ),
              ],
            ),
            const Divider(height: 20, thickness: 1),
            ...timeline.map((t) {
              final entry = t as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: OCColors.mediumBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry['label']?.toString() ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            [
                              if (entry['actor_role'] != null)
                                entry['actor_role'],
                              if (entry['occurred_at'] != null)
                                _formatTimelineDate(entry['occurred_at']),
                            ].join(' • '),
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                            ),
                          ),
                          if (entry['note'] != null &&
                              (entry['note'] as String).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                entry['note'],
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
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
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(Map<String, dynamic> section) {
    final items = (section['items'] as List<dynamic>?) ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: OCColors.mediumBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${section['number']}',
                    style: TextStyle(
                      color: OCColors.mediumBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section['title'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: OCColors.darkBlue,
                        ),
                      ),
                      if ((section['description'] as String?)?.isNotEmpty ==
                          true)
                        Text(
                          section['description'].toString(),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${section['delivered']}/${section['total']}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          // Items List
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: items
                  .map((it) => _buildModernItemCard(it as Map<String, dynamic>))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernItemCard(Map<String, dynamic> item) {
    final statusCode = item['status']?['code']?.toString();
    final verdict = item['review']?['verdict'] as String?;
    final files = (item['files'] as List<dynamic>?) ?? [];
    final required = item['required'] as bool? ?? false;
    final statusColor = _colorForItemStatus(statusCode, verdict);
    final bgColor = statusColor.withOpacity(0.08);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _iconForItemStatus(statusCode, verdict),
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item['numbering'] ?? ''} ${item['name'] ?? ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: OCColors.darkBlue,
                      ),
                    ),
                    if (!required)
                      Text(
                        'Opcional',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  verdict != null
                      ? _translateVerdict(verdict)
                      : (item['status']?['label'] ?? ''),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          if (files.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: files.map((f) {
                  final file = f as Map<String, dynamic>;
                  final fileUuid = file['uuid'] as String?;
                  final isOpening = _openingFileUuid == fileUuid;

                  return InkWell(
                    onTap: fileUuid != null && !isOpening
                        ? () => _openFile(fileUuid!)
                        : null,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.attach_file,
                            size: 16,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              file['file_name']?.toString() ?? '',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isOpening)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: OCColors.mediumBlue,
                              ),
                            )
                          else if (fileUuid != null)
                            Icon(
                              Icons.open_in_new,
                              size: 14,
                              color: OCColors.mediumBlue,
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          if (item['review']?['rejection_note'] != null &&
              (item['review']!['rejection_note'] as String).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Nota: ${item['review']['rejection_note']}',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // --- HELPERS VISUALES ---

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

  IconData _iconForItemStatus(String? statusCode, String? verdict) {
    if (verdict == 'valid') return Icons.check;
    if (verdict == 'invalid') return Icons.close;
    switch (statusCode) {
      case 'ready':
        return Icons.check_circle_outline;
      case 'pending':
        return Icons.access_time;
      case 'blocked':
        return Icons.lock_outline;
      default:
        return Icons.description_outlined;
    }
  }

  Color _colorForItemStatus(String? statusCode, String? verdict) {
    if (verdict == 'valid') return const Color(0xFF00897B); // Teal más moderno
    if (verdict == 'invalid')
      return const Color(0xFFD32F2F); // Rojo más vibrante
    switch (statusCode) {
      case 'ready':
        return const Color(0xFF00897B);
      case 'pending':
        return const Color(0xFFF57C00); // Naranja material
      case 'blocked':
        return Colors.grey.shade600;
      default:
        return OCColors.mediumBlue;
    }
  }

  String _formatTimelineDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }
}
