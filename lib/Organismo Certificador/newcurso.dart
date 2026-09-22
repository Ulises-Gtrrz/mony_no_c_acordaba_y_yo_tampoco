import 'package:flutter/material.dart';
import '../main.dart';
import '../Organismo Certificador/candidatos.dart' show OCColors;

class NewCursoScreen extends StatefulWidget {
  final String? logoUrl;
  const NewCursoScreen({super.key, this.logoUrl});

  @override
  State<NewCursoScreen> createState() => _NewCursoScreenState();
}

class _NewCursoScreenState extends State<NewCursoScreen> {
  Future<void> _openNuevoCursoDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _NuevoCursoDialog(),
    );

    if (created == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Borrador del curso creado')),
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
          'Cursos',
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 80,
                color: OCColors.mediumBlue.withOpacity(0.4),
              ),
              const SizedBox(height: 16),
              const Text(
                'Cursos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: OCColors.darkBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Toca el botón + para crear un nuevo curso.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: OCColors.mediumBlue,
        onPressed: _openNuevoCursoDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _NuevoCursoDialog extends StatefulWidget {
  const _NuevoCursoDialog();

  @override
  State<_NuevoCursoDialog> createState() => _NuevoCursoDialogState();
}

class _NuevoCursoDialogState extends State<_NuevoCursoDialog> {
  static const _fieldFill = Color(0xFF15375A);

  final _formKey = GlobalKey<FormState>();
  final _claveController = TextEditingController();
  final _nombreController = TextEditingController();
  final _objetivoController = TextEditingController();
  final _duracionController = TextEditingController();

  final List<Map<String, String>> _modalidades = const [
    {'value': 'alineacion', 'label': 'Alineación'},
    {'value': 'capacitacion', 'label': 'Capacitación'},
  ];

  List<Map<String, dynamic>> _standards = [];
  bool _isLoadingStandards = true;

  String? _selectedModalidad;
  String? _selectedStandardUuid;
  String? _selectedStandardLabel;

  bool _isSubmitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _fetchStandards();
  }

  @override
  void dispose() {
    _claveController.dispose();
    _nombreController.dispose();
    _objetivoController.dispose();
    _duracionController.dispose();
    super.dispose();
  }

  Future<void> _fetchStandards() async {
    setState(() => _isLoadingStandards = true);

    debugPrint('--- COMPETENCE STANDARDS REQUEST (NUEVO CURSO) ---');

    try {
      final response = await dio.get(
        '/api/v1/competence-standards/get',
        queryParameters: {'page': 1, 'per_page': 100},
      );

      final body = response.data as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> data = body['data'] as List<dynamic>;
        if (mounted) {
          setState(() {
            _standards = data.cast<Map<String, dynamic>>();
            _isLoadingStandards = false;
          });
        }
      } else if (response.statusCode == 401) {
        await clearSession();
        if (mounted) setState(() => _isLoadingStandards = false);
      } else {
        if (mounted) setState(() => _isLoadingStandards = false);
      }
    } catch (e) {
      debugPrint('--- COMPETENCE STANDARDS ERROR (NUEVO CURSO) ---');
      debugPrint(e.toString());
      if (mounted) setState(() => _isLoadingStandards = false);
    }
  }

  Future<void> _openStandardSearch() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: OCColors.darkBlue,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _StandardSearchSheet(standards: _standards),
    );

    if (result != null) {
      setState(() {
        _selectedStandardUuid = result['uuid'] as String;
        final code = result['code'] as String? ?? '';
        final name = result['name'] as String? ?? '';
        _selectedStandardLabel = '$code — $name';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedModalidad == null) {
      setState(() => _submitError = 'Selecciona una modalidad');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    final payload = {
      'modality': _selectedModalidad,
      'competence_standard_uuid': _selectedStandardUuid,
      'code': _claveController.text.trim(),
      'name': _nombreController.text.trim(),
      'objective': _objetivoController.text.trim(),
      'duration_hours': _duracionController.text.trim().isEmpty
          ? null
          : int.tryParse(_duracionController.text.trim()),
    };

    debugPrint('--- CREAR CURSO REQUEST ---');
    debugPrint('Body: $payload');

    try {
      final response = await dio.post('/api/v1/courses/create', data: payload);

      debugPrint('--- CREAR CURSO RESPONSE ---');
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
          _submitError = body['message'] ?? 'No se pudo crear el curso';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      debugPrint('--- CREAR CURSO ERROR ---');
      debugPrint(e.toString());
      setState(() {
        _submitError = 'Error de conexión: $e';
        _isSubmitting = false;
      });
    }
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
            if (required)
              const TextSpan(
                text: '* ',
                style: TextStyle(color: Colors.redAccent),
              ),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint, {Color? hintColor}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: hintColor ?? Colors.white.withOpacity(0.45)),
      filled: true,
      fillColor: _fieldFill,
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
                        'Nuevo curso',
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

                  _label('Modalidad', required: true),
                  DropdownButtonFormField<String>(
                    value: _selectedModalidad,
                    dropdownColor: _fieldFill,
                    isExpanded: true,
                    hint: const Text(
                      'Alineación o capacitación',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: _fieldDecoration(''),
                    items: _modalidades
                        .map(
                          (m) => DropdownMenuItem(
                            value: m['value'],
                            child: Text(m['label']!),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedModalidad = value;
                        _submitError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  _label('Estándar de Competencia'),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _isLoadingStandards ? null : _openStandardSearch,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: _fieldFill,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _isLoadingStandards
                                  ? 'Cargando estándares...'
                                  : (_selectedStandardLabel ??
                                        'Busca por código o nombre'),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _selectedStandardLabel != null
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.45),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (_selectedStandardLabel != null)
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedStandardUuid = null;
                                  _selectedStandardLabel = null;
                                });
                              },
                              child: Icon(
                                Icons.clear,
                                size: 18,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            )
                          else
                            Icon(
                              Icons.search,
                              size: 20,
                              color: Colors.white.withOpacity(0.6),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _label('Clave del curso', required: true),
                  TextFormField(
                    controller: _claveController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _fieldDecoration('CAP-0305'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Escribe la clave del curso'
                        : null,
                  ),
                  const SizedBox(height: 20),

                  _label('Nombre del curso', required: true),
                  TextFormField(
                    controller: _nombreController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _fieldDecoration(
                      'Prestación de servicios de atención a clientes',
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Escribe el nombre del curso'
                        : null,
                  ),
                  const SizedBox(height: 20),

                  _label('Objetivo'),
                  TextFormField(
                    controller: _objetivoController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: _fieldDecoration(
                      'Al concluir, el participante será capaz de...',
                    ),
                  ),
                  const SizedBox(height: 20),

                  _label('Duración en horas'),
                  TextFormField(
                    controller: _duracionController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _fieldDecoration(''),
                  ),

                  if (_submitError != null) ...[
                    const SizedBox(height: 16),
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

class _StandardSearchSheet extends StatefulWidget {
  final List<Map<String, dynamic>> standards;

  const _StandardSearchSheet({required this.standards});

  @override
  State<_StandardSearchSheet> createState() => _StandardSearchSheetState();
}

class _StandardSearchSheetState extends State<_StandardSearchSheet> {
  final _searchController = TextEditingController();
  late List<Map<String, dynamic>> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.standards;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final normalized = query.trim().toLowerCase();
    setState(() {
      _filtered = normalized.isEmpty
          ? widget.standards
          : widget.standards.where((standard) {
              final code = (standard['code'] as String? ?? '').toLowerCase();
              final name = (standard['name'] as String? ?? '').toLowerCase();
              return code.contains(normalized) || name.contains(normalized);
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Busca por código o nombre',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF15375A),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(
                        'Sin resultados',
                        style: TextStyle(color: Colors.white.withOpacity(0.6)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: Colors.white.withOpacity(0.08),
                      ),
                      itemBuilder: (context, index) {
                        final standard = _filtered[index];
                        final code = standard['code'] as String? ?? '';
                        final name = standard['name'] as String? ?? '';
                        return ListTile(
                          title: Text(
                            code,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                          onTap: () => Navigator.of(context).pop(standard),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
