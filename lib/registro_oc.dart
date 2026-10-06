import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'main.dart' show dio;
// Ajusta esta importación a la ruta real donde tengas definidos los OCColors
import '../Organismo Certificador/candidatos.dart' show OCColors;

class _RepCtrl {
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

class RegistroOcScreen extends StatefulWidget {
  const RegistroOcScreen({super.key});

  @override
  State<RegistroOcScreen> createState() => _RegistroOcScreenState();
}

class _RegistroOcScreenState extends State<RegistroOcScreen> {
  final _formKey = GlobalKey<FormState>();

  // Datos legales
  final _razonSocialCtrl = TextEditingController();
  final _nombreComercialCtrl = TextEditingController();
  final _rfcCtrl = TextEditingController();
  final _adminNombreCtrl = TextEditingController();
  final _adminCorreoCtrl = TextEditingController();

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
  bool _buscandoCp = false;
  String? _cpError;
  List<String> _colonias = [];
  String? _coloniaSel;

  // Representantes
  final _director = _RepCtrl();
  final _legal = _RepCtrl();
  final _tecnico = _RepCtrl();

  // Documentos
  final Map<String, PlatformFile?> _archivos = {
    'acta': null,
    'poder': null,
    'csf': null,
    'convenio': null,
  };
  List<PlatformFile> _fotos = [];

  bool _aceptaTerminos = false;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _cpCtrl.addListener(_onCpChanged);
  }

  @override
  void dispose() {
    _cpCtrl.removeListener(_onCpChanged);
    for (final c in [
      _razonSocialCtrl,
      _nombreComercialCtrl,
      _rfcCtrl,
      _adminNombreCtrl,
      _adminCorreoCtrl,
      _calleCtrl,
      _numExtCtrl,
      _numIntCtrl,
      _cpCtrl,
      _coloniaCtrl,
      _localidadCtrl,
      _municipioCtrl,
      _estadoCtrl,
    ]) {
      c.dispose();
    }
    _director.dispose();
    _legal.dispose();
    _tecnico.dispose();
    super.dispose();
  }

  // ---------- Lógica de CP ----------
  void _onCpChanged() {
    final cp = _cpCtrl.text.trim();
    if (cp.length != 5) {
      if (_colonias.isNotEmpty ||
          _municipioCtrl.text.isNotEmpty ||
          _estadoCtrl.text.isNotEmpty) {
        _limpiarDatosCp();
      }
      if (_cpError != null) setState(() => _cpError = null);
      return;
    }
    _buscarCp(cp);
  }

  void _limpiarDatosCp() {
    setState(() {
      _colonias = [];
      _coloniaSel = null;
      _coloniaCtrl.clear();
      _municipioCtrl.clear();
      _estadoCtrl.clear();
      _cpError = null;
    });
  }

