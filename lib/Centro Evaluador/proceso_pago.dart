import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../main.dart';
import '../../Organismo Certificador/candidatos.dart' show OCColors;

class ComprobantePagoScreen extends StatefulWidget {
  final String processUuid;
  final Map<String, dynamic> payment;

  const ComprobantePagoScreen({
    super.key,
    required this.processUuid,
    required this.payment,
  });

  @override
  State<ComprobantePagoScreen> createState() => _ComprobantePagoScreenState();
}

class _ComprobantePagoScreenState extends State<ComprobantePagoScreen> {
  bool _isOpeningReceipt = false;

  Map<String, dynamic>? get _status =>
      widget.payment['status'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _receipt =>
      widget.payment['receipt'] as Map<String, dynamic>?;
  Map<String, dynamic> get _caps =>
      (widget.payment['capabilities'] as Map<String, dynamic>?) ?? {};

  // ---------- Acciones ----------

  Future<void> _verComprobante() async {
    final receiptUuid = _receipt?['uuid'] as String?;
    if (receiptUuid == null || receiptUuid.isEmpty) {
      _showSnack('No hay comprobante para mostrar');
      return;
    }

    setState(() => _isOpeningReceipt = true);

    final path =
        '/api/v1/candidates/processes/${widget.processUuid}/documents/$receiptUuid/open';

    debugPrint('---VER COMPROBANTE REQUEST---');
    debugPrint('URL:$path');

    try {
      final response = await dio.post(path);

      debugPrint('---VER COMPROBANTE RESPONSE---');
      debugPrint('Status code:${response.statusCode}');
      debugPrint('Body:${response.data}');

      final body = response.data as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        final url = data['temporary_url'] as String?;

        if (url == null || url.isEmpty) {
          _showSnack('No se encontró la URL ddel comprobante');
          return;
        }

        final launched = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );

        if (!launched) _showSnack('No se pudo abrir el comprobante');
      } else if (response.statusCode == 401) {
        await clearSession();
        _showSnack('Tu sesión expiró.Vuelve a iniciar sesión.');
      } else {
        _showSnack(body['message'] ?? 'No se pudo abrir el comprobante');
      }
    } catch (e) {
      debugPrint('---VER COMPROBANTE ERROR---');
      debugPrint(e.toString());
      _showSnack('Error de conexión:$e');
    } finally {
      if (mounted) setState(() => _isOpeningReceipt = false);
    }
  }

  Future<void> _validarPago() async {
    final ok = await _confirm(
      title: 'Validar pago',
      message: '¿Confirmas que el comprobante es correcto?',
      confirmLabel: 'Validar',
    );
    if (ok != true) return;
    _showSnack('Pendiente de conectar con el endpoint de validación');
  }

  Future<void> _rechazarComprobante() async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar comprobante'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Motivo del rechazo',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text(
              'Rechazar',
              style: TextStyle(color: Color(0xFFC62828)),
            ),
          ),
        ],
      ),
    );
    if (note == null || note.isEmpty) return;
    _showSnack('Pendiente de conectar con el endpoint de rechazo');
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------- Helpers ----------

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '—';
    const meses = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final min = d.minute.toString().padLeft(2, '0');
    final suf = d.hour >= 12 ? 'p.m.' : 'a.m.';
    return '${d.day} ${meses[d.month - 1]} ${d.year}, $h12:$min $suf';
  }

  Color _statusColor(String? code) {
    switch (code) {
      case 'validated':
      case 'approved':
        return const Color(0xFF00796B);
      case 'rejected':
        return const Color(0xFFC62828);
      case 'submitted':
        return const Color(0xFF1976D2);
      default:
        return Colors.orange.shade800;
    }
  }

  String _bannerText(String? code) {
    switch (code) {
      case 'submitted':
        return 'Tu comprobante está en revisión. Te avisaremos cuando el Centro Evaluador lo valide.';
      case 'validated':
      case 'approved':
        return 'Tu pago fue validado correctamente.';
      case 'rejected':
        final note = widget.payment['rejection_note']?.toString();
        return (note != null && note.isNotEmpty)
            ? 'Tu comprobante fue rechazado: $note'
            : 'Tu comprobante fue rechazado.';
      default:
        return 'Aún no hay un comprobante de pago registrado.';
    }
  }

  IconData _bannerIcon(String? code) {
    switch (code) {
      case 'validated':
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.error;
      default:
        return Icons.info;
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final statusCode = _status?['code']?.toString();
    final statusName = _status?['name']?.toString() ?? '';
    final color = _statusColor(statusCode);

    return Scaffold(
      backgroundColor: OCColors.bgLight,
      appBar: AppBar(
        backgroundColor: OCColors.darkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Comprobante de pago',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: OCColors.cardBorder, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.credit_card,
                      size: 20,
                      color: OCColors.darkBlue,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: OCColors.darkBlue,
                            fontSize: 15,
                          ),
                          children: [
                            const TextSpan(
                              text: 'Paso 3 · ',
                              style: TextStyle(fontWeight: FontWeight.normal),
                            ),
                            const TextSpan(
                              text: 'Comprobante de pago',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (statusName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusName,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner informativo
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withOpacity(0.35)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(_bannerIcon(statusCode), color: color, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _bannerText(statusCode),
                              style: const TextStyle(
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

                    // Tabla de datos
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: OCColors.cardBorder),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          _tableRow(
                            'Archivo recibido',
                            _receipt?['original_name']?.toString() ?? '—',
                            shaded: true,
                          ),
                          _tableRow(
                            'Fecha de entrega',
                            _formatDate(
                              widget.payment['submitted_at'] as String?,
                            ),
                          ),
                          _tableRow(
                            'Fecha de validación',
                            _formatDate(
                              widget.payment['validated_at'] as String?,
                            ),
                            shaded: true,
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Botones apilados verticalmente y centrados
                    Center(
                      child: Column(
                        children: [
                          if (_caps['can_view_receipt'] == true &&
                              _receipt != null)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _isOpeningReceipt
                                    ? null
                                    : _verComprobante,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: OCColors.darkBlue,
                                  side: const BorderSide(
                                    color: OCColors.cardBorder,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                icon: _isOpeningReceipt
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.visibility_outlined,
                                        size: 18,
                                      ),
                                label: const Text('Ver comprobante'),
                              ),
                            ),
                          if (_caps['can_reject'] == true) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _rechazarComprobante,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFC62828),
                                  side: const BorderSide(
                                    color: Color(0xFFC62828),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text('Rechazar comprobante'),
                              ),
                            ),
                          ],
                          if (_caps['can_validate'] == true) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _validarPago,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: OCColors.mediumBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: const Text('Validar pago'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableRow(
    String label,
    String value, {
    bool shaded = false,
    bool isLast = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: shaded ? Colors.grey.shade100 : Colors.white,
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: OCColors.cardBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: OCColors.darkBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
