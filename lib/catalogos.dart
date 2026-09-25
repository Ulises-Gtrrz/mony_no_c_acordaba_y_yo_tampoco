import 'package:flutter/material.dart';
import '../main.dart';
import '../Organismo Certificador/candidatos.dart' show OCColors;

class CatalogScreen extends StatefulWidget {
  final String? logoUrl;
  const CatalogScreen({super.key, this.logoUrl});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCatalogo();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCatalogo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    debugPrint('--- CATALOGO CURSOS REQUEST ---');
    debugPrint('URL: https://ocmax.mx/api/v1/course-orders/catalog');

    try {
      final response = await dio.get('/api/v1/course-orders/catalog');

      debugPrint('--- CATALOGO CURSOS RESPONSE ---');
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
          _errorMessage = body['message'] ?? 'No se pudo obtener el catálogo';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('--- CATALOGO CURSOS ERROR ---');
      debugPrint(e.toString());
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
        title: const Text(
          'Catálogo de Cursos',
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
                onPressed: _fetchCatalogo,
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

    return RefreshIndicator(
      onRefresh: _fetchCatalogo,
      color: OCColors.mediumBlue,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Buscador
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar catálogo...',
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

            Expanded(
              child: _items.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) =>
                          _buildCatalogCard(_items[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      // ListView para que RefreshIndicator siga funcionando aunque
      // esté vacío.
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
                    Icons.menu_book_outlined,
                    size: 44,
                    color: OCColors.mediumBlue,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Sin cursos disponibles',
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
                    'Tu Organismo Certificador aún no ha publicado cursos en el catálogo.',
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
                  onPressed: _fetchCatalogo,
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

  Widget _buildCatalogCard(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? 'Curso sin nombre';
    final description = item['description']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: OCColors.cardBorder, width: 0.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: OCColors.cyan.withOpacity(0.18),
          child: const Icon(
            Icons.menu_book_outlined,
            color: OCColors.mediumBlue,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: OCColors.darkBlue,
          ),
        ),
        subtitle: description.isNotEmpty
            ? Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              )
            : const Text('Curso disponible'),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey.shade400,
        ),
        onTap: () {
          // Acción al seleccionar un curso
        },
      ),
    );
  }
}
