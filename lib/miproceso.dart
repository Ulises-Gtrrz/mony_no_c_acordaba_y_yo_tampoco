import 'package:flutter/material.dart';
import '../main.dart';
import '../Organismo Certificador/candidatos.dart' show OCColors;
import '../Organismo Certificador/proceso_candidatos.dart';
import 'proceso_detalle.dart';

class MiProcesoScreen extends StatefulWidget {
  final String? logoUrl;
  const MiProcesoScreen({super.key, this.logoUrl});

  @override
  State<MiProcesoScreen> createState() => _MiProcesoScreenState();
}

class _MiProcesoScreenState extends State<MiProcesoScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _busqueda = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProcesos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProcesos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    debugPrint('--- MI PROCESO REQUEST ---');
    debugPrint('URL: https://ocmax.mx/api/v1/candidates/me/processes');

    try {
      final response = await dio.get('/api/v1/candidates/me/processes');

      debugPrint('--- MI PROCESO RESPONSE ---');
      debugPrint('Status code: ${response.statusCode}');
      debugPrint('Body: ${response.data}');

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
              body['message'] ?? 'No se pudieron obtener tus procesos';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('--- MI PROCESO ERROR ---');
      debugPrint(e.toString());
      setState(() {
        _errorMessage = 'Error de conexión: $e';
        _isLoading = false;
      });
    }
  }

  Color _colorForStatus(String? code) {
    switch (code) {
      case 'approved':
        return const Color(0xFF00796B);
      case 'in_review':
        return OCColors.mediumBlue;
      case 'rejected':
        return const Color(0xFFC62828);
      case 'pending':
        return Colors.orange.shade800;
      default:
        return OCColors.mediumBlue;
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
          'Mi Proceso',
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: OCColors.mediumBlue),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: OCColors.darkBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchProcesos,
                style: ElevatedButton.styleFrom(
                  backgroundColor: OCColors.mediumBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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

    final procesosFiltrados = _items.where((proceso) {
      final standard = proceso['competence_standard'] as Map<String, dynamic>?;
      final nombre = standard?['name']?.toString() ?? '';
      final code = standard?['code']?.toString() ?? '';
      final query = _busqueda.toLowerCase();
      return nombre.toLowerCase().contains(query) ||
          code.toLowerCase().contains(query);
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchProcesos,
      color: OCColors.mediumBlue,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Buscador
            TextField(
              controller: _searchController,
              onChanged: (valor) {
                setState(() => _busqueda = valor);
              },
              decoration: InputDecoration(
                hintText: 'Buscar proceso...',
                prefixIcon: Icon(Icons.search, color: OCColors.mediumBlue),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: OCColors.cardBorder,
                    width: 0.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: OCColors.cardBorder,
                    width: 0.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: OCColors.mediumBlue,
                    width: 1.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            if (_items.isNotEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Mis procesos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: OCColors.darkBlue,
                  ),
                ),
              ),

            const SizedBox(height: 12),

            Expanded(
              child: _items.isEmpty
                  ? _buildEmptyState()
                  : procesosFiltrados.isEmpty
                  ? _buildNoResultsState()
                  : ListView.builder(
                      itemCount: procesosFiltrados.length,
                      itemBuilder: (context, index) =>
                          _buildProcesoCard(procesosFiltrados[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Se muestra cuando la API regresa data: [] (aún no tiene procesos)
  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: OCColors.mediumBlue.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.checklist_rtl_outlined,
                    size: 44,
                    color: OCColors.mediumBlue,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Aún no tienes procesos',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: OCColors.darkBlue,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Cuando inicies un proceso de certificación, aparecerá aquí.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: _fetchProcesos,
                  icon: Icon(
                    Icons.refresh,
                    color: OCColors.mediumBlue,
                    size: 18,
                  ),
                  label: Text(
                    'Actualizar',
                    style: TextStyle(color: OCColors.mediumBlue),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No se encontraron procesos',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildProcesoCard(Map<String, dynamic> proceso) {
    final processUuid = proceso['uuid']?.toString();
    final publicRef = proceso['public_reference']?.toString() ?? '';

    final standard = proceso['competence_standard'] as Map<String, dynamic>?;
    final standardName = standard?['name']?.toString() ?? 'Estándar sin nombre';
    final standardCode = standard?['code']?.toString() ?? '';

    final center = proceso['center'] as Map<String, dynamic>?;
    final centerName = center?['name']?.toString() ?? '';

    final status = proceso['status'] as Map<String, dynamic>?;
    final statusName = status?['name']?.toString() ?? '';
    final statusCode = status?['code']?.toString();
    final colorEstado = _colorForStatus(statusCode);

    final steps = proceso['process_steps'] as Map<String, dynamic>?;
    final percent = (steps?['percent'] as num?)?.toInt() ?? 0;
    final currentStep = steps?['current_step'];
    final totalSteps = steps?['total_steps'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: OCColors.cardBorder, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // ajusta la ruta

        // dentro de _buildProcesoCard, en el onTap:
        onTap: processUuid == null
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProcesoDetalleCandidatoScreen(
                      processUuid: processUuid,
                      logoUrl: widget.logoUrl,
                    ),
                  ),
                );
              },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: colorEstado.withOpacity(0.15),
                    child: Icon(Icons.school_outlined, color: colorEstado),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          standardName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: OCColors.darkBlue,
                          ),
                        ),
                        if (standardCode.isNotEmpty || publicRef.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              [
                                if (standardCode.isNotEmpty) standardCode,
                                if (publicRef.isNotEmpty) publicRef,
                              ].join(' · '),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        if (centerName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              centerName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Estado
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorEstado.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusName,
                      style: TextStyle(
                        color: colorEstado,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (currentStep != null && totalSteps != null)
                    Text(
                      'Paso $currentStep de $totalSteps',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 10),

              // Barra de avance
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: percent / 100,
                  minHeight: 6,
                  backgroundColor: OCColors.cardBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    OCColors.mediumBlue,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$percent% completado',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
