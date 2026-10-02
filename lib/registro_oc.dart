import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'main.dart' show dio;

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
  void dispose() {
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

  Widget _representante(String titulo, _RepCtrl r) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
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
          _fila([
            _campo(
              'WhatsApp',
              r.whatsapp,
              validator: _whatsappVal,
              maxLength: 10,
              keyboardType: TextInputType.phone,
              formatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ]),
        ],
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () => _elegirArchivo(key),
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

  Widget _fotosPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Fotografías de las Instalaciones'),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: _elegirFotos,
          icon: const Icon(Icons.upload_outlined, size: 18),
          label: const Text('Seleccionar fotografías'),
        ),
        if (_fotos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${_fotos.length} fotografía(s) seleccionada(s)',
              style: const TextStyle(fontSize: 12, color: Colors.green),
            ),
          ),
      ],
    );
  }

  // ---------- Envío ----------
  /// Agrega al multipart los datos de un representante como
  /// `contacts[tipo][campo]`, omitiendo los vacíos.
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

  /// Arma el multipart que espera `POST /public/register/oc`.
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
      form.files.add(MapEntry(remota, _archivo(_archivos[local]!)));
    });
    for (final foto in _fotos) {
      form.files.add(MapEntry('facility_photos[]', _archivo(foto)));
    }
    return form;
  }

  /// Extrae el mensaje del envelope de error de la API (message / errors).
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

  void _aviso(String texto) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(texto)));

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FA),
      appBar: AppBar(title: const Text('Acreditar Organismo (OC)')),
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
                          child: Icon(Icons.shield_outlined, color: primary),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Acreditar Organismo (OC)',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Envía la solicitud de registro de tu OC',
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

                    // Datos legales
                    _titulo('Datos legales'),
                    _fila([
                      _campo(
                        'Razón Social (Nombre Legal)',
                        _razonSocialCtrl,
                        hint: 'Ej. Instituto Certificador de Competencias',
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
                        hint: 'RFC CON HOMOCLAVE (12 O 13 CARACTERES)',
                        validator: _rfcVal,
                        maxLength: 13,
                        capitalization: TextCapitalization.characters,
                      ),
                      _campo(
                        'Nombre del Administrador del OC',
                        _adminNombreCtrl,
                        hint: 'Ej. Ing. Carlos Salinas',
                        validator: _req,
                      ),
                    ]),
                    _fila([
                      _campo(
                        'Correo del Administrador (Email OC)',
                        _adminCorreoCtrl,
                        hint: 'carlos.salinas@tu-oc.com',
                        validator: _emailVal,
                        keyboardType: TextInputType.emailAddress,
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

                    // Representantes
                    _titulo('Representantes'),
                    const Text(
                      'Registra a las tres personas responsables del OC. El número de WhatsApp se usa para notificarles el avance de la solicitud.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        border: Border.all(color: const Color(0xFF90CAF9)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info, color: Color(0xFF1677FF)),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Credenciales de administrador',
                                  style: TextStyle(fontSize: 16),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Si la solicitud es aprobada, las credenciales de administrador se enviarán al Correo del Administrador y al correo del Representante técnico. El identificador para iniciar sesión será siempre el Correo del Administrador.',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _representante('Director general', _director),
                    _representante('Representante legal', _legal),
                    _representante('Representante técnico', _tecnico),

                    const Divider(height: 32),

                    // Expediente documental
                    _titulo('Expediente documental'),
                    _fila([
                      _archivoPicker('Acta Constitutiva', 'acta'),
                      _archivoPicker('Poder del Representante Legal', 'poder'),
                    ]),
                    _fila([
                      _archivoPicker(
                        'Constancia de Situación Fiscal (CSF)',
                        'csf',
                      ),
                      _archivoPicker(
                        'Convenio vigente con CONOCER',
                        'convenio',
                      ),
                    ]),
                    _fila([_fotosPicker()]),

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
                                      onTap: () {
                                        /* abrir Términos */
                                      },
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
                                      onTap: () {
                                        /* abrir Aviso */
                                      },
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
                            : const Text('Enviar Solicitud'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        'No se generan credenciales al enviar la solicitud. Las recibirás únicamente si el registro es aprobado.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.black54),
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
