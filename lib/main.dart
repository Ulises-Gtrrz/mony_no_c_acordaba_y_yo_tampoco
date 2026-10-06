import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Organismo Certificador/organismo_certificador.dart';
import 'Centro Evaluador/centro_evaluador_admin.dart';
import 'evaluador.dart';
import 'candidato.dart';
import 'formulario.dart';

/// Cliente HTTP y cookie jar compartidos por toda la app.
late Dio dio;
late PersistCookieJar cookieJar;

/// Token Bearer devuelto por el login de WhatsApp (client_type "mobile").
/// Si es null, la app se autentica por cookie como siempre.
String? authToken;

const String _authTokenKey = 'auth_token';

const String _baseUrl = 'https://ocmax.mx';

/// Base para los endpoints de WhatsApp (ngrok para pruebas).
/// Cuando termines de probar, cámbiala por `_baseUrl`.
const String _whatsappBaseUrl = 'https://ocmax.mx';

Future<void> _initDio() async {
  final appDocDir = await getApplicationDocumentsDirectory();
  cookieJar = PersistCookieJar(
    ignoreExpires: false,
    storage: FileStorage('${appDocDir.path}/.cookies/'),
  );

  dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        // El backend entrega token (no cookie) si el UA parece móvil.
        'User-Agent': 'OCMAXApp/1.0 (Android; Mobile)',
        'X-Requested-With': 'XMLHttpRequest',
        'Origin': _baseUrl,
        'Referer': '$_baseUrl/',
      },
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  authToken = prefs.getString(_authTokenKey);

  dio.interceptors.add(CookieManager(cookieJar));

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = authToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final cookies = await cookieJar.loadForRequest(options.uri);
        debugPrint('--- COOKIES ENVIADAS a ${options.path} ---');
        if (cookies.isEmpty) {
          debugPrint('  (ninguna cookie guardada todavía)');
        }
        for (final c in cookies) {
          final preview = c.value.length > 20
              ? c.value.substring(0, 20)
              : c.value;
          debugPrint('  ${c.name} = $preview...');
        }
        handler.next(options);
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final cookies = await cookieJar.loadForRequest(Uri.parse(_baseUrl));
        final xsrfCookie = cookies.where((c) => c.name == 'XSRF-TOKEN');
        if (xsrfCookie.isNotEmpty) {
          options.headers['X-XSRF-TOKEN'] = Uri.decodeComponent(
            xsrfCookie.first.value,
          );
        }
        handler.next(options);
      },
    ),
  );
}

Future<void> _primeCsrfCookie() async {
  try {
    final response = await dio.get(
      '/api/v1/centers-evaluators/requests/get',
      queryParameters: {'page': 1, 'per_page': 1},
    );
    debugPrint('--- CSRF COOKIE RESPONSE ---');
    debugPrint('Status: ${response.statusCode}');
    debugPrint('Set-Cookie headers: ${response.headers['set-cookie']}');
  } catch (e) {
    debugPrint('No se pudo precargar la cookie CSRF: $e');
  }
}

