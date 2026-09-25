import 'package:flutter/material.dart';
import '../main.dart';
import '../Organismo Certificador/candidatos.dart' show OCColors;

class MisCursosScreen extends StatefulWidget {
  final String? logoUrl;
  const MisCursosScreen({super.key, this.logoUrl});

  @override
  State<MisCursosScreen> createState() => _MisCursosScreenState();
}

class _MisCursosScreenState extends State<MisCursosScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _busqueda = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMisCursos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMisCursos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    debugPrint('--- MIS CURSOS REQUEST ---');
    debugPrint('URL: https://ocmax.mx/api/v1/my-courses/get');

    try {
      final response = await dio.get('/api/v1/my-courses/get');

      debugPrint('--- MIS CURSOS RESPONSE ---');
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
              body['message'] ?? 'No se pudieron obtener tus cursos';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('--- MIS CURSOS ERROR ---');
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
          'Mis Cursos',
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
                onPressed: _fetchMisCursos,
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

    final cursosFiltrados = _items.where((curso) {
      final nombre =
          curso['name']?.toString() ?? curso['nombre']?.toString() ?? '';
      return nombre.toLowerCase().contains(_busqueda.toLowerCase());
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchMisCursos,
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
                hintText: 'Buscar curso...',
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
                  : cursosFiltrados.isEmpty
                  ? _buildNoResultsState()
                  : ListView.builder(
                      itemCount: cursosFiltrados.length,
                      itemBuilder: (context, index) =>
                          _buildCursoCard(cursosFiltrados[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Se muestra cuando la API regresa data: [] (aún no está inscrito a nada)
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
                    Icons.school_outlined,
                    size: 44,
                    color: OCColors.mediumBlue,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Aún no tienes cursos',
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
                    'Cuando te inscribas a un curso, aparecerá aquí.',
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
                  onPressed: _fetchMisCursos,
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

  /// Se muestra cuando SÍ hay cursos pero el buscador no encuentra coincidencias
  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No se encontraron cursos',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildCursoCard(Map<String, dynamic> curso) {
    final nombre =
        curso['name']?.toString() ?? curso['nombre']?.toString() ?? 'Curso';
    final descripcion =
        curso['description']?.toString() ??
        curso['descripcion']?.toString() ??
        '';

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
          nombre,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: OCColors.darkBlue,
          ),
        ),
        subtitle: descripcion.isNotEmpty
            ? Text(
                descripcion,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              )
            : const Text('Curso en curso'),
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
