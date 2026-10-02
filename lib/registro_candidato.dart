import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'main.dart' show dio;

class RegistroCandtoScreen extends StatefulWidget {
  const RegistroCandtoScreen({super.key});

  @override
  State<RegistroCandtoScreen> createState() => _RegistroCandtoScreenState();
}

class _RegistroCandtoScreenState extends State<RegistroCandtoScreen> {
  final _formKey = GlobalKey<FormState>();

  // Datos personales
  final _nombreCtrl = TextEditingController();
  final _curpCtrl = TextEditingController();
  final _rfcCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  DateTime? _fechaNacimiento;
  static const _nacMexicana = '1';
  static const _nacExtranjera = '2';

  /// IDs de `oc_cat_nationalities` y `oc_cat_education_levels` (fijos en el web).
  static const _nacionalidades = [
    MapEntry(_nacMexicana, 'Mexicana'),
    MapEntry(_nacExtranjera, 'Extranjera'),
  ];
  static const _gradosEstudios = [
    MapEntry('1', 'Sin estudios'),
    MapEntry('2', 'Primaria'),
    MapEntry('3', 'Secundaria'),
    MapEntry('4', 'Bachillerato o Preparatoria'),
    MapEntry('5', 'Carrera técnica'),
    MapEntry('6', 'Licenciatura'),
    MapEntry('7', 'Especialidad'),
    MapEntry('8', 'Maestría'),
    MapEntry('9', 'Doctorado'),
  ];

  String? _nacionalidad; // id de nacionalidad
  String? _entidadNacimiento; // uuid de entidad (solo mexicanos)
  final _paisNacimientoCtrl = TextEditingController(); // solo extranjeros
  String? _gradoEstudios; // id de grado de estudios

  // Catálogos cargados de la API
  List<Map<String, dynamic>> _centros = [];
  List<Map<String, dynamic>> _acreditaciones = [];
  List<Map<String, dynamic>> _estados = [];
  bool _cargandoCentros = true;
  bool _cargandoAcreditaciones = false;
  bool _enviando = false;

  bool get _esExtranjero => _nacionalidad == _nacExtranjera;

  // Domicilio
  final _calleCtrl = TextEditingController();
  final _numExtCtrl = TextEditingController();
  final _numIntCtrl = TextEditingController();
  final _cpCtrl = TextEditingController();
  final _coloniaCtrl = TextEditingController();
  final _localidadCtrl = TextEditingController();
  final _municipioCtrl = TextEditingController();
  final _estadoCtrl = TextEditingController();
  bool _domicilioManual = false;

  // Proceso de certificación
  String? _centroEvaluador;
  String? _estandarCompetencia;

  // Documentos
  PlatformFile? _ineFile;
  PlatformFile? _curpPdfFile;
  PlatformFile? _comprobanteFile;
  PlatformFile? _fotoFile;
  PlatformFile? _firmaFile;

  // Avisos
  bool _avisosCorreo = false;
  bool _avisosWhatsApp = false;
  String? _autorizaPublicacion;
  bool _aceptaTerminos = false;

  @override
  void initState() {
    super.initState();
    _cargarCentros();
    _cargarEstados();
  }

  @override
  void dispose() {
    _paisNacimientoCtrl.dispose();
    _nombreCtrl.dispose();
    _curpCtrl.dispose();
    _rfcCtrl.dispose();
    _correoCtrl.dispose();
    _telefonoCtrl.dispose();
    _calleCtrl.dispose();
    _numExtCtrl.dispose();
    _numIntCtrl.dispose();
    _cpCtrl.dispose();
    _coloniaCtrl.dispose();
    _localidadCtrl.dispose();
    _municipioCtrl.dispose();
    _estadoCtrl.dispose();
    super.dispose();
  }

  // ---------- Validadores ----------
  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null;