Future<void> clearSession() async {
  await cookieJar.deleteAll();
  authToken = null;
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_authTokenKey);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initDio();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OC MAX Login',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A2342),
          primary: const Color(0xFF0A2342),
          secondary: const Color(0xFF38C9D6),
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1B6CA8), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  /// Rellena el formulario con las credenciales guardadas
  /// de la última vez, si es que el usuario eligió recordarlas.
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIdentifier = prefs.getString('saved_identifier');
    final savedPassword = prefs.getString('saved_password');
    final rememberMe = prefs.getBool('remember_me') ?? true;

    if (savedIdentifier != null) {
      _emailController.text = savedIdentifier;
    }
    if (savedPassword != null) {
      _passwordController.text = savedPassword;
    }
    if (mounted) setState(() => _rememberMe = rememberMe);
  }

  Future<void> _saveOrClearCredentials(
    String identifier,
    String password,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', _rememberMe);

    if (_rememberMe) {
      await prefs.setString('saved_identifier', identifier);
      await prefs.setString('saved_password', password);
    } else {
      await prefs.remove('saved_identifier');
      await prefs.remove('saved_password');
    }
  }

  /// Navega a la pantalla correspondiente según el rol del usuario.
  void _navigateByRole(Map<String, dynamic> user) {
    final institution = user['institution'] as Map<String, dynamic>?;
    final logoUrl = institution?['logo_url'] as String?;
    final role = user['role'] as String? ?? '';
    final userName = user['username'] as String? ?? '';

    Widget screen;
    if (role == 'CE Super Admin') {
      screen = CentroEvaluadorHomeScreen(
        userName: userName,
        logoUrl: logoUrl,
        role: role,
      );
    } else if (role == 'Evaluador') {
      screen = EvaluadorScreen(
        userName: userName,
        role: role,
        logoUrl: logoUrl,
      );
    } else if (role == 'Candidato') {
      screen = CandidatoScreen(
        userName: userName,
        role: role,
        logoUrl: logoUrl,
      );
    } else {
      screen = OrganismoScreen(logoUrl: logoUrl);
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => screen));
  }

  /// POST /api/v1/auth/whatsapp/request-code  { "phone": "..." }
  Future<void> _requestWhatsappCode() async {
    final phone = await showDialog<String>(
      context: context,
      builder: (_) => const _InputDialog(
        title: 'Recuperar por WhatsApp',
        label: 'Teléfono (10 dígitos)',
        icon: Icons.phone_outlined,
        keyboardType: TextInputType.phone,
        maxLength: 10,
        confirmText: 'Enviar código',
      ),
    );

    if (!mounted || phone == null) return;
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un teléfono de 10 dígitos')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await dio.post(
        '$_whatsappBaseUrl/api/v1/auth/whatsapp/request-code',
        data: {'phone': phone},
      );

      debugPrint('--- WHATSAPP CODE RESPONSE ---');
      debugPrint('Status: ${response.statusCode}');
      debugPrint('Body: ${response.data}');

      final body = response.data as Map<String, dynamic>;
      final message =
          body['message'] ??
          (body['success'] == true
              ? 'Si la cuenta existe, enviamos un código por WhatsApp.'
              : 'No se pudo solicitar el código');

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

      if (body['success'] == true) {
        final code = await showDialog<String>(
          context: context,
          builder: (_) => const _InputDialog(
            title: 'Ingresa el código',
            label: 'Código de 6 dígitos',
            icon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            maxLength: 6,
            confirmText: 'Verificar',
          ),
        );

        if (mounted && code != null && code.length == 6) {
          await _verifyWhatsappCode(phone, code);
        }
      }
    } catch (e) {
      debugPrint('--- WHATSAPP CODE ERROR ---');
      debugPrint(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// POST /api/v1/auth/whatsapp/verify
  /// { "phone": "...", "code": "...", "client_type": "web" }
  Future<void> _verifyWhatsappCode(String phone, String code) async {
    setState(() => _isLoading = true);

    try {
      final response = await dio.post(
        '$_whatsappBaseUrl/api/v1/auth/whatsapp/verify',
        data: {'phone': phone, 'code': code, 'client_type': 'mobile'},
      );

      debugPrint('--- WHATSAPP VERIFY RESPONSE ---');
      debugPrint('Status: ${response.statusCode}');
      debugPrint('Body: ${response.data}');

      final body = response.data as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        final user = data['user'] as Map<String, dynamic>;

        final logoUrl =
            (user['institution'] as Map<String, dynamic>?)?['logo_url']
                as String?;

        final prefs = await SharedPreferences.getInstance();
        if (logoUrl != null) {
          await prefs.setString('logo_url', logoUrl);
        }

        final token = data['token'] as String?;
        if (token != null && token.isNotEmpty) {
          authToken = token;
          await prefs.setString(_authTokenKey, token);
        }

        if (!mounted) return;
        _navigateByRole(user);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(body['message'] ?? 'Código inválido o expirado'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('--- WHATSAPP VERIFY ERROR ---');
      debugPrint(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleLogin() async {
    final identifier = _emailController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa tu correo y contraseña')),
      );
      return;
    }

    setState(() => _isLoading = true);

    authToken = null;
    (await SharedPreferences.getInstance()).remove(_authTokenKey);

    await _primeCsrfCookie();

    final requestBody = {'identifier': identifier, 'password': password};

    debugPrint('--- LOGIN REQUEST ---');
    debugPrint('URL: $_baseUrl/api/v1/auth/login');
    debugPrint('Body: ${jsonEncode(requestBody)}');

    try {
      final response = await dio.post('/api/v1/auth/login', data: requestBody);

      debugPrint('--- LOGIN RESPONSE ---');
      debugPrint('Status code: ${response.statusCode}');
      debugPrint('Body: ${response.data}');

      final body = response.data as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        final user = data['user'] as Map<String, dynamic>;
        final institution = user['institution'] as Map<String, dynamic>?;
        final logoUrl = institution?['logo_url'] as String?;

        // Guardamos (o borramos) las credenciales según "Recordarme",
        // y el logo para mostrarlo en la siguiente pantalla.
        await _saveOrClearCredentials(identifier, password);
        final prefs = await SharedPreferences.getInstance();
        if (logoUrl != null) await prefs.setString('logo_url', logoUrl);

        final token = data['token'] as String?;
        if (token != null && token.isNotEmpty) {
          authToken = token;
          await prefs.setString(_authTokenKey, token);
        }

        if (!mounted) return;

        // Según el rol del usuario, se manda a una pantalla distinta.
        _navigateByRole(user);
      } else {
        final message = body['message'] ?? 'No se pudo iniciar sesión';
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      }
    } catch (e) {
      debugPrint('--- LOGIN ERROR ---');
      debugPrint(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: size.height * 0.08),
              Image.asset(
                'assets/img/NORMAL.png',
                height: 140,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 48),
              Text(
                'Iniciar Sesión',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0A2342),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Ingresa tus credenciales para acceder.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo Electrónico',
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: Color(0xFF1B6CA8),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: Color(0xFF1B6CA8),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // RECORDARME
              Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _rememberMe,
                      activeColor: const Color(0xFF0A2342),
                      onChanged: (value) {
                        setState(() => _rememberMe = value ?? true);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Recordar mis datos',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isLoading ? null : _requestWhatsappCode,
                    child: const Text(
                      '¿Olvidaste tu contraseña?',
                      style: TextStyle(color: Color(0xFF1B6CA8), fontSize: 13),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2342),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'INGRESAR',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FormScreen()),
                    );
                  },
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text(
                    'REGISTRAR EMPRESA/PERSONA',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0A2342),
                    side: const BorderSide(color: Color(0xFF0A2342)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Organismo Certificador ',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Text(
                    'OC MAX',
                    style: TextStyle(
                      color: const Color(0xFF38C9D6),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

/// Diálogo con un campo de texto que administra su propio controller,
/// para evitar usarlo después de haberlo liberado (dispose).
class _InputDialog extends StatefulWidget {
  final String title;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;
  final int maxLength;
  final String confirmText;

  const _InputDialog({
    required this.title,
    required this.label,
    required this.icon,
    required this.keyboardType,
    required this.maxLength,
    required this.confirmText,
  });

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        keyboardType: widget.keyboardType,
        maxLength: widget.maxLength,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: Icon(widget.icon, color: const Color(0xFF1B6CA8)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(widget.confirmText),
        ),
      ],
    );
  }
}
