import 'package:flutter/material.dart';
import '../main.dart';
import '../Organismo Certificador/candidatos.dart' show OCColors;

class DiagnosticaScreen extends StatefulWidget {
  final String? logoUrl;
  const DiagnosticaScreen({super.key, this.logoUrl});

  @override
  State<DiagnosticaScreen> createState() => _DiagnosticaScreenState();
}

class _DiagnosticaScreenState extends State<DiagnosticaScreen> {
  List<Map<String, dynamic>> _standards = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchStandards();
  }

  Future<void> _fetchStandards() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    debugPrint('--- COMPETENCE STANDARDS REQUEST ---');
    debugPrint(
      'URL: https://ocmax.mx/api/v1/competence-standards/get?page=1&per_page=100',
    );

    try {
      final response = await dio.get(
        '/api/v1/competence-standards/get',
        queryParameters: {'page': 1, 'per_page': 100},
      );

      debugPrint('--- COMPETENCE STANDARDS RESPONSE ---');
      debugPrint('Status code: ${response.statusCode}');
      debugPrint('Body: ${response.data}');

      final body = response.data as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> data = body['data'] as List<dynamic>;
        setState(() {
          _standards = data.cast<Map<String, dynamic>>();
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
      debugPrint('--- COMPETENCE STANDARDS ERROR ---');
      debugPrint(e.toString());
      setState(() {
        _errorMessage = 'Error de conexión: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _openNuevoInstrumentoDialog() async {
    if (_standards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aún no hay estándares de competencia cargados'),
        ),
      );
      return;
    }

    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _NuevoInstrumentoDialog(standards: _standards),
    );

    if (created == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Borrador del instrumento creado')),
      );
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
          'Diagnóstica',
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: OCColors.mediumBlue,
        onPressed: _openNuevoInstrumentoDialog,
        child: const Icon(Icons.add, color: Colors.white),
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
                onPressed: _fetchStandards,
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

    return RefreshIndicator(
      onRefresh: _fetchStandards,
      color: OCColors.mediumBlue,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.medical_services_outlined,
                        size: 80,
                        color: OCColors.mediumBlue.withOpacity(0.4),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Pantalla de Diagnóstica',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: OCColors.darkBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Toca el botón + para crear un nuevo instrumento de '
                        'evaluación.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NuevoInstrumentoDialog extends StatefulWidget {
  final List<Map<String, dynamic>> standards;

  const _NuevoInstrumentoDialog({required this.standards});

  @override
  State<_NuevoInstrumentoDialog> createState() =>
      _NuevoInstrumentoDialogState();
}

class _NuevoInstrumentoDialogState extends State<_NuevoInstrumentoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _instruccionesController = TextEditingController(
    text:
        'Lea cuidadosamente los siguientes reactivos y elija la respuesta '
        'correcta.',
  );

  String? _selectedStandardUuid;
  bool _mostrarExplicacion = true;
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void dispose() {
    _nombreController.dispose();
    _instruccionesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedStandardUuid == null) {
      setState(() {
        _submitError = _selectedStandardUuid == null
            ? 'Selecciona un estándar de competencia'
            : null;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    final payload = {
      'competence_standard_uuid': _selectedStandardUuid,
      'name': _nombreController.text.trim(),
      'instructions': _instruccionesController.text.trim(),
      'show_explanation': _mostrarExplicacion,
    };

    debugPrint('--- CREAR INSTRUMENTO REQUEST ---');
    debugPrint('Body: $payload');

    try {
      final response = await dio.post(
        '/api/v1/evaluation-instruments/create',
        data: payload,
      );

      debugPrint('--- CREAR INSTRUMENTO RESPONSE ---');
      debugPrint('Status code: ${response.statusCode}');
      debugPrint('Body: ${response.data}');

      final body = response.data as Map<String, dynamic>;

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body['success'] == true) {
        if (mounted) Navigator.of(context).pop(true);
      } else if (response.statusCode == 401) {
        await clearSession();
        setState(() {
          _submitError = 'Tu sesión expiró. Vuelve a iniciar sesión.';
          _isSubmitting = false;
        });
      } else {
        setState(() {
          _submitError = body['message'] ?? 'No se pudo crear el instrumento';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      debugPrint('--- CREAR INSTRUMENTO ERROR ---');
      debugPrint(e.toString());
      setState(() {
        _submitError = 'Error de conexión: $e';
        _isSubmitting = false;
      });
    }
  }

  InputDecoration _fieldDecoration(String hint, {Color? hintColor}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: hintColor ?? Colors.white.withOpacity(0.45)),
      filled: true,
      fillColor: const Color(0xFF15375A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.35)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: OCColors.cyan, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  Widget _label(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          children: [
            TextSpan(text: text),
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.redAccent),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: OCColors.darkBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Nuevo instrumento',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      InkWell(
                        onTap: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: Icon(
                          Icons.close,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _label('Estándar de Competencia', required: true),
                  DropdownButtonFormField<String>(
                    value: _selectedStandardUuid,
                    dropdownColor: const Color(0xFF15375A),
                    isExpanded: true,
                    hint: const Text(
                      'Selecciona un estándar',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: _fieldDecoration(''),
                    items: widget.standards.map((standard) {
                      final uuid = standard['uuid'] as String;
                      final code = standard['code'] as String? ?? '';
                      final name = standard['name'] as String? ?? '';
                      return DropdownMenuItem(
                        value: uuid,
                        child: Text(
                          '$code — $name',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedStandardUuid = value;
                        _submitError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  _label('Nombre del instrumento', required: true),
                  TextFormField(
                    controller: _nombreController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _fieldDecoration(
                      'Evaluación diagnóstica EC0305',
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Escribe un nombre para el instrumento'
                        : null,
                  ),
                  const SizedBox(height: 20),

                  _label('Instrucciones para el candidato'),
                  TextFormField(
                    controller: _instruccionesController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: _fieldDecoration(
                      'Lea cuidadosamente los siguientes reactivos y elija la '
                      'respuesta correcta.',
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Mostrar la explicación después de cada reactivo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Switch(
                        value: _mostrarExplicacion,
                        activeColor: Colors.white,
                        activeTrackColor: OCColors.cyan,
                        onChanged: (value) {
                          setState(() => _mostrarExplicacion = value);
                        },
                      ),
                      Expanded(
                        child: Text(
                          'El candidato ve si acertó y por qué, reactivo por '
                          'reactivo.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_submitError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _submitError!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withOpacity(0.08),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: OCColors.cyan,
                          foregroundColor: OCColors.darkBlue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: OCColors.darkBlue,
                                ),
                              )
                            : const Text(
                                'Crear borrador',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