  String? _curpVal(String? v) {
    if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
    final ok = RegExp(
      r'^[A-Z]{4}\d{6}[HMX][A-Z]{2}[B-DF-HJ-NP-TV-Z]{3}[A-Z0-9]\d$',
    ).hasMatch(v.trim().toUpperCase());
    return ok ? null : 'CURP inválida (18 caracteres)';
  }

  String? _rfcVal(String? v) {
    if (v == null || v.trim().isEmpty) return null; // opcional
    final ok = RegExp(
      r'^[A-ZÑ&]{3,4}\d{6}[A-Z0-9]{3}$',
    ).hasMatch(v.trim().toUpperCase());
    return ok ? null : 'RFC inválido';
  }

  String? _emailVal(String? v) {
    if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    return ok ? null : 'Correo inválido';
  }

  String? _telVal(String? v) {
    if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
    return RegExp(r'^\d{10}$').hasMatch(v.trim())
        ? null
        : 'Debe tener 10 dígitos';
  }

  // ---------- Catálogos ----------
  List<Map<String, dynamic>> _lista(Response<dynamic> res) {
    final body = res.data;
    if (body is Map && body['data'] is List) {
      return (body['data'] as List).whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  Future<void> _cargarCentros() async {
    try {
      final res = await dio.get('/api/v1/public/evaluation-centers');
      if (!mounted) return;
      setState(() => _centros = _lista(res));
    } on DioException {
      if (mounted) _aviso('No se pudieron cargar los centros de evaluación');
    } finally {
      if (mounted) setState(() => _cargandoCentros = false);
    }
  }

  Future<void> _cargarEstados() async {
    try {
      final res = await dio.get('/api/v1/states');
      if (!mounted) return;
      setState(() => _estados = _lista(res));
    } on DioException {
      if (mounted) _aviso('No se pudieron cargar las entidades federativas');
    }
  }

  /// Al elegir centro se piden solo sus acreditaciones activas.
  Future<void> _elegirCentro(String? uuid) async {
    setState(() {
      _centroEvaluador = uuid;
      _estandarCompetencia = null;
      _acreditaciones = [];
      _cargandoAcreditaciones = uuid != null;
    });
    if (uuid == null) return;
    try {
      final res = await dio.get(
        '/api/v1/public/evaluation-centers/$uuid/accreditations',
      );
      if (!mounted || _centroEvaluador != uuid) return;
      setState(() => _acreditaciones = _lista(res));
    } on DioException {
      if (mounted) _aviso('No se pudieron cargar las acreditaciones');
    } finally {
      if (mounted && _centroEvaluador == uuid) {
        setState(() => _cargandoAcreditaciones = false);
      }
    }
  }

  /// Etiqueta `[código] nombre — OC` de una acreditación.
  String _etiquetaAcreditacion(Map<String, dynamic> a) {
    final est = a['competence_standard'];
    final nombre = est is Map && est['code'] != null
        ? '[${est['code']}] ${est['name']}'
        : (est is Map ? '${est['name']}' : 'Estándar de Competencia');
    final oc = a['certifying_body'];
    final ocNombre = oc is Map ? oc['legal_name'] : null;
    return ocNombre != null ? '$nombre — $ocNombre' : nombre;
  }

  // ---------- Fechas ----------
  Future<void> _seleccionarFechaNacimiento() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime(1995),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
    );
    if (fecha != null) setState(() => _fechaNacimiento = fecha);
  }

  String _fmt(DateTime? d) => d == null
      ? 'Selecciona tu fecha de nacimiento'
      : '${d.day.toString().padLeft(2, '0')}/'
            '${d.month.toString().padLeft(2, '0')}/'
            '${d.year}';

