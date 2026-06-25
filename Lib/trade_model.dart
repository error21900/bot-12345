import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'api_service.dart';

class Trade {
  final String symbol;
  final String direction;
  final double price;
  final double quantity;
  final String timestamp;

  Trade({
    required this.symbol,
    required this.direction,
    required this.price,
    required this.quantity,
    required this.timestamp,
  });
}

class Position {
  final String symbol;
  final String side;
  final double contracts;
  final double entryPrice;
  final double unrealizedPnl;

  Position({
    required this.symbol,
    required this.side,
    required this.contracts,
    required this.entryPrice,
    required this.unrealizedPnl,
  });
}

class TradingProvider extends ChangeNotifier {
  ApiService? _api;

  bool _isRunning = false;
  bool _isInitialized = false;
  bool _isFetching = false; // Concurrency protection gate
  double _balance = 0.0;
  double _totalPnL = 0.0;
  String _lastUpdate = '--:--:--';
  String _statusMsg = 'Initializing...';
  String _selectedTimeframe = '15';

  Map<String, Position> _positions = {};
  List<Trade> _trades = [];
  Map<String, dynamic> _livePrices = {
    'BTCUSDT': {'lastPrice': '0', 'price24hPcnt': '0'},
    'SOLUSDT': {'lastPrice': '0', 'price24hPcnt': '0'},
    'LINKUSDT': {'lastPrice': '0', 'price24hPcnt': '0'},
    'XRPUSDT': {'lastPrice': '0', 'price24hPcnt': '0'},
  };
  Timer? _timer;

  bool get isRunning => _isRunning;
  bool get isInitialized => _isInitialized;
  double get balance => _balance;
  double get totalPnL => _totalPnL;
  String get lastUpdate => _lastUpdate;
  String get statusMsg => _statusMsg;
  String get selectedTimeframe => _selectedTimeframe;
  Map<String, Position> get positions => _positions;
  List<Trade> get trades => _trades;
  Map<String, dynamic> get livePrices => _livePrices;

  void initialize(ApiService api) {
    try {
      _api = api;
      _isInitialized = true;
      _statusMsg = 'Ready to start';
      debugPrint('✅ TradingProvider initialized successfully');
      notifyListeners();
    } catch (e) {
      _statusMsg = 'Initialization error: $e';
      debugPrint('❌ Initialization error: $e');
      notifyListeners();
    }
  }

  void updateTimeframe(String timeframe) {
    _selectedTimeframe = timeframe;
    _statusMsg = 'Timeframe switched to ${timeframe}M';
    notifyListeners();
  }

  void startBot() {
    if (!_isInitialized) {
      _statusMsg = 'Bot not initialized. Please log in again.';
      notifyListeners();
      return;
    }
    if (_isRunning) return;

    _isRunning = true;
    _statusMsg = 'Bot is RUNNING';
    WakelockPlus.enable();
    notifyListeners();
    _startPolling();
  }

  void stopBot() {
    _isRunning = false;
    _statusMsg = 'Bot STOPPED';
    _timer?.cancel();
    WakelockPlus.disable();
    notifyListeners();
  }

  void cancelPolling() => _timer?.cancel();

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_api == null) {
      _statusMsg = 'API Service not initialized';
      notifyListeners();
      return;
    }

    if (_isFetching) return; // Drop overlapping cycles if network is hanging
    _isFetching = true;

    try {
      final results = await Future.wait([
        _api!.fetchBalance(),
        _api!.fetchPositions(),
        _api!.fetchRecentTrades(),
        _api!.fetchLivePrices(),
      ]);

      _balance = results[0] as double;
      _positions = results[1] as Map<String, Position>;
      _trades = results[2] as List<Trade>;
      _livePrices = results[3] as Map<String, dynamic>;

      double pnl = 0;
      for (var p in _positions.values) {
        pnl += p.unrealizedPnl;
      }
      _totalPnL = pnl;

      final now = DateTime.now();
      _lastUpdate =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      if (_statusMsg.contains('Error')) {
        _statusMsg = 'Bot is RUNNING';
      }

      notifyListeners();
    } catch (e) {
      final errStr = e.toString();
      _statusMsg =
          'Error: ${errStr.length > 60 ? '${errStr.substring(0, 60)}...' : errStr}';
      debugPrint('❌ Refresh error: $e');
      notifyListeners();
    } finally {
      _isFetching = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }
}