  Future<void> _buscarCp(String cp) async {
    if (_buscandoCp) return;
    setState(() {
      _buscandoCp = true;
      _cpError = null;
    });
    try {
      final res = await dio.get('/api/v1/zip-codes/$cp');
      if (!mounted) return;

      final body = res.data;
      if (body is! Map || body['success'] != true) {
        setState(() {
          _cpError = 'No encontramos información para ese CP';
          _colonias = [];
        });
        return;
      }

      final data = body['data'] as Map;
      final state = data['state']?['name'] as String? ?? '';
      final municipality = data['municipality']?['name'] as String? ?? '';
      final settlements =
          (data['settlements'] as List?)?.cast<Map>() ?? <Map>[];

      final nombres = settlements
          .map((s) => (s['name'] as String? ?? '').trim())
          .where((n) => n.isNotEmpty)
          .toList();

      setState(() {
        _estadoCtrl.text = state.toUpperCase();
        _municipioCtrl.text = municipality.toUpperCase();
        _colonias = nombres;
        if (nombres.length == 1) {
          _coloniaSel = nombres.first;
          _coloniaCtrl.text = nombres.first;
        } else {
          _coloniaSel = null;
          _coloniaCtrl.clear();
        }
        _cpError = null;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _cpError = e.response?.statusCode == 404
            ? 'Código postal no encontrado'
            : 'No se pudo consultar el CP. Intenta de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _buscandoCp = false);
    }
  }

  // ---------- Validadores ----------
  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null;

  String? _rfcVal(String? v) {
    if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
    final ok = RegExp(
      r'^[A-ZÑ&]{3,4}\d{6}[A-Z0-9]{3}$',
    ).hasMatch(v.trim().toUpperCase());
    return ok ? null : 'RFC inválido (12 o 13 caracteres)';
  }

  String? _curpVal(String? v) {
    if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
    final ok = RegExp(
      r'^[A-Z]{4}\d{6}[HMX][A-Z]{2}[B-DF-HJ-NP-TV-Z]{3}[A-Z0-9]\d$',
    ).hasMatch(v.trim().toUpperCase());
    return ok ? null : 'CURP inválida (18 caracteres)';
  }

  String? _emailVal(String? v) {
    if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    return ok ? null : 'Correo inválido';
  }

  String? _whatsappVal(String? v) {
    if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
    return RegExp(r'^\d{10}$').hasMatch(v.trim())
        ? null
        : 'Debe tener 10 dígitos';
  }

  // ---------- Widgets de UI Mejorados ----------

  // Estilo base para inputs
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
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
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

  Widget _representante(String titulo, _RepCtrl r) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: OCColors.cardBorder),
      ),
      margin: const EdgeInsets.only(bottom: 16),
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
              _campo('Nombre completo', r.nombre, validator: _req),
              _campo(
                'Correo',
                r.correo,
                validator: _emailVal,
                keyboardType: TextInputType.emailAddress,
              ),
            ]),
            _fila([
              _campo(
                'RFC',
                r.rfc,
                validator: _rfcVal,
                maxLength: 13,
                capitalization: TextCapitalization.characters,
              ),
              _campo(
                'CURP',
                r.curp,
                validator: _curpVal,
                maxLength: 18,
                capitalization: TextCapitalization.characters,
              ),
            ]),
            _campo(
              'WhatsApp',
              r.whatsapp,
              validator: _whatsappVal,
              maxLength: 10,
              keyboardType: TextInputType.phone,
              formatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
      ),
    );
  }

  Widget _campoColonia() {
    if (_colonias.isEmpty) {
      return _campo(
        'Colonia',
        _coloniaCtrl,
        validator: _req,
        hint: _domicilioManual ? 'Escribe tu colonia' : 'Se llena con el CP',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _coloniaSel,
          isExpanded: true,
          decoration: _inputDecoration(label: 'Colonia'),
          items: _colonias
              .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) {
            setState(() {
              _coloniaSel = v;
              _coloniaCtrl.text = v ?? '';
            });
          },
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Selecciona una colonia' : null,
        ),
      ],
    );
  }

  // ---------- Archivos ----------
  Future<void> _elegirArchivo(String key) async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (res != null && res.files.isNotEmpty) {
      setState(() => _archivos[key] = res.files.first);
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

  Widget _archivoPicker(String label, String key) {
    final archivo = _archivos[key];
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
            child: OutlinedButton(
              onPressed: () => _elegirArchivo(key),
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
              child: Text(tieneArchivo ? 'Cambiar archivo' : 'Subir archivo'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fotosPicker() {
    final hayFotos = _fotos.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hayFotos ? const Color(0xFFE8F5E9) : Colors.white,
        border: Border.all(
          color: hayFotos ? Colors.green.shade300 : OCColors.cardBorder,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hayFotos
                    ? Icons.photo_library
                    : Icons.add_photo_alternate_outlined,
                color: hayFotos ? Colors.green : OCColors.mediumBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Fotografías de las Instalaciones',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: hayFotos ? Colors.green.shade800 : OCColors.darkBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hayFotos)
            Text(
              '${_fotos.length} fotografía(s) seleccionada(s)',
              style: const TextStyle(fontSize: 12),
            )
          else
            Text(
              'Mínimo 1 foto requerida',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _elegirFotos,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: hayFotos ? Colors.green : OCColors.mediumBlue,
                ),
                foregroundColor: hayFotos ? Colors.green : OCColors.mediumBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                hayFotos ? 'Cambiar fotografías' : 'Seleccionar fotografías',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Envío ----------
  void _agregarContacto(FormData form, String tipo, _RepCtrl r) {
    final campos = {
      'full_name': r.nombre.text.trim(),
      'email': r.correo.text.trim(),
      'rfc': r.rfc.text.trim().toUpperCase(),
      'curp': r.curp.text.trim().toUpperCase(),
      'phone': r.whatsapp.text.trim(),
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

    campo('legal_name', _razonSocialCtrl.text);
    campo('commercial_name', _nombreComercialCtrl.text);
    campo('rfc', _rfcCtrl.text.toUpperCase());
    campo('admin_name', _adminNombreCtrl.text);
    campo('admin_email', _adminCorreoCtrl.text);

    campo('address[street]', _calleCtrl.text);
    campo('address[ext_num]', _numExtCtrl.text);
    campo('address[int_num]', _numIntCtrl.text);
    campo('address[zip_code]', _cpCtrl.text);
    campo('address[neighborhood]', _coloniaCtrl.text);
    campo('address[locality]', _localidadCtrl.text);
    campo('address[municipality]', _municipioCtrl.text);
    campo('address[state]', _estadoCtrl.text);

    _agregarContacto(form, 'director', _director);
    _agregarContacto(form, 'legal_representative', _legal);
    _agregarContacto(form, 'technical_representative', _tecnico);

    form.fields.add(const MapEntry('terms_accepted', '1'));

    const claves = {
      'acta': 'acta_constitutiva',
      'poder': 'poder_legal',
      'csf': 'csf',
      'convenio': 'conocer_agreement',
    };
    claves.forEach((local, remota) {
      if (_archivos[local] != null)
        form.files.add(MapEntry(remota, _archivo(_archivos[local]!)));
    });
    for (final foto in _fotos) {
      form.files.add(MapEntry('facility_photos[]', _archivo(foto)));
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

  Future<void> _enviar() async {
    if (_enviando) return;
    if (!_formKey.currentState!.validate()) return;

    final faltantes = _archivos.values.any((a) => a == null) || _fotos.isEmpty;
    if (faltantes) {
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
        '/api/v1/public/register/oc',
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

  void _aviso(String texto) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(texto),
      backgroundColor: OCColors.darkBlue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );

  // ---------- UI Principal ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OCColors.bgLight,
      appBar: AppBar(
        backgroundColor: OCColors.darkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Acreditar Organismo (OC)',
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
                              Icons.shield_outlined,
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
                                  'Solicitud de Registro',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: OCColors.darkBlue,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Completa la información para acreditar tu Organismo Certificador ante CONOCER.',
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

                  // 1. Datos Legales
                  _seccionTitulo('1. Datos Legales', Icons.business),
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
                            _campo(
                              'Razón Social',
                              _razonSocialCtrl,
                              hint: 'Nombre Legal',
                              validator: _req,
                            ),
                            _campo(
                              'Nombre Comercial',
                              _nombreComercialCtrl,
                              hint: 'Ej. Certifica MX',
                              validator: _req,
                            ),
                          ]),
                          _fila([
                            _campo(
                              'RFC',
                              _rfcCtrl,
                              hint: 'Con Homoclave',
                              validator: _rfcVal,
                              maxLength: 13,
                              capitalization: TextCapitalization.characters,
                            ),
                            _campo(
                              'Admin. del OC',
                              _adminNombreCtrl,
                              hint: 'Nombre completo',
                              validator: _req,
                            ),
                          ]),
                          _campo(
                            'Correo Admin',
                            _adminCorreoCtrl,
                            hint: 'correo@ejemplo.com',
                            validator: _emailVal,
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. Domicilio
                  _seccionTitulo('2. Domicilio Fiscal', Icons.location_on),
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _campo(
                                  'Código Postal',
                                  _cpCtrl,
                                  validator: _req,
                                  maxLength: 5,
                                  keyboardType: TextInputType.number,
                                  formatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  suffixIcon: _buscandoCp
                                      ? const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        )
                                      : const Icon(Icons.search, size: 20),
                                ),
                                if (_cpError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 4,
                                      left: 12,
                                    ),
                                    child: Text(
                                      _cpError!,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            _campoColonia(),
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
                            onChanged: (v) {
                              setState(() => _domicilioManual = v ?? false);
                              if (_domicilioManual) {
                                _limpiarDatosCp();
                              } else {
                                final cp = _cpCtrl.text.trim();
                                if (cp.length == 5) _buscarCp(cp);
                              }
                            },
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

                  // 3. Representantes
                  _seccionTitulo('3. Representantes', Icons.people),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: OCColors.cyan.withOpacity(0.15),
                      border: Border.all(color: OCColors.cyan.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: OCColors.mediumBlue),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Las credenciales de administrador se enviarán al correo del Administrador y del Representante Técnico si la solicitud es aprobada.',
                            style: TextStyle(
                              fontSize: 13,
                              color: OCColors.darkBlue,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _representante('Director General', _director),
                  _representante('Representante Legal', _legal),
                  _representante('Representante Técnico', _tecnico),

                  const SizedBox(height: 24),

                  // 4. Expediente
                  _seccionTitulo('4. Expediente Documental', Icons.folder_open),
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
                            _archivoPicker('Acta Constitutiva', 'acta'),
                            _archivoPicker('Poder Legal', 'poder'),
                          ]),
                          _fila([
                            _archivoPicker(
                              'Constancia Situación Fiscal',
                              'csf',
                            ),
                            _archivoPicker('Convenio CONOCER', 'convenio'),
                          ]),
                          const SizedBox(height: 16),
                          _fotosPicker(),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Términos y Botón
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
                            value: _aceptaTerminos,
                            activeColor: OCColors.mediumBlue,
                            onChanged: (v) =>
                                setState(() => _aceptaTerminos = v ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
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
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              'Al enviar, registraremos tu IP y fecha de aceptación.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
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
