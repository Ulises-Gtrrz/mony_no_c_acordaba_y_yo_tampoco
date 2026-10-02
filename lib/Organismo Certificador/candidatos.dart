import 'package:flutter/material.dart';
import '../main.dart';
import 'proceso_candidatos.dart';

// PALETA OC MAX (misma que en CentroEvaluadorDetalleScreen)
class OCColors {
  static const darkBlue = Color(0xFF0A2342);
  static const mediumBlue = Color(0xFF1B6CA8);
  static const cyan = Color(0xFF38C9D6);
  static const bgLight = Color(0xFFF5F7FA);
  static const cardBorder = Color(0xFFE1E8ED);
}

class CandidatosScreen extends StatefulWidget {
  final String? logoUrl;

  const CandidatosScreen({super.key, this.logoUrl});

  @override
  State<CandidatosScreen> createState() => _CandidatosScreenState();
}

class _CandidatosScreenState extends State<CandidatosScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  bool _isLoadingProfile = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchCandidatos();
  }

  Future<void> _fetchCandidatos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    debugPrint('--- CANDIDATOS REQUEST ---');
    debugPrint(
      'URL: https://ocmax.mx/api/v1/candidates/requests/get?page=1&per_page=15',
    );

    try {
      final response = await dio.get(
        '/api/v1/candidates/requests/get',
        queryParameters: {'page': 1, 'per_page': 15},
      );

      debugPrint('--- CANDIDATOS RESPONSE ---');
      debugPrint('Status code: ${response.statusCode}');
      debugPrint('Body: ${response.data}');

      final body = response.data as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> data = body['data'] as List<dynamic>;
        setState(() {
          _items = data.cast<Map<String, dynamic>>();
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
      debugPrint('--- CANDIDATOS ERROR ---');
      debugPrint(e.toString());
      setState(() {
        _errorMessage = 'Error de conexión: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _showCandidateProfile(String candidateUuid) async {
    setState(() => _isLoadingProfile = true);

    final path = '/api/v1/candidates/$candidateUuid/profile';

    debugPrint('--- PERFIL CANDIDATO REQUEST ---');
    debugPrint('URL: $path');

    try {
      final response = await dio.get(path);

      debugPrint('--- PERFIL CANDIDATO RESPONSE ---');
      debugPrint('Status code: ${response.statusCode}');
      debugPrint('Body: ${response.data}');

      final body = response.data as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        if (mounted) _openProfileDialog(data);
      } else if (response.statusCode == 401) {
        await clearSession();
        _showSnack('Tu sesión expiró. Vuelve a iniciar sesión.');
      } else {
        _showSnack(body['message'] ?? 'No se pudo obtener el expediente');
      }
    } catch (e) {
      debugPrint('--- PERFIL CANDIDATO ERROR ---');
      debugPrint(e.toString());
      _showSnack('Error de conexión: $e');
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Extrae el uuid del proceso a partir de una entrada de `evaluations`
  /// en la lista de candidatos.
  ///
  /// NOTA: el endpoint `/api/v1/candidates/requests/get` no fue
  /// confirmado con un ejemplo de JSON para el campo exacto que trae el
  /// uuid del proceso dentro de cada evaluación. Se intentan varias
  /// llaves comunes (`process_uuid`, `uuid`, `process.uuid`). Si tu
  /// backend usa otro nombre, ajústalo aquí.
  String? _processUuidFrom(Map<String, dynamic> evaluation) {
    final direct =
        evaluation['process_uuid'] ??
        evaluation['request_uuid'] ??
        evaluation['uuid'];
    if (direct != null) return direct.toString();

    final nestedProcess = evaluation['process'] as Map<String, dynamic>?;
    if (nestedProcess != null && nestedProcess['uuid'] != null) {
      return nestedProcess['uuid'].toString();
    }
    return null;
  }

  void _openProceso(String processUuid) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProcesoDetalleScreen(
          processUuid: processUuid,
          logoUrl: widget.logoUrl,
          esRevisor: true,
        ),
      ),
    );
  }

  void _openProfileDialog(Map<String, dynamic> data) {
    final name = data['name'] as String? ?? '';
    final email = data['email'] as String? ?? '';
    final curp = data['curp'] as String? ?? '';
    final phone = data['phone'] as String? ?? '';
    final rfc = data['rfc'] as String? ?? '';
    final birthDate = data['birth_date'] as String? ?? '';

    final nationality = data['nationality'] as Map<String, dynamic>?;
    final birthState = data['birth_state'] as Map<String, dynamic>?;
    final educationLevel = data['education_level'] as Map<String, dynamic>?;

    final address = data['address'] as Map<String, dynamic>?;
    final documents = (data['documents'] as List<dynamic>?) ?? [];
    final processes = (data['processes'] as List<dynamic>?) ?? [];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 600, maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ENCABEZADO
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: OCColors.darkBlue,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: OCColors.cyan.withOpacity(0.25),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                ),

                // CONTENIDO SCROLLEABLE
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _dialogSectionTitle('Datos personales'),
                        _dialogRow('CURP', curp),
                        _dialogRow('RFC', rfc),
                        _dialogRow('Correo', email),
                        _dialogRow('Teléfono', phone),
                        _dialogRow('Fecha de nacimiento', birthDate),
                        if (nationality != null)
                          _dialogRow(
                            'Nacionalidad',
                            nationality['name']?.toString() ?? '',
                          ),
                        if (birthState != null)
                          _dialogRow(
                            'Estado de nacimiento',
                            birthState['name']?.toString() ?? '',
                          ),
                        if (educationLevel != null)
                          _dialogRow(
                            'Escolaridad',
                            educationLevel['name']?.toString() ?? '',
                          ),

                        if (address != null) ...[
                          const SizedBox(height: 12),
                          _dialogSectionTitle('Domicilio'),
                          _dialogRow(
                            'Calle',
                            '${address['street'] ?? ''} #${address['ext_num'] ?? ''}'
                                '${address['int_num'] != null ? ' Int. ${address['int_num']}' : ''}',
                          ),
                          _dialogRow(
                            'Colonia',
                            address['neighborhood']?.toString() ?? '',
                          ),
                          _dialogRow(
                            'Localidad',
                            '${address['locality'] ?? ''}, ${address['municipality'] ?? ''}',
                          ),
                          _dialogRow(
                            'Estado',
                            address['state']?.toString() ?? '',
                          ),
                          _dialogRow(
                            'C.P.',
                            address['zip_code']?.toString() ?? '',
                          ),
                        ],

                        if (processes.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _dialogSectionTitle('Procesos de evaluación'),
                          ...processes.map((p) {
                            final proc = p as Map<String, dynamic>;
                            final processUuid = proc['uuid']?.toString();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: OCColors.bgLight,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: OCColors.cardBorder,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      proc['standard']?.toString() ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: OCColors.darkBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      proc['ce_ei']?.toString() ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      proc['request_status']?.toString() ?? '',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: OCColors.mediumBlue,
                                      ),
                                    ),
                                    if (processUuid != null) ...[
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            Navigator.of(
                                              context,
                                            ).pop(); // cierra el diálogo
                                            _openProceso(processUuid);
                                          },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                OCColors.mediumBlue,
                                            side: const BorderSide(
                                              color: OCColors.mediumBlue,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.folder_open,
                                            size: 16,
                                          ),
                                          label: const Text('Ver expediente'),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],

                        if (documents.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _dialogSectionTitle('Documentos'),
                          ...documents.map((d) {
                            final doc = d as Map<String, dynamic>;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.description_outlined,
                                    size: 18,
                                    color: OCColors.mediumBlue,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      doc['type_name']?.toString() ?? '',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dialogSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: OCColors.mediumBlue,
        ),
      ),
    );
  }

  Widget _dialogRow(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
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
          'Candidatos',
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
                onPressed: _fetchCandidatos,
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

    if (_items.isEmpty) {
      return const Center(child: Text('No hay candidatos disponibles'));
    }

    return RefreshIndicator(
      onRefresh: _fetchCandidatos,
      color: OCColors.mediumBlue,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _items.length,
        itemBuilder: (context, index) => _buildCard(_items[index]),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final uuid = item['uuid'] as String?;
    final name = item['name'] as String? ?? '';
    final curp = item['curp'] as String? ?? '';
    final submittedAt = item['submitted_at'] as String? ?? '';
    final evaluations = (item['evaluations'] as List<dynamic>?) ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: OCColors.cardBorder, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: (uuid == null || _isLoadingProfile)
            ? null
            : () => _showCandidateProfile(uuid),
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
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
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
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: OCColors.darkBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'CURP: $curp',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        if (submittedAt.isNotEmpty)
                          Text(
                            'Enviado: $submittedAt',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_isLoadingProfile)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),

              if (evaluations.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: OCColors.cardBorder),
                const SizedBox(height: 10),
                ...evaluations.map((e) {
                  final evaluation = e as Map<String, dynamic>;
                  final standard = evaluation['standard']?.toString() ?? '';
                  final ceEi = evaluation['ce_ei']?.toString() ?? '';
                  final statusName =
                      evaluation['request_status']?.toString() ?? '';
                  final statusCode = evaluation['request_status_code']
                      ?.toString();
                  final processUuid = _processUuidFrom(evaluation);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    standard,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: OCColors.darkBlue,
                                    ),
                                  ),
                                  if (ceEi.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        ceEi,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (statusName.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
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
                        if (processUuid != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _openProceso(processUuid),
                              style: TextButton.styleFrom(
                                foregroundColor: OCColors.mediumBlue,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(Icons.folder_open, size: 14),
                              label: const Text(
                                'Ver proceso',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
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