  // ---------- Archivos ----------
  Future<void> _elegirArchivo(String tipo) async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (res != null && res.files.isNotEmpty) {
      setState(() {
        switch (tipo) {
          case 'ine':
            _ineFile = res.files.first;
            break;
          case 'curpPdf':
            _curpPdfFile = res.files.first;
            break;
          case 'comprobante':
            _comprobanteFile = res.files.first;
            break;
          case 'foto':
            _fotoFile = res.files.first;
            break;
          case 'firma':
            _firmaFile = res.files.first;
            break;
        }
      });
    }
  }

  // ---------- Envío ----------
  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  MultipartFile _archivo(PlatformFile f) =>
      MultipartFile.fromBytes(f.bytes!, filename: f.name);

  /// Arma el multipart que espera `POST /public/register/candidate`.
  FormData _construirFormData() {
    final form = FormData();
    void campo(String k, String v) {
      if (v.trim().isNotEmpty) form.fields.add(MapEntry(k, v.trim()));
    }

    String flag(bool v) => v ? '1' : '0';

    campo('name', _nombreCtrl.text);
    campo('email', _correoCtrl.text);
    campo('curp', _curpCtrl.text.toUpperCase());
    campo('phone', _telefonoCtrl.text);
    campo('rfc', _rfcCtrl.text.toUpperCase());
    campo('birth_date', _iso(_fechaNacimiento!));
    campo('cat_nationality_id', _nacionalidad ?? '');
    campo('cat_education_level_id', _gradoEstudios ?? '');
    if (_esExtranjero) {
      campo('birth_country', _paisNacimientoCtrl.text);
    } else {
      campo('birth_state_uuid', _entidadNacimiento ?? '');
    }
    campo('accreditation_uuid', _estandarCompetencia ?? '');

    campo('address[street]', _calleCtrl.text);
    campo('address[ext_num]', _numExtCtrl.text);
    campo('address[int_num]', _numIntCtrl.text);
    campo('address[zip_code]', _cpCtrl.text);
    campo('address[neighborhood]', _coloniaCtrl.text);
    campo('address[locality]', _localidadCtrl.text);
    campo('address[municipality]', _municipioCtrl.text);
    campo('address[state]', _estadoCtrl.text);

    // El formulario móvil tiene un solo consentimiento (Términos y Aviso de
    // Privacidad); cubre también el tratamiento de datos sensibles.
    form.fields.add(MapEntry('terms_accepted', flag(_aceptaTerminos)));
    form.fields.add(
      MapEntry('sensitive_data_accepted', flag(_aceptaTerminos)),
    );
    form.fields.add(MapEntry('accepts_email_notifications', flag(_avisosCorreo)));
    form.fields.add(
      MapEntry('accepts_whatsapp_notifications', flag(_avisosWhatsApp)),
    );
    form.fields.add(
      MapEntry(
        'authorizes_information_publication',
        flag(_autorizaPublicacion == 'Sí, autorizo'),
      ),
    );

    form.files.add(MapEntry('ine', _archivo(_ineFile!)));
    form.files.add(MapEntry('curp_doc', _archivo(_curpPdfFile!)));
    form.files.add(MapEntry('comprobante', _archivo(_comprobanteFile!)));
    form.files.add(MapEntry('foto', _archivo(_fotoFile!)));
    form.files.add(MapEntry('file_firma', _archivo(_firmaFile!)));
    return form;
  }

  String _mensajeError(Response<dynamic> res) {
    final body = res.data;
    if (body is Map) {
      final errors = body['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final primero = errors.values.first;
        if (primero is List && primero.isNotEmpty) return '${primero.first}';
      }
      if (body['message'] != null) return '${body['message']}';
    }
    return 'No se pudo enviar la solicitud (${res.statusCode})';
  }

  void _aviso(String texto) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(texto)));

  Future<void> _enviar() async {
    if (_enviando) return;
    if (!_formKey.currentState!.validate()) return;

    if (_fechaNacimiento == null ||
        _nacionalidad == null ||
        (!_esExtranjero && _entidadNacimiento == null) ||
        _gradoEstudios == null ||
        _centroEvaluador == null ||
        _estandarCompetencia == null ||
        _autorizaPublicacion == null) {
      _aviso('Completa todos los campos obligatorios');
      return;
    }

    if (_ineFile == null ||
        _curpPdfFile == null ||
        _comprobanteFile == null ||
        _fotoFile == null ||
        _firmaFile == null) {
      _aviso('Adjunta todos los documentos');
      return;
    }

    if (!_aceptaTerminos) {
      _aviso('Debes aceptar los Términos y el Aviso de Privacidad');
      return;
    }

    setState(() => _enviando = true);
    try {
      final res = await dio.post(
        '/api/v1/public/register/candidate',
        data: _construirFormData(),
        options: Options(contentType: Headers.multipartFormDataContentType),
      );
      if (!mounted) return;

      final ok = res.statusCode != null &&
          res.statusCode! >= 200 &&
          res.statusCode! < 300;
      if (!ok) {
        _aviso(_mensajeError(res));
        return;
      }

      _aviso(
        'Recibimos tu solicitud. Te avisaremos por correo cuando cambie su estado.',
      );
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (mounted) {
        _aviso(
          e.response != null
              ? _mensajeError(e.response!)
              : 'Sin conexión con el servidor. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // ---------- Widgets reutilizables ----------
  Widget _campo(
    String label,
    TextEditingController controller, {
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? formatters,
    TextCapitalization capitalization = TextCapitalization.none,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLength: maxLength,
          inputFormatters: formatters,
          textCapitalization: capitalization,
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            isDense: true,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _dropdown(
    String label,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged, {
    bool requerido = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
          validator: (v) => (requerido && (v == null || v.isEmpty))
              ? 'Campo obligatorio'
              : null,
        ),
      ],
    );
  }

  /// Selector cuyas opciones vienen de la API o de un catálogo fijo:
  /// `key` es el valor que viaja al backend y `value` la etiqueta.
  Widget _dropdownApi(
    String label,
    String? value,
    List<MapEntry<String, String>> items,
    ValueChanged<String?> onChanged, {
    bool cargando = false,
    bool habilitado = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: cargando
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: habilitado ? onChanged : null,
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Campo obligatorio' : null,
        ),
      ],
    );
  }

  Widget _fechaNacimientoField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Fecha de Nacimiento'),
        const SizedBox(height: 6),
        TextFormField(
          readOnly: true,
          onTap: _seleccionarFechaNacimiento,
          decoration: InputDecoration(
            hintText: _fmt(_fechaNacimiento),
            isDense: true,
            suffixIcon: const Icon(Icons.calendar_today, size: 18),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          validator: (_) =>
              _fechaNacimiento == null ? 'Campo obligatorio' : null,
        ),
      ],
    );
  }

  Widget _fila(List<Widget> hijos, {int columnas = 2}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth < 600) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < hijos.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  hijos[i],
                ],
              ],
            );
          }
          final items = [...hijos];
          while (items.length < columnas) {
            items.add(const SizedBox());
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                Expanded(child: items[i]),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _titulo(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      texto,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
    ),
  );

  Widget _archivoPicker(String label, PlatformFile? archivo, String tipo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () => _elegirArchivo(tipo),
          icon: const Icon(Icons.upload_outlined, size: 18),
          label: const Text('Seleccionar archivo'),
        ),
        if (archivo != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              archivo.name,
              style: const TextStyle(fontSize: 12, color: Colors.green),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FA),
      appBar: AppBar(title: const Text('Registro de Candidato')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F0F3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.person_outline, color: primary),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Registro de Candidato',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Inicia tu proceso de certificación',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Datos personales
                    _fila([
                      _campo(
                        'Nombre Completo',
                        _nombreCtrl,
                        hint: 'Ej. JUAN PEREZ LOPEZ',
                        validator: _req,
                        capitalization: TextCapitalization.characters,
                      ),
                    ]),
                    _fila([
                      _campo(
                        'CURP',
                        _curpCtrl,
                        hint: 'Ej. PELJ900101HDFRND09',
                        validator: _curpVal,
                        maxLength: 18,
                        capitalization: TextCapitalization.characters,
                      ),
                      _campo(
                        'RFC (opcional)',
                        _rfcCtrl,
                        hint: 'Ej. PELJ900101AB1',
                        validator: _rfcVal,
                        maxLength: 13,
                        capitalization: TextCapitalization.characters,
                      ),
                    ]),
                    _fila([
                      _campo(
                        'Correo Electrónico',
                        _correoCtrl,
                        hint: 'Ej. juan.perez@correo.com',
                        validator: _emailVal,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      _campo(
                        'Teléfono',
                        _telefonoCtrl,
                        hint: 'Ej. 5512345678',
                        validator: _telVal,
                        maxLength: 10,
                        keyboardType: TextInputType.phone,
                        formatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ]),
                    _fila([
                      _fechaNacimientoField(),
                      _dropdownApi(
                        'Nacionalidad',
                        _nacionalidad,
                        _nacionalidades,
                        (v) => setState(() {
                          _nacionalidad = v;
                          _entidadNacimiento = null;
                          _paisNacimientoCtrl.clear();
                        }),
                      ),
                    ]),
                    _fila([
                      _esExtranjero
                          ? _campo(
                              'País de nacimiento',
                              _paisNacimientoCtrl,
                              validator: _req,
                            )
                          : _dropdownApi(
                              'Entidad Federativa de Nacimiento',
                              _entidadNacimiento,
                              [
                                for (final e in _estados)
                                  MapEntry('${e['uuid']}', '${e['name']}'),
                              ],
                              (v) => setState(() => _entidadNacimiento = v),
                            ),
                      _dropdownApi(
                        'Grado de Estudios',
                        _gradoEstudios,
                        _gradosEstudios,
                        (v) => setState(() => _gradoEstudios = v),
                      ),
                    ]),

                    const Divider(height: 32),

                    // Domicilio
                    _titulo('Domicilio particular'),
                    _fila([
                      _campo('Calle', _calleCtrl, validator: _req),
                      _campo('Número exterior', _numExtCtrl, validator: _req),
                      _campo('Número interior', _numIntCtrl),
                    ], columnas: 3),
                    _fila([
                      _campo(
                        'Código postal',
                        _cpCtrl,
                        validator: _req,
                        maxLength: 5,
                        keyboardType: TextInputType.number,
                        formatters: [FilteringTextInputFormatter.digitsOnly],
                        suffixIcon: const Icon(Icons.location_on_outlined),
                      ),
                      _campo('Colonia', _coloniaCtrl, validator: _req),
                      _campo('Localidad', _localidadCtrl, validator: _req),
                    ], columnas: 3),
                    _fila([
                      _campo(
                        'Municipio / alcaldía',
                        _municipioCtrl,
                        validator: _req,
                      ),
                      _campo('Estado', _estadoCtrl, validator: _req),
                    ], columnas: 3),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _domicilioManual,
                      onChanged: (v) =>
                          setState(() => _domicilioManual = v ?? false),
                      title: const Text(
                        'No encuentro mi localidad: capturar el domicilio manualmente',
                      ),
                    ),

                    const Divider(height: 32),

                    // Proceso de certificación
                    _titulo('Proceso de certificación'),
                    _fila([
                      _dropdownApi(
                        'Centro de Evaluación / Evaluador Independiente',
                        _centroEvaluador,
                        [
                          for (final c in _centros)
                            MapEntry('${c['uuid']}', '${c['legal_name']}'),
                        ],
                        _elegirCentro,
                        cargando: _cargandoCentros,
                      ),
                    ]),
                    _fila([
                      _dropdownApi(
                        'Estándar de Competencia',
                        _estandarCompetencia,
                        [
                          for (final a in _acreditaciones)
                            MapEntry(
                              '${a['accreditation_uuid']}',
                              _etiquetaAcreditacion(a),
                            ),
                        ],
                        (v) => setState(() => _estandarCompetencia = v),
                        cargando: _cargandoAcreditaciones,
                        habilitado: _centroEvaluador != null,
                      ),
                    ]),

                    const Divider(height: 32),

                    // Expediente documental
                    _titulo('Expediente documental'),
                    _fila([
                      _archivoPicker(
                        'Identificación Oficial (INE / Pasaporte)',
                        _ineFile,
                        'ine',
                      ),
                      _archivoPicker(
                        'CURP Oficial PDF',
                        _curpPdfFile,
                        'curpPdf',
                      ),
                    ]),
                    _fila([
                      _archivoPicker(
                        'Comprobante de Domicilio',
                        _comprobanteFile,
                        'comprobante',
                      ),
                    ]),

                    // Fotografía del candidato
                    _titulo('Fotografía del Candidato'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F8FB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.camera_alt_outlined,
                            color: Color(0xFF0E6E8C),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Fotografía del Candidato',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '¿Cómo debe ser tu fotografía?',
                                      style: TextStyle(
                                        color: primary,
                                        fontSize: 12,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Fotografía reciente tipo credencial rostro descubierto y de frente, fondo claro y uniforme. Sube un archivo o toma con tu cámara. Los ajustes por ti al tamaño que pide el formato oficial (196 x 236 px, JPG).',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _elegirArchivo('foto'),
                            icon: const Icon(Icons.upload_outlined, size: 18),
                            label: const Text('Seleccionar archivo'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _elegirArchivo('foto'),
                            icon: const Icon(
                              Icons.camera_alt_outlined,
                              size: 18,
                            ),
                            label: const Text('Tomar fotografía'),
                          ),
                        ),
                      ],
                    ),
                    if (_fotoFile != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _fotoFile!.name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Firma
                    _titulo('Firma del Candidato'),
                    _archivoPicker(
                      'Seleccionar archivo de firma',
                      _firmaFile,
                      'firma',
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Imagen JPG o PNG de tu firma, como la haces en papel: trazo sobre fondo claro, sin sombras.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),

                    const Divider(height: 32),

                    // Avisos y autorizaciones
                    _titulo('Avisos y autorizaciones'),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _avisosCorreo,
                      onChanged: (v) =>
                          setState(() => _avisosCorreo = v ?? false),
                      title: const Text(
                        'Deseo recibir avisos por correo electrónico',
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _avisosWhatsApp,
                      onChanged: (v) =>
                          setState(() => _avisosWhatsApp = v ?? false),
                      title: const Text('Deseo recibir avisos por WhatsApp'),
                    ),
                    const SizedBox(height: 8),
                    _dropdown(
                      '¿Autorizas la publicación de tu información?',
                      _autorizaPublicacion,
                      const ['Sí, autorizo', 'No autorizo'],
                      (v) => setState(() => _autorizaPublicacion = v),
                    ),

                    const SizedBox(height: 16),

                    // Términos
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: _aceptaTerminos,
                                onChanged: (v) => setState(
                                  () => _aceptaTerminos = v ?? false,
                                ),
                              ),
                              Expanded(
                                child: Wrap(
                                  children: [
                                    const Text('He leído y acepto los '),
                                    InkWell(
                                      onTap: () {},
                                      child: Text(
                                        'Términos y Condiciones',
                                        style: TextStyle(
                                          color: primary,
                                          fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                    const Text(' y el '),
                                    InkWell(
                                      onTap: () {},
                                      child: Text(
                                        'Aviso de Privacidad',
                                        style: TextStyle(
                                          color: primary,
                                          fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                    const Text('.'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 12, top: 4),
                            child: Text(
                              'Doy mi consentimiento expreso para el tratamiento de mis datos personales sensibles (identificación oficial, CURP, comprobante de domicilio, fotografía y firma) con fines de evaluación y certificación.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 12, top: 4),
                            child: Text(
                              'Para acreditar tu consentimiento registramos la fecha, la versión de los documentos aceptados, tu dirección IP y el navegador desde el que aceptaste.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _enviando ? null : _enviar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1677FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _enviando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Enviar solicitud'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
