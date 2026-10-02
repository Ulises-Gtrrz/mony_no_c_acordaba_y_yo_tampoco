import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'main.dart' show dio;

/// Controladores de una persona de contacto (`contacts[tipo][*]`).
class _ContactoCtrl {
  final nombre = TextEditingController();
  final correo = TextEditingController();
  final rfc = TextEditingController();
  final curp = TextEditingController();
  final whatsapp = TextEditingController();

  void dispose() {
    nombre.dispose();
    correo.dispose();
    rfc.dispose();
    curp.dispose();
    whatsapp.dispose();
  }
}

class RegistroCEScreen extends StatefulWidget {
  const RegistroCEScreen({super.key});

  @override
  State<RegistroCEScreen> createState() => _RegistroCEScreenState();
}

class _RegistroCEScreenState extends State<RegistroCEScreen> {
  final _formKey = GlobalKey<FormState>();

  static const _tipoCe = 'Centro de Evaluación';
  static const _tipoEi = 'Evaluador Independiente';

  // Datos de la solicitud
  String? _tipoRegistro;
  final _razonSocialCtrl = TextEditingController();
  final _nombreComercialCtrl = TextEditingController();
  final _rfcCtrl = TextEditingController();
  final _adminNombreCtrl = TextEditingController();
  final _adminCorreoCtrl = TextEditingController();
  String? _estandarInicial;
  String? _organismoCertificador;
  DateTime? _inicioVigencia;
  DateTime? _finVigencia;

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

  // Personas de contacto (CE: director, legal y técnico; EI: evaluador)
  final _director = _ContactoCtrl();
  final _legal = _ContactoCtrl();
  final _tecnico = _ContactoCtrl();
  final _independiente = _ContactoCtrl();

  // Catálogos cargados de la API: estándares y OC que lo ofrecen
  List<Map<String, dynamic>> _estandares = [];
  List<Map<String, dynamic>> _organismos = [];
  bool _cargandoEstandares = true;
  bool _cargandoOrganismos = false;
  bool _enviando = false;

  bool get _esCe => _tipoRegistro == _tipoCe;
  bool get _esEi => _tipoRegistro == _tipoEi;

  // Documentos
  PlatformFile? _actaFile;
  PlatformFile? _poderFile;
  PlatformFile? _convenioFile;
  PlatformFile? _csfFile;
  PlatformFile? _contratoFile;
  PlatformFile? _formatoFile;
  List<PlatformFile> _fotos = [];

  bool _aceptaTerminos = false;

  @override
  void initState() {
    super.initState();
    _cargarEstandares();
  }

