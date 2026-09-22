import 'package:flutter/material.dart';
import '../main.dart';
import 'centro_evaluador_detalle_screen.dart';

// Reutilizamos la paleta definida anteriormente para consistencia
class OCColors {
  static const darkBlue = Color(0xFF0A2342);
  static const mediumBlue = Color(0xFF1B6CA8);
  static const cyan = Color(0xFF38C9D6);
  static const bgLight = Color(0xFFF5F7FA);
  static const cardBorder = Color(0xFFE1E8ED);
}

class CentrosEvaluadoresScreen extends StatefulWidget {
  final String? logoUrl;

  const CentrosEvaluadoresScreen({super.key, this.logoUrl});

  @override
  State<CentrosEvaluadoresScreen> createState() =>
      _CentrosEvaluadoresScreenState();
}

class _CentrosEvaluadoresScreenState extends State<CentrosEvaluadoresScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchCentrosEvaluadores();
  }

  Future<void> _fetchCentrosEvaluadores() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await dio.get(
        '/api/v1/centers-evaluators/requests/get',
        queryParameters: {'page': 1, 'per_page': 15},
      );

      final body = response.data as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> data = body['data'] as List<dynamic>;
        setState(() {
          _items = data.cast<Map<String, dynamic>>();
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
      setState(() {
        _errorMessage = 'Error de conexión: $e';
        _isLoading = false;
      });
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Centros Evaluadores',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Gestión de solicitudes CE/EI',
              style: TextStyle(
                fontSize: 12,
                color: OCColors.cyan.withOpacity(0.9),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
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
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: OCColors.mediumBlue),
            const SizedBox(height: 16),
            Text(
              'Cargando registros...',
              style: TextStyle(color: OCColors.mediumBlue, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: OCColors.darkBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Verifica tu conexión e intenta nuevamente',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchCentrosEvaluadores,
                style: ElevatedButton.styleFrom(
                  backgroundColor: OCColors.mediumBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
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

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No hay registros disponibles',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchCentrosEvaluadores,
      color: OCColors.mediumBlue,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: _items.length,
        itemBuilder: (context, index) => _buildCard(_items[index]),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final legalName = item['legal_name'] as String? ?? '';
    final commercialName = item['commercial_name'] as String?;
    final rfc = item['rfc'] as String? ?? '';
    final type = item['type'] as String? ?? '';
    final registrationKey = item['registration_key'] as String? ?? '';
    final applicationUuid = item['application_uuid'] as String?;

    final status = item['status'] as Map<String, dynamic>?;
    final statusName = status?['name'] as String? ?? '';

    final operationalStatus =
        item['operational_status'] as Map<String, dynamic>?;
    final operationalStatusName = operationalStatus?['name'] as String?;

    final competenceStandard =
        item['competence_standard'] as Map<String, dynamic>?;
    final standardCode = competenceStandard?['code'] as String?;
    final standardName = competenceStandard?['name'] as String?;

    final logo = item['logo'] as Map<String, dynamic>?;
    final logoUrl = logo?['url'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shadowColor: OCColors.darkBlue.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: OCColors.cardBorder, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: applicationUuid == null
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CentroEvaluadorDetalleScreen(
                    applicationUuid: applicationUuid,
                    logoUrl: widget.logoUrl,
                  ),
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LOGO / AVATAR
              Hero(
                tag: 'logo_$applicationUuid',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: (logoUrl != null && logoUrl.isNotEmpty)
                      ? Image.network(
                          logoUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholderLogo(),
                        )
                      : _placeholderLogo(),
                ),
              ),
              const SizedBox(width: 14),

              // CONTENIDO PRINCIPAL
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre Comercial / Legal
                    Text(
                      commercialName?.isNotEmpty == true
                          ? commercialName!
                          : legalName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: OCColors.darkBlue,
                      ),
                    ),
                    if (commercialName?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          legalName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: OCColors.mediumBlue.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ),

                    const SizedBox(height: 10),

                    // Grid de Datos Clave
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        _miniDataPoint('RFC', rfc),
                        _miniDataPoint('Tipo', type),
                        if (standardCode != null || standardName != null)
                          _miniDataPoint(
                            'Estándar',
                            '${standardCode ?? ''} ${standardName ?? ''}',
                          ),
                        if (registrationKey.isNotEmpty)
                          _miniDataPoint('Clave', registrationKey),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Badges de Estado
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (statusName.isNotEmpty)
                          _statusChip(
                            statusName,
                            bgColor: OCColors.cyan.withOpacity(0.15),
                            textColor: OCColors.darkBlue,
                          ),
                        if (operationalStatusName != null &&
                            operationalStatusName.isNotEmpty)
                          _statusChip(
                            operationalStatusName,
                            bgColor: const Color(0xFF00796B).withOpacity(0.12),
                            textColor: const Color(0xFF00796B),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Indicador de Navegación Estilizado
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 8),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: OCColors.mediumBlue.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget auxiliar para datos compactos tipo "etiqueta: valor"
  Widget _miniDataPoint(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12, height: 1.3),
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              color: OCColors.mediumBlue.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: OCColors.darkBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para chips/badges consistentes
  Widget _statusChip(
    String label, {
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _placeholderLogo() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: OCColors.cyan.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.business_center_rounded,
        color: OCColors.mediumBlue.withOpacity(0.6),
        size: 28,
      ),
    );
  }
}
