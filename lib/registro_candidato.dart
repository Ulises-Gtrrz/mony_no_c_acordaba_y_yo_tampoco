import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'main.dart' show dio;
// Ajusta esta importación a la ruta real donde tengas definidos los OCColors
import '../Organismo Certificador/candidatos.dart' show OCColors;

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

  void _mostrarModalFotoCandidato() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 700, // 👈 modal más ancho
              maxHeight: 700,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.photo_camera,
                        color: OCColors.mediumBlue,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Fotografía del Candidato',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: OCColors.darkBlue,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 👇 Imagen más grande y con zoom interactivo
                  Flexible(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 5.0,
                        child: Image.asset(
                          'assets/img/mony.png',
                          fit: BoxFit.contain,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 400,
                              alignment: Alignment.center,
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.broken_image,
                                size: 80,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'La fotografía debe ser reciente, tipo credencial, '
                    'rostro descubierto y fondo claro.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            foregroundColor: OCColors.mediumBlue,
                            side: const BorderSide(color: OCColors.mediumBlue),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _elegirArchivo('foto');
                          },
                          icon: const Icon(Icons.upload, size: 18),
                          label: const Text('Subir foto'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: OCColors.mediumBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------- Envío ----------
  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  MultipartFile _archivo(PlatformFile f) =>
      MultipartFile.fromBytes(f.bytes!, filename: f.name);

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

    form.fields.add(MapEntry('terms_accepted', flag(_aceptaTerminos)));
    form.fields.add(MapEntry('sensitive_data_accepted', flag(_aceptaTerminos)));
    form.fields.add(
      MapEntry('accepts_email_notifications', flag(_avisosCorreo)),
    );
    form.fields.add(
      MapEntry('accepts_whatsapp_notifications', flag(_avisosWhatsApp)),
    );
    form.fields.add(
      MapEntry(
        'authorizes_information_publication',
        flag(_autorizaPublicacion == 'Sí, autorizo'),
      ),
    );

    if (_ineFile != null) form.files.add(MapEntry('ine', _archivo(_ineFile!)));
    if (_curpPdfFile != null)
      form.files.add(MapEntry('curp_doc', _archivo(_curpPdfFile!)));
    if (_comprobanteFile != null)
      form.files.add(MapEntry('comprobante', _archivo(_comprobanteFile!)));
    if (_fotoFile != null)
      form.files.add(MapEntry('foto', _archivo(_fotoFile!)));
    if (_firmaFile != null)
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

      final ok =
          res.statusCode != null &&
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

  Widget _fechaNacimientoField() {
    return TextFormField(
      readOnly: true,
      onTap: _seleccionarFechaNacimiento,
      decoration: _inputDecoration(
        label: 'Fecha de Nacimiento',
        suffixIcon: const Icon(Icons.calendar_today, size: 20),
      ),
      validator: (_) => _fechaNacimiento == null ? 'Campo obligatorio' : null,
      controller: TextEditingController(text: _fmt(_fechaNacimiento)),
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

  Widget _archivoCard(
    String label,
    PlatformFile? archivo,
    String tipo, {
    bool isCamera = false,
    VoidCallback? onTapExtra,
  }) {
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
              onPressed: () {
                if (onTapExtra != null) {
                  onTapExtra();
                } else {
                  _elegirArchivo(tipo);
                }
              },
              icon: Icon(
                isCamera ? Icons.camera_alt_outlined : Icons.upload_outlined,
                size: 18,
              ),
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
          'Registro de Candidato',
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
                              Icons.person_outline,
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
                                  'Solicitud de Certificación',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: OCColors.darkBlue,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Completa tus datos para iniciar el proceso.',
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

                  // 1. Datos Personales
                  _seccionTitulo('1. Datos Personales', Icons.badge),
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
                          _campo(
                            'Nombre Completo',
                            _nombreCtrl,
                            hint: 'Como aparece en tu identificación',
                            validator: _req,
                            capitalization: TextCapitalization.characters,
                          ),
                          const SizedBox(height: 16),
                          _fila([
                            _campo(
                              'CURP',
                              _curpCtrl,
                              validator: _curpVal,
                              maxLength: 18,
                              capitalization: TextCapitalization.characters,
                            ),
                            _campo(
                              'RFC (Opcional)',
                              _rfcCtrl,
                              validator: _rfcVal,
                              maxLength: 13,
                              capitalization: TextCapitalization.characters,
                            ),
                          ]),
                          _fila([
                            _campo(
                              'Correo Electrónico',
                              _correoCtrl,
                              validator: _emailVal,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            _campo(
                              'Teléfono',
                              _telefonoCtrl,
                              validator: _telVal,
                              maxLength: 10,
                              keyboardType: TextInputType.phone,
                              formatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
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
                                    'Entidad Federativa',
                                    _entidadNacimiento,
                                    [
                                      for (final e in _estados)
                                        MapEntry(
                                          '${e['uuid']}',
                                          '${e['name']}',
                                        ),
                                    ],
                                    (v) =>
                                        setState(() => _entidadNacimiento = v),
                                  ),
                            _dropdownApi(
                              'Grado de Estudios',
                              _gradoEstudios,
                              _gradosEstudios,
                              (v) => setState(() => _gradoEstudios = v),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. Domicilio
                  _seccionTitulo('2. Domicilio Particular', Icons.home),
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

                  // 3. Proceso de Certificación
                  _seccionTitulo('3. Proceso de Certificación', Icons.school),
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
                          _dropdownApi(
                            'Centro de Evaluación',
                            _centroEvaluador,
                            [
                              for (final c in _centros)
                                MapEntry('${c['uuid']}', '${c['legal_name']}'),
                            ],
                            _elegirCentro,
                            cargando: _cargandoCentros,
                          ),
                          const SizedBox(height: 16),
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
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. Expediente Documental
                  _seccionTitulo('4. Expediente Documental', Icons.folder),
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
                            _archivoCard(
                              'Identificación Oficial (INE/Pasaporte)',
                              _ineFile,
                              'ine',
                            ),
                            _archivoCard(
                              'CURP Oficial (PDF)',
                              _curpPdfFile,
                              'curpPdf',
                            ),
                          ]),
                          _archivoCard(
                            'Comprobante de Domicilio',
                            _comprobanteFile,
                            'comprobante',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 5. Foto y Firma
                  _seccionTitulo('5. Fotografía y Firma', Icons.camera_alt),
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
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: OCColors.cyan.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: OCColors.mediumBlue,
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'La fotografía debe ser reciente, tipo credencial, rostro descubierto y fondo claro.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: OCColors.darkBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _fila([
                            _archivoCard(
                              'Fotografía del Candidato',
                              _fotoFile,
                              'foto',
                              isCamera: true,
                              onTapExtra: _mostrarModalFotoCandidato,
                            ),
                            _archivoCard(
                              'Firma Digitalizada',
                              _firmaFile,
                              'firma',
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 6. Avisos y Términos
                  _seccionTitulo('6. Consentimientos', Icons.policy),
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
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: OCColors.mediumBlue,
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
                            activeColor: OCColors.mediumBlue,
                            value: _avisosWhatsApp,
                            onChanged: (v) =>
                                setState(() => _avisosWhatsApp = v ?? false),
                            title: const Text(
                              'Deseo recibir avisos por WhatsApp',
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _autorizaPublicacion,
                            isExpanded: true,
                            decoration: _inputDecoration(
                              label:
                                  '¿Autorizas la publicación de tu información?',
                            ),
                            items: const ['Sí, autorizo', 'No autorizo']
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _autorizaPublicacion = v),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Campo obligatorio'
                                : null,
                          ),
                          const Divider(height: 32),
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
                              'Consiento el tratamiento de mis datos sensibles para fines de evaluación.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Botón Enviar
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
