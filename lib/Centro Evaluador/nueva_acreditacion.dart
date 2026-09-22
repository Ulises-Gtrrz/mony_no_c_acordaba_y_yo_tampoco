import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../Organismo Certificador/candidatos.dart' show OCColors;

/// Formulario de "Nueva solicitud de acreditación".
///
/// Esta pantalla es solo la UI del formulario: no llama a ningún
/// endpoint. Los campos de Organismo Certificador y Estándar de
/// competencia están listos para recibir listas reales (por ejemplo,
/// vía un parámetro del constructor, o conectando aquí mismo la
/// llamada a `dio` cuando tengas las rutas confirmadas).
class NuevaAcreditacionScreen extends StatefulWidget {
  final String? logoUrl;

  /// Lista opcional de organismos certificadores a mostrar en el
  /// dropdown. Cada item debe traer al menos 'uuid' y 'legal_name'
  /// (o 'name'). Si se deja vacía, el dropdown aparece sin opciones.
  final List<Map<String, dynamic>> certifyingBodies;

  /// Lista opcional de estándares disponibles a mostrar en el
  /// dropdown. Cada item debe traer al menos 'uuid', 'code' y 'name'.
  final List<Map<String, dynamic>> standards;

  /// Callback que se dispara al presionar "Enviar solicitud", ya con
  /// el formulario validado. Aquí es donde se conectaría la llamada
  /// real al endpoint de envío cuando esté confirmado.
  final Future<void> Function({
    required String certifyingBodyUuid,
    required String standardUuid,
    required DateTime validFrom,
    required DateTime validUntil,
    required PlatformFile contractFile,
    required PlatformFile applicationFormFile,
  })?
  onSubmit;

  const NuevaAcreditacionScreen({
    super.key,
    this.logoUrl,
    this.certifyingBodies = const [],
    this.standards = const [],
    this.onSubmit,
  });

  @override
  State<NuevaAcreditacionScreen> createState() =>
      _NuevaAcreditacionScreenState();
}

class _NuevaAcreditacionScreenState extends State<NuevaAcreditacionScreen> {
  bool _isSubmitting = false;

  String? _selectedCertifyingBodyUuid;
  String? _selectedStandardUuid;

  DateTime? _validFrom;
  DateTime? _validUntil;

  PlatformFile? _contractFile;
  PlatformFile? _applicationFormFile;

  Future<void> _pickFile(bool isContract) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        if (isContract) {
          _contractFile = result.files.first;
        } else {
          _applicationFormFile = result.files.first;
        }
      });
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _validFrom = picked;
        } else {
          _validUntil = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'dd/mm/aaaa';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_selectedCertifyingBodyUuid == null) {
      _showSnack('Selecciona un Organismo Certificador');
      return;
    }
    if (_selectedStandardUuid == null) {
      _showSnack('Selecciona un Estándar de competencia');
      return;
    }
    if (_validFrom == null || _validUntil == null) {
      _showSnack('Completa la vigencia del contrato');
      return;
    }
    if (_contractFile == null) {
      _showSnack('Adjunta el Contrato con el Organismo Certificador');
      return;
    }
    if (_applicationFormFile == null) {
      _showSnack('Adjunta el Formato de solicitud');
      return;
    }

    if (widget.onSubmit == null) {
      // Sin endpoint conectado todavía: solo mostramos que el
      // formulario está completo y listo para enviarse.
      debugPrint('--- FORMULARIO LISTO (sin endpoint conectado) ---');
      debugPrint('certifying_body_uuid: $_selectedCertifyingBodyUuid');
      debugPrint('competence_standard_uuid: $_selectedStandardUuid');
      debugPrint('valid_from: ${_validFrom!.toIso8601String()}');
      debugPrint('valid_until: ${_validUntil!.toIso8601String()}');
      debugPrint('contract file: ${_contractFile!.name}');
      debugPrint('application form file: ${_applicationFormFile!.name}');
      _showSnack('Formulario completo (falta conectar el endpoint de envío)');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit!(
        certifyingBodyUuid: _selectedCertifyingBodyUuid!,
        standardUuid: _selectedStandardUuid!,
        validFrom: _validFrom!,
        validUntil: _validUntil!,
        contractFile: _contractFile!,
        applicationFormFile: _applicationFormFile!,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _showSnack('Error al enviar la solicitud: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
          'Nueva solicitud de acreditación',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AVISO
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: OCColors.mediumBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: OCColors.mediumBlue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: OCColors.mediumBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Un mismo estándar no puede acreditarse con dos organismos, '
                      'así que solo aparecen los estándares que todavía no tienes '
                      'acreditados.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ORGANISMO CERTIFICADOR
            _fieldLabel('Organismo Certificador'),
            _dropdownField<String>(
              value: _selectedCertifyingBodyUuid,
              hint: 'Elige el Organismo Certificador',
              items: widget.certifyingBodies.map((cb) {
                return DropdownMenuItem(
                  value: cb['uuid']?.toString(),
                  child: Text(
                    cb['legal_name']?.toString() ??
                        cb['name']?.toString() ??
                        '',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCertifyingBodyUuid = value;
                  // Al cambiar de organismo se limpia el estándar
                  // elegido, ya que la lista de estándares depende
                  // de qué organismo se seleccione.
                  _selectedStandardUuid = null;
                });
              },
            ),

            const SizedBox(height: 20),

            // ESTÁNDAR DE COMPETENCIA
            _fieldLabel('Estándar de competencia'),
            _dropdownField<String>(
              value: _selectedStandardUuid,
              hint: 'Elige el estándar que quieres acreditar',
              enabled: _selectedCertifyingBodyUuid != null,
              items: widget.standards.map((s) {
                return DropdownMenuItem(
                  value: s['uuid']?.toString(),
                  child: Text(
                    '${s['code'] ?? ''} - ${s['name'] ?? ''}',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedStandardUuid = value);
              },
            ),
            if (_selectedCertifyingBodyUuid != null && widget.standards.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                  'Este organismo no tiene estándares disponibles para tu institución.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),

            const SizedBox(height: 20),

            // VIGENCIA DEL CONTRATO
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('Inicio de vigencia del contrato'),
                      _dateField(_validFrom, () => _pickDate(true)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('Fin de vigencia del contrato'),
                      _dateField(_validUntil, () => _pickDate(false)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ARCHIVOS
            _fieldLabel('Contrato con el Organismo Certificador'),
            _fileField(_contractFile, () => _pickFile(true)),

            const SizedBox(height: 20),

            _fieldLabel('Formato de solicitud'),
            _fileField(_applicationFormFile, () => _pickFile(false)),

            const SizedBox(height: 28),

            // BOTONES
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OCColors.cyan,
                      foregroundColor: OCColors.darkBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Enviar solicitud',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OCColors.darkBlue,
                      side: const BorderSide(color: OCColors.cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: OCColors.darkBlue,
        ),
      ),
    );
  }

  Widget _dropdownField<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    bool enabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OCColors.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(
            hint,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
          isExpanded: true,
          items: enabled ? items : [],
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  Widget _dateField(DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: OCColors.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDate(date),
              style: TextStyle(
                fontSize: 13,
                color: date == null ? Colors.grey.shade500 : OCColors.darkBlue,
              ),
            ),
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: OCColors.mediumBlue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _fileField(PlatformFile? file, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: OCColors.cardBorder),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.upload_outlined,
              size: 18,
              color: OCColors.mediumBlue,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                file?.name ?? 'Seleccionar archivo',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: file == null ? OCColors.mediumBlue : OCColors.darkBlue,
                  fontWeight: file == null
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
