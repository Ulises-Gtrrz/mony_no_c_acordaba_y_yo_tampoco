import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../main.dart';
import '../../Organismo Certificador/candidatos.dart' show OCColors;

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
  bool _isSaving = false;
  bool _isApproving = false;
  bool _isRejecting = false;
  int _reviewVersion = 0;

  // --- Cambios pendientes de guardar: uno por documento (clave = item_uuid) ---
  final Map<String, _RevisionArchivo> _revisiones = {};

  @override
  void initState() {
    super.initState();
    _fetchPortafolio();
  }

  String? _itemUuid(Map<String, dynamic> item) =>
      (item['uuid'] ?? item['item_uuid'])?.toString();

  Map<String, dynamic>? _findItem(String itemUuid) {
    final sections = (_data?['sections'] as List<dynamic>?) ?? [];
    for (final sec in sections) {
      for (final it in (sec['items'] as List<dynamic>? ?? [])) {
        if (it['uuid'] == itemUuid) return it as Map<String, dynamic>;
      }
    }
    return null;
  }

  /// Panel inferior con los checks, independiente para cada documento.
  Future<void> _mostrarRevisionSheet(Map<String, dynamic> item) async {
    if (!mounted) return;
    final itemUuid = _itemUuid(item);
    if (itemUuid == null) {
      _showSnack('No se encontró el identificador del documento');
      return;
    }
    final fileName = '${item['numbering'] ?? ''} ${item['name'] ?? ''}'.trim();

    // Usa lo marcado antes (pendiente) o, si no hay, lo que ya tiene el servidor
    final previa = _revisiones[itemUuid];
    final verdictServidor = item['review']?['verdict'] as String?;
    bool aprobado = previa?.aprobado ?? (verdictServidor == 'valid');
    bool conObservaciones =
        previa?.conObservaciones ??
        (verdictServidor == 'invalid' || verdictServidor == 'rejected');
    String observaciones =
        previa?.observaciones ??
        (conObservaciones
            ? (item['review']?['rejection_note']?.toString() ?? '')
            : '');
    String? errorText;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Resultado de la revisión',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: OCColors.darkBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Aprobado'),
                      value: aprobado,
                      activeColor: const Color(0xFF00897B),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (value) {
                        setModalState(() {
                          aprobado = value ?? false;
                          if (aprobado) {
                            conObservaciones = false;
                            observaciones = '';
                          }
                          errorText = null;
                        });
                      },
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Con observaciones'),
                      value: conObservaciones,
                      activeColor: const Color(0xFFF57C00),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (value) {
                        setModalState(() {
                          conObservaciones = value ?? false;
                          if (conObservaciones) {
                            aprobado = false;
                          } else {
                            observaciones = '';
                          }
                          errorText = null;
                        });
                      },
                    ),
                    if (conObservaciones)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextFormField(
                          initialValue: observaciones,
                          maxLines: 4,
                          onChanged: (v) => observaciones = v,
                          decoration: const InputDecoration(
                            labelText: 'Observaciones',
                            hintText: 'Escribe tus observaciones...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          errorText!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        final valido =
                            (aprobado || conObservaciones) &&
                            !(conObservaciones && observaciones.trim().isEmpty);
                        if (!valido) {
                          setModalState(() {
                            errorText =
                                'Selecciona una opción y completa las observaciones';
                          });
                          return;
                        }

                        setState(() {
                          _revisiones[itemUuid] = _RevisionArchivo(
                            aprobado: aprobado,
                            conObservaciones: conObservaciones,
                            observaciones: observaciones.trim(),
                          );
                        });
                        Navigator.of(sheetContext).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: OCColors.mediumBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Listo'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _guardarCambios() async {
    if (_revisiones.isEmpty) return;
    setState(() => _isSaving = true);

    final path =
        '/api/v1/candidates/processes/${widget.processUuid}/portfolio/review/progress';

    // El servidor espera la versión ACTUAL (data.review.version) y él la incrementa
    final currentVersion =
        (_data?['review']?['version'] as num?)?.toInt() ?? _reviewVersion;

    final payload = {
      'version': currentVersion,
      'general_note': null,
      'documents': _revisiones.entries
          .map(
            (e) => {
              'item_uuid': e.key,
              'verdict': e.value.aprobado ? 'valid' : 'rejected',
              'rejection_note': e.value.aprobado ? null : e.value.observaciones,
            },
          )
          .toList(),
    };
    debugPrint('--- GUARDAR REVISION --- $path\n$payload');

    try {
      final response = await dio.put(path, data: payload);
      final body = response.data as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        if (mounted) setState(() => _revisiones.clear());
        _showSnack(body['message']?.toString() ?? 'Cambios guardados');
        await _fetchPortafolio(); // trae la nueva versión
      } else if (response.statusCode == 401) {
        await clearSession();
        _showSnack('Tu sesión expiró. Vuelve a iniciar sesión.');
      } else if (response.statusCode == 409) {
        debugPrint('--- 409 BODY --- $body');
        await _fetchPortafolio(silent: true);
        _showSnack('La revisión se actualizó. Vuelve a presionar Guardar.');
      } else if (response.statusCode == 422) {
        debugPrint('--- 422 BODY --- $body');
        final errors = body['errors'];
        String detalle = '';
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          detalle = (first is List && first.isNotEmpty)
              ? first.first.toString()
              : first.toString();
        }
        _showSnack(
          detalle.isNotEmpty
              ? detalle
              : (body['message']?.toString() ?? 'Datos inválidos'),
        );
      } else {
        debugPrint('--- ERROR ${response.statusCode} BODY --- $body');
        _showSnack(body['message']?.toString() ?? 'No se pudo guardar');
      }
    } catch (e) {
      debugPrint('--- GUARDAR REVISION ERROR --- $e');
      _showSnack('Error de conexión: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _aprobarPortafolio() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aprobar portafolio'),
        content: const Text(
          'Todos los documentos están aprobados. ¿Deseas aprobar el portafolio de evidencias?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00897B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _isApproving = true);

    final path =
        '/api/v1/candidates/processes/${widget.processUuid}/portfolio/approve';
    final currentVersion =
        (_data?['review']?['version'] as num?)?.toInt() ?? _reviewVersion;
    final payload = {'version': currentVersion};
    debugPrint('--- APROBAR PORTAFOLIO --- $path\n$payload');

    try {
      final response = await dio.post(path, data: payload);
      final body = response.data as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        _showSnack(body['message']?.toString() ?? 'Portafolio aprobado');
        // La respuesta trae el portafolio ya actualizado (nuevo estado y ronda)
        final nuevo = body['data'];
        if (nuevo is Map<String, dynamic> && mounted) {
          setState(() {
            _data = nuevo;
            _reviewVersion =
                (nuevo['review']?['version'] as num?)?.toInt() ??
                _reviewVersion;
            _revisiones.clear();
          });
        } else {
          await _fetchPortafolio();
        }
      } else if (response.statusCode == 401) {
        await clearSession();
        _showSnack('Tu sesión expiró. Vuelve a iniciar sesión.');
      } else if (response.statusCode == 409) {
        debugPrint('--- APROBAR 409 --- $body');
        await _fetchPortafolio(silent: true);
        _showSnack('La revisión se actualizó. Intenta aprobar de nuevo.');
      } else {
        debugPrint('--- APROBAR ${response.statusCode} --- $body');
        _showSnack(body['message']?.toString() ?? 'No se pudo aprobar');
      }
    } catch (e) {
      debugPrint('--- APROBAR ERROR --- $e');
      _showSnack('Error de conexión: $e');
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  /// true si algún documento ya tiene veredicto con observaciones en el servidor
  bool _hayObservaciones() {
    final sections = (_data?['sections'] as List<dynamic>?) ?? [];
    for (final sec in sections) {
      for (final it in (sec['items'] as List<dynamic>? ?? [])) {
        final v = it['review']?['verdict'];
        if (v == 'rejected' || v == 'invalid') return true;
      }
    }
    return false;
  }

  Future<void> _rechazarPortafolio() async {
    String nota = '';
    String? errorNota;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Rechazar portafolio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Se devolverá el portafolio con las observaciones de cada documento.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                maxLines: 3,
                onChanged: (v) {
                  nota = v;
                  if (errorNota != null) {
                    setDialogState(() => errorNota = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Nota general',
                  errorText: errorNota,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nota.trim().isEmpty) {
                  setDialogState(
                    () => errorNota = 'Escribe el motivo del rechazo',
                  );
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
              ),
              child: const Text('Rechazar'),
            ),
          ],
        ),
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _isRejecting = true);

    final path =
        '/api/v1/candidates/processes/${widget.processUuid}/portfolio/request-correction';
    final currentVersion =
        (_data?['review']?['version'] as num?)?.toInt() ?? _reviewVersion;
    final payload = {'version': currentVersion, 'general_note': nota.trim()};
    debugPrint('--- RECHAZAR PORTAFOLIO --- $path\n$payload');

    try {
      final response = await dio.post(path, data: payload);
      final body = response.data as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        _showSnack(body['message']?.toString() ?? 'Portafolio rechazado');
        // La respuesta trae el portafolio ya actualizado
        final nuevo = body['data'];
        if (nuevo is Map<String, dynamic> && mounted) {
          setState(() {
            _data = nuevo;
            _reviewVersion =
                (nuevo['review']?['version'] as num?)?.toInt() ??
                _reviewVersion;
            _revisiones.clear();
          });
        } else {
          await _fetchPortafolio();
        }
      } else if (response.statusCode == 401) {
        await clearSession();
        _showSnack('Tu sesión expiró. Vuelve a iniciar sesión.');
      } else if (response.statusCode == 409) {
        debugPrint('--- RECHAZAR 409 --- $body');
        await _fetchPortafolio(silent: true);
        _showSnack('La revisión se actualizó. Intenta de nuevo.');
      } else {
        debugPrint('--- RECHAZAR ${response.statusCode} --- $body');
        _showSnack(body['message']?.toString() ?? 'No se pudo rechazar');
      }
    } catch (e) {
      debugPrint('--- RECHAZAR ERROR --- $e');
      _showSnack('Error de conexión: $e');
    } finally {
      if (mounted) setState(() => _isRejecting = false);
    }
  }

  Future<void> _fetchPortafolio({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    final path = '/api/v1/candidates/processes/${widget.processUuid}/portfolio';

    try {
      final response = await dio.get(path);
      final body = response.data as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        setState(() {
          _data = body['data'] as Map<String, dynamic>;
          _reviewVersion =
              (_data!['review']?['version'] as num?)?.toInt() ?? _reviewVersion;
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

  Future<void> _openFile(String fileUuid, Map<String, dynamic> item) async {
    final itemUuid = _itemUuid(item);
    setState(() => _openingFileUuid = fileUuid);

    try {
      // 1) Registrar el documento como "abierto" para la revisión.
      //    Sin esto el servidor rechaza el veredicto (PORTFOLIO_DOCUMENT_NOT_OPENED).
      if (itemUuid != null) {
        final markPath =
            '/api/v1/candidates/processes/${widget.processUuid}/portfolio/review/items/$itemUuid/open';
        try {
          final markResp = await dio.post(markPath);
          final markBody = markResp.data;

          if (markResp.statusCode == 200 &&
              markBody is Map<String, dynamic> &&
              markBody['success'] == true) {
            // La respuesta trae el portafolio actualizado (con opened_at)
            if (mounted) {
              setState(() {
                _data = markBody['data'] as Map<String, dynamic>;
                _reviewVersion =
                    (_data!['review']?['version'] as num?)?.toInt() ??
                    _reviewVersion;
              });
            }
          } else if (markResp.statusCode == 401) {
            await clearSession();
            _showSnack('Tu sesión expiró. Vuelve a iniciar sesión.');
            return;
          } else {
            debugPrint(
              '--- MARCAR ABIERTO ${markResp.statusCode} --- $markBody',
            );
          }
        } catch (e) {
          debugPrint('--- MARCAR ABIERTO ERROR --- $e');
        }
      }

      // 2) Obtener la URL temporal del archivo y abrirlo
      final path =
          '/api/v1/candidates/processes/${widget.processUuid}/portfolio/files/$fileUuid/open';
      final response = await dio.post(path);
      final body = response.data as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        final temporaryUrl = data['temporary_url'] as String?;

        if (temporaryUrl != null && temporaryUrl.isNotEmpty) {
          try {
            final launched = await launchUrl(
              Uri.parse(temporaryUrl),
              mode: LaunchMode.externalApplication,
            );
            if (!launched && mounted) _showSnack('No se pudo abrir el archivo');
          } catch (e) {
            debugPrint('launchUrl error: $e');
          }

          // 3) Mostrar los checks con el documento ya actualizado
          if (mounted) {
            setState(() => _openingFileUuid = null);
            final actualizado = itemUuid != null ? _findItem(itemUuid) : null;
            debugPrint(
              '--- OPENED_AT tras abrir --- ${actualizado?['review']?['opened_at']}',
            );
            await _mostrarRevisionSheet(actualizado ?? item);
          }
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

  // --- INTERFAZ DE USUARIO ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(title: const Text('Portafolio de Evidencias')),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _spinner() => const SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
  );

  Widget? _buildBottomBar() {
    if (_isLoading || _errorMessage != null || _data == null) return null;

    final capabilities = _data!['capabilities'] as Map<String, dynamic>? ?? {};
    final hayPendientes = _revisiones.isNotEmpty;

    final showApprove =
        !hayPendientes && (capabilities['can_approve'] as bool? ?? false);
    final showReject =
        !hayPendientes &&
        ((capabilities['can_request_correction'] as bool? ?? false) ||
            _hayObservaciones());

    if (!hayPendientes && !showApprove && !showReject) return null;

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    const labelStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 16);

    final botones = <Widget>[
      if (hayPendientes)
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _guardarCambios,
          icon: _isSaving ? _spinner() : const Icon(Icons.save_outlined),
          label: Text(
            'Guardar cambios (${_revisiones.length})',
            style: labelStyle,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: OCColors.mediumBlue,
            foregroundColor: Colors.white,
            shape: shape,
          ),
        ),
      if (showApprove)
        ElevatedButton.icon(
          onPressed: _isApproving ? null : _aprobarPortafolio,
          icon: _isApproving ? _spinner() : const Icon(Icons.verified_outlined),
          label: const Text('Aprobar portafolio', style: labelStyle),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00897B),
            foregroundColor: Colors.white,
            shape: shape,
          ),
        ),
      if (showReject)
        ElevatedButton.icon(
          onPressed: _isRejecting ? null : _rechazarPortafolio,
          icon: _isRejecting ? _spinner() : const Icon(Icons.undo_rounded),
          label: const Text('Rechazar portafolio', style: labelStyle),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD32F2F),
            foregroundColor: Colors.white,
            shape: shape,
          ),
        ),
    ];

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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < botones.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              SizedBox(width: double.infinity, height: 50, child: botones[i]),
            ],
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
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // HEADER CARD
          _buildHeaderCard(candidate, standard, status, progress),

          const SizedBox(height: 20),

          // TIMELINE (si existe)
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
    final itemUuid = _itemUuid(item);
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
                        ? () => _openFile(fileUuid, item)
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
                          if (itemUuid != null && _revisiones[itemUuid] != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(
                                _revisiones[itemUuid]!.aprobado
                                    ? Icons.check_circle
                                    : Icons.rate_review,
                                size: 16,
                                color: _revisiones[itemUuid]!.aprobado
                                    ? const Color(0xFF00897B)
                                    : const Color(0xFFF57C00),
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
      case 'rejected':
        return 'CON OBSERVACIONES';
      case 'pending':
        return 'PENDIENTE';
      default:
        return verdict.toUpperCase();
    }
  }

  IconData _iconForItemStatus(String? statusCode, String? verdict) {
    if (verdict == 'valid') return Icons.check;
    if (verdict == 'invalid' || verdict == 'rejected') return Icons.close;
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
    if (verdict == 'valid') return const Color(0xFF00897B);
    if (verdict == 'invalid' || verdict == 'rejected') {
      return const Color(0xFFD32F2F);
    }
    switch (statusCode) {
      case 'ready':
        return const Color(0xFF00897B);
      case 'pending':
        return const Color(0xFFF57C00);
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

/// Resultado de la revisión de un archivo.
class _RevisionArchivo {
  final bool aprobado;
  final bool conObservaciones;
  final String observaciones;

  const _RevisionArchivo({
    required this.aprobado,
    required this.conObservaciones,
    required this.observaciones,
  });
}