  @override
  void dispose() {
    _nombreComercialCtrl.dispose();
    _director.dispose();
    _legal.dispose();
    _tecnico.dispose();
    _independiente.dispose();
    _razonSocialCtrl.dispose();
    _rfcCtrl.dispose();
    _adminNombreCtrl.dispose();
    _adminCorreoCtrl.dispose();
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

  String? _rfcVal(String? v) {
    if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
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

  String? _curpVal(String? v) {
    if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
    final ok = RegExp(
      r'^[A-Z]{4}\d{6}[HMX][A-Z]{2}[B-DF-HJ-NP-TV-Z]{3}[A-Z0-9]\d$',
    ).hasMatch(v.trim().toUpperCase());
    return ok ? null : 'CURP inválida (18 caracteres)';
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

  Future<void> _cargarEstandares() async {
    try {
      final res = await dio.get('/api/v1/public/competence-standards');
      if (!mounted) return;
      setState(() => _estandares = _lista(res));
    } on DioException {
      if (mounted) _aviso('No se pudieron cargar los estándares');
    } finally {
      if (mounted) setState(() => _cargandoEstandares = false);
    }
  }

  /// Al elegir estándar se piden solo los OC que lo ofrecen.
  Future<void> _elegirEstandar(String? uuid) async {
    setState(() {
      _estandarInicial = uuid;
      _organismoCertificador = null;
      _organismos = [];
      _cargandoOrganismos = uuid != null;
    });
    if (uuid == null) return;
    try {
      final res = await dio.get(
        '/api/v1/public/competence-standards/$uuid/certifying-bodies',
      );
      if (!mounted || _estandarInicial != uuid) return;
      setState(() => _organismos = _lista(res));
    } on DioException {
      if (mounted) _aviso('No se pudieron cargar los Organismos Certificadores');
    } finally {
      if (mounted && _estandarInicial == uuid) {
        setState(() => _cargandoOrganismos = false);
      }
    }
  }

  // ---------- Fechas ----------
  Future<void> _seleccionarFecha(bool esInicio) async {
    final inicial = esInicio
        ? (_inicioVigencia ?? DateTime.now())
        : (_finVigencia ?? DateTime.now());
    final fecha = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (fecha != null) {
      setState(() {
        if (esInicio) {
          _inicioVigencia = fecha;
        } else {
          _finVigencia = fecha;
        }
      });
    }
  }

  String _fmt(DateTime? d) => d == null
      ? 'dd/mm/aaaa'
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
          case 'acta':
            _actaFile = res.files.first;
            break;
          case 'poder':
            _poderFile = res.files.first;
            break;
          case 'convenio':
            _convenioFile = res.files.first;
            break;
          case 'csf':
            _csfFile = res.files.first;
            break;
          case 'contrato':
            _contratoFile = res.files.first;
            break;
          case 'formato':
            _formatoFile = res.files.first;
            break;
        }
      });
    }
  }

  Future<void> _elegirFotos() async {
    final res = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (res != null) setState(() => _fotos = res.files);
  }

  // ---------- Envío ----------
  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  void _agregarContacto(FormData form, String tipo, _ContactoCtrl c) {
    final campos = {
      'full_name': c.nombre.text.trim(),
      'email': c.correo.text.trim(),
      'rfc': c.rfc.text.trim().toUpperCase(),
      'curp': c.curp.text.trim().toUpperCase(),
      'phone': c.whatsapp.text.trim(),
    };
    campos.forEach((k, v) {
      if (v.isNotEmpty) form.fields.add(MapEntry('contacts[$tipo][$k]', v));
    });
  }

  MultipartFile _archivo(PlatformFile f) =>
      MultipartFile.fromBytes(f.bytes!, filename: f.name);

  /// Arma el multipart que espera `POST /public/register/ce-ei`.
  FormData _construirFormData() {
    final form = FormData();
    void campo(String k, String v) {
      if (v.trim().isNotEmpty) form.fields.add(MapEntry(k, v.trim()));
    }

    // Cada fila de estándar pertenece a un solo OC: el backend exige el UUID
    // de la pareja EC ↔ OC elegida, no el del estándar mostrado en catálogo.
    final afiliacion = _organismos.firstWhere(
      (o) => o['uuid'] == _organismoCertificador,
      orElse: () => <String, dynamic>{},
    );

    campo('cat_institution_type_id', _esCe ? '2' : '3');
    campo('legal_name', _razonSocialCtrl.text);
    if (_esCe) campo('commercial_name', _nombreComercialCtrl.text);
    campo('rfc', _rfcCtrl.text.toUpperCase());
    campo('admin_name', _adminNombreCtrl.text);
    campo('admin_email', _adminCorreoCtrl.text);
    campo('certifying_body_uuid', _organismoCertificador ?? '');
    campo(
      'competence_standard_uuid',
      '${afiliacion['competence_standard_uuid'] ?? _estandarInicial ?? ''}',
    );
    campo('contract_valid_from', _iso(_inicioVigencia!));
    campo('contract_valid_until', _iso(_finVigencia!));

    campo('address[street]', _calleCtrl.text);
    campo('address[ext_num]', _numExtCtrl.text);
    campo('address[int_num]', _numIntCtrl.text);
    campo('address[zip_code]', _cpCtrl.text);
    campo('address[neighborhood]', _coloniaCtrl.text);
    campo('address[locality]', _localidadCtrl.text);
    campo('address[municipality]', _municipioCtrl.text);
    campo('address[state]', _estadoCtrl.text);

    if (_esCe) {
      _agregarContacto(form, 'director', _director);
      _agregarContacto(form, 'legal_representative', _legal);
      _agregarContacto(form, 'technical_representative', _tecnico);
    } else {
      _agregarContacto(form, 'independent_evaluator', _independiente);
    }

    form.fields.add(const MapEntry('terms_accepted', '1'));

    if (_esCe) {
      form.files.add(MapEntry('acta_constitutiva', _archivo(_actaFile!)));
      form.files.add(MapEntry('poder_legal', _archivo(_poderFile!)));
      form.files.add(MapEntry('convenio', _archivo(_convenioFile!)));
    }
    form.files.add(MapEntry('csf', _archivo(_csfFile!)));
    form.files.add(MapEntry('contrato', _archivo(_contratoFile!)));
    form.files.add(MapEntry('formato_solicitud', _archivo(_formatoFile!)));
    for (final foto in _fotos) {
      form.files.add(
        MapEntry('fotografias_instalaciones[]', _archivo(foto)),
      );
    }
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

    if (_tipoRegistro == null ||
        _estandarInicial == null ||
        _organismoCertificador == null ||
        _inicioVigencia == null ||
        _finVigencia == null) {
      _aviso('Completa todos los campos obligatorios');
      return;
    }

    if (_csfFile == null ||
        _contratoFile == null ||
        _formatoFile == null ||
        _fotos.isEmpty ||
        (_esCe &&
            (_actaFile == null ||
                _poderFile == null ||
                _convenioFile == null))) {
      _aviso('Adjunta todos los documentos y fotografías');
      return;
    }

    if (!_aceptaTerminos) {
      _aviso('Debes aceptar los Términos y el Aviso de Privacidad');
      return;
    }

    setState(() => _enviando = true);
    try {
      final res = await dio.post(
        '/api/v1/public/register/ce-ei',
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

      final folio = res.data is Map ? (res.data['data']?['folio']) : null;
      _aviso(
        folio != null
            ? 'Recibimos tu solicitud con el folio $folio. Consérvalo para consultar su avance.'
            : 'Recibimos tu solicitud. Te avisaremos por correo cuando cambie su estado.',
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
    ValueChanged<String?> onChanged,
  ) {
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
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Campo obligatorio' : null,
        ),
      ],
    );
  }

  /// Selector cuyas opciones vienen de la API: `key` es el UUID.
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

  Widget _contacto(String titulo, _ContactoCtrl c) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          _fila([
            _campo('Nombre completo', c.nombre, validator: _req),
            _campo(
              'Correo',
              c.correo,
              validator: _emailVal,
              keyboardType: TextInputType.emailAddress,
            ),
          ]),
          _fila([
            _campo(
              'RFC',
              c.rfc,
              validator: _rfcVal,
              maxLength: 13,
              capitalization: TextCapitalization.characters,
            ),
            _campo(
              'CURP',
              c.curp,
              validator: _curpVal,
              maxLength: 18,
              capitalization: TextCapitalization.characters,
            ),
          ]),
          _fila([
            _campo(
              'WhatsApp',
              c.whatsapp,
              validator: _telVal,
              maxLength: 10,
              keyboardType: TextInputType.phone,
              formatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ]),
        ],
      ),
    );
  }

  Widget _fecha(String label, DateTime? valor, bool esInicio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        TextFormField(
          readOnly: true,
          onTap: () => _seleccionarFecha(esInicio),
          decoration: InputDecoration(
            hintText: _fmt(valor),
            isDense: true,
            suffixIcon: const Icon(Icons.calendar_today, size: 18),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          validator: (_) => valor == null ? 'Campo obligatorio' : null,
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
      appBar: AppBar(title: const Text('Solicitud CE / EI')),
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
                          child: Icon(
                            Icons.workspace_premium_outlined,
                            color: primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Solicitud CE / EI',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Completa el expediente para solicitar la afiliación inicial a un OC',
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

                    // Datos de la solicitud
                    _titulo('Datos de la solicitud'),
                    _fila([
                      _dropdown(
                        'Tipo de registro',
                        _tipoRegistro,
                        const [_tipoCe, _tipoEi],
                        (v) => setState(() => _tipoRegistro = v),
                      ),
                      _campo(
                        'Razón social / nombre legal',
                        _razonSocialCtrl,
                        validator: _req,
                      ),
                    ]),
                    if (_esCe)
                      _fila([
                        _campo(
                          'Nombre comercial',
                          _nombreComercialCtrl,
                          validator: _req,
                        ),
                      ]),
                    _fila([
                      _campo(
                        'RFC',
                        _rfcCtrl,
                        validator: _rfcVal,
                        maxLength: 13,
                        capitalization: TextCapitalization.characters,
                      ),
                      _campo(
                        'Nombre del administrador',
                        _adminNombreCtrl,
                        validator: _req,
                      ),
                    ]),
                    _fila([
                      _campo(
                        'Correo del administrador',
                        _adminCorreoCtrl,
                        validator: _emailVal,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      _dropdownApi(
                        'Estándar inicial',
                        _estandarInicial,
                        [
                          for (final e in _estandares)
                            MapEntry(
                              '${e['uuid']}',
                              '[${e['code']}] ${e['name']}',
                            ),
                        ],
                        _elegirEstandar,
                        cargando: _cargandoEstandares,
                      ),
                    ]),
                    _fila([
                      _dropdownApi(
                        'Organismo Certificador que lo oferta',
                        _organismoCertificador,
                        [
                          for (final o in _organismos)
                            MapEntry('${o['uuid']}', '${o['legal_name']}'),
                        ],
                        (v) => setState(() => _organismoCertificador = v),
                        cargando: _cargandoOrganismos,
                        habilitado: _estandarInicial != null,
                      ),
                      _fecha(
                        'Inicio de vigencia del contrato',
                        _inicioVigencia,
                        true,
                      ),
                    ]),
                    _fila([
                      _fecha(
                        'Fin de vigencia del contrato',
                        _finVigencia,
                        false,
                      ),
                    ]),

                    const Divider(height: 32),

                    // Domicilio
                    _titulo('Domicilio'),
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

                    // Personas de contacto
                    _titulo('Personas de contacto'),
                    const Text(
                      'Se usarán los datos de contacto para notificar el avance de la solicitud.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    if (_esCe) ...[
                      _contacto('Director del Centro', _director),
                      _contacto('Representante legal', _legal),
                      _contacto('Representante técnico', _tecnico),
                    ],
                    if (_esEi)
                      _contacto('Evaluador independiente', _independiente),

                    const Divider(height: 32),

                    // Expediente documental
                    _titulo('Expediente documental'),
                    if (_esCe) ...[
                      _fila([
                        _archivoPicker(
                          'Acta constitutiva',
                          _actaFile,
                          'acta',
                        ),
                        _archivoPicker('Poder legal', _poderFile, 'poder'),
                      ]),
                      _fila([
                        _archivoPicker(
                          'Convenio con el OC',
                          _convenioFile,
                          'convenio',
                        ),
                      ]),
                    ],
                    _fila([
                      _archivoPicker(
                        'Constancia de Situación Fiscal',
                        _csfFile,
                        'csf',
                      ),
                      _archivoPicker(
                        'Contrato con el OC',
                        _contratoFile,
                        'contrato',
                      ),
                    ]),
                    _fila([
                      _archivoPicker(
                        'Formato de solicitud',
                        _formatoFile,
                        'formato',
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Fotografías de las instalaciones'),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: _elegirFotos,
                            icon: const Icon(Icons.upload_outlined, size: 18),
                            label: const Text('Seleccionar archivo'),
                          ),
                          if (_fotos.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '${_fotos.length} fotografía(s) seleccionada(s)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ]),

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
