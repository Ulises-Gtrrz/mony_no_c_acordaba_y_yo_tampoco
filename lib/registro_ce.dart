import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'main.dart' show dio;
// Ajusta esta importación a la ruta real donde tengas definidos los OCColors
import '../Organismo Certificador/candidatos.dart' show OCColors;

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

  // Personas de contacto
  final _director = _ContactoCtrl();
  final _legal = _ContactoCtrl();
  final _tecnico = _ContactoCtrl();
  final _independiente = _ContactoCtrl();

  // Catálogos cargados de la API
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
      if (mounted)
        _aviso('No se pudieron cargar los Organismos Certificadores');
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
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

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
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

  FormData _construirFormData() {
    final form = FormData();
    void campo(String k, String v) {
      if (v.trim().isNotEmpty) form.fields.add(MapEntry(k, v.trim()));
    }

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
      if (_actaFile != null)
        form.files.add(MapEntry('acta_constitutiva', _archivo(_actaFile!)));
      if (_poderFile != null)
        form.files.add(MapEntry('poder_legal', _archivo(_poderFile!)));
      if (_convenioFile != null)
        form.files.add(MapEntry('convenio', _archivo(_convenioFile!)));
    }
    if (_csfFile != null) form.files.add(MapEntry('csf', _archivo(_csfFile!)));
    if (_contratoFile != null)
      form.files.add(MapEntry('contrato', _archivo(_contratoFile!)));
    if (_formatoFile != null)
      form.files.add(MapEntry('formato_solicitud', _archivo(_formatoFile!)));
    for (final foto in _fotos) {
      form.files.add(MapEntry('fotografias_instalaciones[]', _archivo(foto)));
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

  void _aviso(String texto) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(texto),
      backgroundColor: OCColors.darkBlue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );

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

      final ok =
          res.statusCode != null &&
          res.statusCode! >= 200 &&
          res.statusCode! < 300;
      if (!ok) {
        _aviso(_mensajeError(res));
        return;
      }

      final folio = res.data is Map ? (res.data['data']?['folio']) : null;
      _aviso(
        folio != null
            ? 'Recibimos tu solicitud con el folio $folio.'
            : 'Recibimos tu solicitud.',
      );
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (mounted) {
        _aviso(
          e.response != null
              ? _mensajeError(e.response!)
              : 'Sin conexión con el servidor.',
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // ---------- Widgets de UI Mejorados ----------

  InputDecoration _inputDecoration({String? label, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: OCColors.cardBorder, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: OCColors.cardBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: OCColors.mediumBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
    );
  }

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
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: formatters,
      textCapitalization: capitalization,
      decoration: _inputDecoration(label: label, suffixIcon: suffixIcon),
    );
  }

  Widget _dropdownApi(
    String label,
    String? value,
    List<MapEntry<String, String>> items,
    ValueChanged<String?> onChanged, {
    bool cargando = false,
    bool habilitado = true,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: _inputDecoration(
        label: label,
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
      validator: (v) => (v == null || v.isEmpty) ? 'Campo obligatorio' : null,
    );
  }

  Widget _seccionTitulo(String texto, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        children: [
          Icon(icon, color: OCColors.mediumBlue, size: 24),
          const SizedBox(width: 10),
          Text(
            texto,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: OCColors.darkBlue,
            ),
          ),
        ],
      ),
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
          while (items.length < columnas) items.add(const SizedBox());
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

  Widget _contactoCard(String titulo, _ContactoCtrl c) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: OCColors.cardBorder),
      ),
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: OCColors.darkBlue,
              ),
            ),
            const Divider(height: 24),
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
            _campo(
              'WhatsApp',
              c.whatsapp,
              validator: _telVal,
              maxLength: 10,
              keyboardType: TextInputType.phone,
              formatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fechaField(String label, DateTime? valor, bool esInicio) {
    return TextFormField(
      readOnly: true,
      onTap: () => _seleccionarFecha(esInicio),
      decoration: _inputDecoration(
        label: label,
        suffixIcon: const Icon(Icons.calendar_today, size: 20),
      ),
      controller: TextEditingController(text: _fmt(valor)),
      validator: (_) => valor == null ? 'Campo obligatorio' : null,
    );
  }

  Widget _archivoCard(String label, PlatformFile? archivo, String tipo) {
    final tieneArchivo = archivo != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tieneArchivo ? const Color(0xFFE8F5E9) : Colors.white,
        border: Border.all(
          color: tieneArchivo ? Colors.green.shade300 : OCColors.cardBorder,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                tieneArchivo ? Icons.check_circle : Icons.upload_file,
                color: tieneArchivo ? Colors.green : OCColors.mediumBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: tieneArchivo
                        ? Colors.green.shade800
                        : OCColors.darkBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (tieneArchivo)
            Text(
              archivo.name,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          else
            Text(
              'No seleccionado',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _elegirArchivo(tipo),
              icon: const Icon(Icons.upload_outlined, size: 18),
              label: Text(tieneArchivo ? 'Cambiar' : 'Seleccionar'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: tieneArchivo ? Colors.green : OCColors.mediumBlue,
                ),
                foregroundColor: tieneArchivo
                    ? Colors.green
                    : OCColors.mediumBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
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
          'Solicitud CE / EI',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: OCColors.mediumBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.workspace_premium_outlined,
                              color: OCColors.mediumBlue,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Afiliación Inicial',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: OCColors.darkBlue,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Registro para Centros de Evaluación o Evaluadores Independientes.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 1. Datos de la Solicitud
                  _seccionTitulo('1. Datos de la Solicitud', Icons.description),
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: OCColors.cardBorder),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: _tipoRegistro,
                            isExpanded: true,
                            decoration: _inputDecoration(
                              label: 'Tipo de registro',
                            ),
                            items: const [_tipoCe, _tipoEi]
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _tipoRegistro = v),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Campo obligatorio'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _campo(
                            'Razón Social / Nombre Legal',
                            _razonSocialCtrl,
                            validator: _req,
                          ),
                          if (_esCe) const SizedBox(height: 16),
                          if (_esCe)
                            _campo(
                              'Nombre Comercial',
                              _nombreComercialCtrl,
                              validator: _req,
                            ),
                          const SizedBox(height: 16),
                          _fila([
                            _campo(
                              'RFC',
                              _rfcCtrl,
                              validator: _rfcVal,
                              maxLength: 13,
                              capitalization: TextCapitalization.characters,
                            ),
                            _campo(
                              'Nombre del Administrador',
                              _adminNombreCtrl,
                              validator: _req,
                            ),
                          ]),
                          _campo(
                            'Correo del Administrador',
                            _adminCorreoCtrl,
                            validator: _emailVal,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          _fila([
                            _dropdownApi(
                              'Estándar Inicial',
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
                            _dropdownApi(
                              'Organismo Certificador',
                              _organismoCertificador,
                              [
                                for (final o in _organismos)
                                  MapEntry(
                                    '${o['uuid']}',
                                    '${o['legal_name']}',
                                  ),
                              ],
                              (v) => setState(() => _organismoCertificador = v),
                              cargando: _cargandoOrganismos,
                              habilitado: _estandarInicial != null,
                            ),
                          ]),
                          _fila([
                            _fechaField(
                              'Inicio Vigencia Contrato',
                              _inicioVigencia,
                              true,
                            ),
                            _fechaField(
                              'Fin Vigencia Contrato',
                              _finVigencia,
                              false,
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. Domicilio
                  _seccionTitulo('2. Domicilio', Icons.location_on),
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: OCColors.cardBorder),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _fila([
                            _campo('Calle', _calleCtrl, validator: _req),
                            _campo('No. Ext', _numExtCtrl, validator: _req),
                            _campo('No. Int', _numIntCtrl),
                          ], columnas: 3),
                          _fila([
                            _campo(
                              'Código Postal',
                              _cpCtrl,
                              validator: _req,
                              maxLength: 5,
                              keyboardType: TextInputType.number,
                              formatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                            _campo('Colonia', _coloniaCtrl, validator: _req),
                            _campo(
                              'Localidad',
                              _localidadCtrl,
                              validator: _req,
                            ),
                          ], columnas: 3),
                          _fila([
                            _campo(
                              'Municipio',
                              _municipioCtrl,
                              validator: _req,
                            ),
                            _campo('Estado', _estadoCtrl, validator: _req),
                          ], columnas: 2),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: OCColors.mediumBlue,
                            value: _domicilioManual,
                            onChanged: (v) =>
                                setState(() => _domicilioManual = v ?? false),
                            title: const Text(
                              'Capturar domicilio manualmente',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Personas de Contacto
                  _seccionTitulo('3. Personas de Contacto', Icons.people),
                  if (_esCe) ...[
                    _contactoCard('Director del Centro', _director),
                    _contactoCard('Representante Legal', _legal),
                    _contactoCard('Representante Técnico', _tecnico),
                  ],
                  if (_esEi)
                    _contactoCard('Evaluador Independiente', _independiente),

                  const SizedBox(height: 24),

                  // 4. Expediente Documental
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: OCColors.cardBorder),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          if (_esCe) ...[
                            _fila([
                              _archivoCard(
                                'Acta Constitutiva',
                                _actaFile,
                                'acta',
                              ),
                              _archivoCard('Poder Legal', _poderFile, 'poder'),
                            ]),
                            _archivoCard(
                              'Convenio con el OC',
                              _convenioFile,
                              'convenio',
                            ),
                            const SizedBox(height: 16),
                          ],
                          _fila([
                            _archivoCard(
                              'Constancia Situación Fiscal',
                              _csfFile,
                              'csf',
                            ),
                            _archivoCard(
                              'Contrato con el OC',
                              _contratoFile,
                              'contrato',
                            ),
                          ]),
                          const SizedBox(height: 16),
                          _fila([
                            _archivoCard(
                              'Formato de Solicitud',
                              _formatoFile,
                              'formato',
                            ),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _fotos.isNotEmpty
                                    ? const Color(0xFFE8F5E9)
                                    : Colors.white,
                                border: Border.all(
                                  color: _fotos.isNotEmpty
                                      ? Colors.green.shade300
                                      : OCColors.cardBorder,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _fotos.isNotEmpty
                                            ? Icons.photo_library
                                            : Icons
                                                  .add_photo_alternate_outlined,
                                        color: _fotos.isNotEmpty
                                            ? Colors.green
                                            : OCColors.mediumBlue,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Fotografías Instalaciones',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: _fotos.isNotEmpty
                                              ? Colors.green.shade800
                                              : OCColors.darkBlue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (_fotos.isNotEmpty)
                                    Text(
                                      '${_fotos.length} seleccionadas',
                                      style: const TextStyle(fontSize: 12),
                                    )
                                  else
                                    Text(
                                      'Mínimo 1 foto requerida',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _elegirFotos,
                                      icon: const Icon(
                                        Icons.upload_outlined,
                                        size: 18,
                                      ),
                                      label: Text(
                                        _fotos.isNotEmpty
                                            ? 'Cambiar fotos'
                                            : 'Subir fotos',
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: _fotos.isNotEmpty
                                              ? Colors.green
                                              : OCColors.mediumBlue,
                                        ),
                                        foregroundColor: _fotos.isNotEmpty
                                            ? Colors.green
                                            : OCColors.mediumBlue,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 5. Términos y Botón
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: OCColors.cardBorder),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: OCColors.mediumBlue,
                            value: _aceptaTerminos,
                            onChanged: (v) =>
                                setState(() => _aceptaTerminos = v ?? false),
                            title: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'He leído y acepto los ',
                                  ),
                                  TextSpan(
                                    text: 'Términos y Condiciones',
                                    style: const TextStyle(
                                      color: OCColors.mediumBlue,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  const TextSpan(text: ' y el '),
                                  TextSpan(
                                    text: 'Aviso de Privacidad',
                                    style: const TextStyle(
                                      color: OCColors.mediumBlue,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  const TextSpan(text: '.'),
                                ],
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 12, top: 4),
                            child: Text(
                              'Se registrará tu IP y fecha de aceptación.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _enviando ? null : _enviar,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: OCColors.mediumBlue,
                                disabledBackgroundColor: Colors.grey.shade400,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _enviando
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'ENVIAR SOLICITUD',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
