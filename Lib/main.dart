import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard.dart';
import 'api_service.dart';
import 'trade_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TradingProvider()),
      ],
      child: const SaadBotApp(),
    ),
  );
}

class SaadBotApp extends StatelessWidget {
  const SaadBotApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Saad Trading Bot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0E1A),
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C087),
            foregroundColor: Colors.black,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _apiKeyController = TextEditingController();
  final _apiSecretController = TextEditingController();
  bool _isLoading = false;
  String _statusMsg = '';
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _checkForSavedCredentials();
  }

  Future<void> _checkForSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKey = prefs.getString('bybit_api_key') ?? '';
      final savedSecret = prefs.getString('bybit_api_secret') ?? '';

      if (mounted && savedKey.isNotEmpty && savedSecret.isNotEmpty) {
        _apiKeyController.text = savedKey;
        _apiSecretController.text = savedSecret;
        setState(() => _statusMsg = '✅ Credentials found. Auto-logging in...');

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          _handleConnect(autoLogin: true);
        }
      }
    } catch (e) {
      print('Error checking saved credentials: $e');
      if (mounted) {
        setState(() => _statusMsg = 'Error loading saved credentials');
      }
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiSecretController.dispose();
    super.dispose();
  }

  Future<void> _handleConnect({bool autoLogin = false}) async {
    final key = _apiKeyController.text.trim();
    final secret = _apiSecretController.text.trim();

    if (key.isEmpty || secret.isEmpty) {
      _showMsg('❌ Please enter both API Key and Secret', isError: true);
      return;
    }
    if (key.length < 10) {
      _showMsg('❌ API Key appears too short', isError: true);
      return;
    }
    if (secret.length < 10) {
      _showMsg('❌ API Secret appears too short', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMsg = '🔗 Securing link with Bybit Demo...';
    });

    try {
      final apiService = ApiService(apiKey: key, apiSecret: secret);
      await apiService.testConnection();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('bybit_api_key', key);
        await prefs.setString('bybit_api_secret', secret);
      } catch (e) {
        print('⚠️ Warning: Could not save credentials: $e');
      }

      if (!mounted) return;

      final provider = Provider.of<TradingProvider>(context, listen: false);
      provider.initialize(apiService);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } on SocketException catch (e) {
      _showMsg('❌ Network Error: ${e.message}. Check your internet connection.',
          isError: true);
    } catch (e) {
      final errorMsg = e
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('SocketException: ', '')
          .trim();

      if (errorMsg.contains('Authentication failed') ||
          errorMsg.contains('retCode')) {
        _showMsg('❌ Authentication Failed: Invalid API credentials',
            isError: true);
      } else if (errorMsg.contains('Connection') ||
          errorMsg.contains('Network')) {
        _showMsg('❌ Connection Error: Unable to reach Bybit servers',
            isError: true);
      } else if (errorMsg.contains('account') || errorMsg.contains('null')) {
        _showMsg('❌ Account Error: Invalid account credentials', isError: true);
      } else {
        _showMsg('❌ Error: $errorMsg', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (mounted) setState(() => _statusMsg = msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Column(children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00C087), Color(0xFF0066FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00C087).withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.candlestick_chart_rounded,
                        size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Saad Bot',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  Text(
                    'Core Mechanical Execution Terminal',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ]),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _apiKeyController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Bybit Demo API Key',
                  hintText: 'Enter your demo API key',
                  filled: true,
                  fillColor: const Color(0xFF141B2D),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon:
                      const Icon(Icons.vpn_key, color: Color(0xFF00C087)),
                  labelStyle: TextStyle(color: Colors.grey[400]),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _apiSecretController,
                enabled: !_isLoading,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  labelText: 'Bybit Demo API Secret',
                  hintText: 'Enter your demo API secret',
                  filled: true,
                  fillColor: const Color(0xFF141B2D),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon:
                      const Icon(Icons.security, color: Color(0xFF00C087)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey[600],
                    ),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                  labelStyle: TextStyle(color: Colors.grey[400]),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 24),
              if (_statusMsg.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _statusMsg.contains('❌')
                        ? Colors.red.withValues(alpha: 0.1)
                        : const Color(0xFF00C087).withValues(alpha: 0.1),
                    border: Border.all(
                      color: _statusMsg.contains('❌')
                          ? Colors.red.withValues(alpha: 0.5)
                          : const Color(0xFF00C087).withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusMsg,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: _statusMsg.contains('❌')
                          ? Colors.red
                          : const Color(0xFF00C087),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _handleConnect(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C087),
                    disabledBackgroundColor: Colors.grey[800],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : const Text(
                          'ESTABLISH GATEWAY',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Using Demo Account\nNo real funds required',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
