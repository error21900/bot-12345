import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'trade_model.dart';

class ApiService {
  final String apiKey;
  final String apiSecret;
  static const String _baseUrl = 'https://api-demo.bybit.com';

  ApiService({required this.apiKey, required this.apiSecret});

  String _sign(String payload) {
    final key = utf8.encode(apiSecret);
    final data = utf8.encode(payload);
    return Hmac(sha256, key).convert(data).toString();
  }

  Map<String, String> _headers({String body = '', String queryString = ''}) {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    const recvWindow = '20000';
    final raw = '$ts$apiKey$recvWindow${body.isNotEmpty ? body : queryString}';
    return {
      'X-BAPI-API-KEY': apiKey,
      'X-BAPI-TIMESTAMP': ts,
      'X-BAPI-RECV-WINDOW': recvWindow,
      'X-BAPI-SIGN': _sign(raw),
      'Content-Type': 'application/json',
    };
  }

  Future<void> testConnection() async {
    const qs = 'category=linear&coin=USDT';
    final uri = Uri.parse('$_baseUrl/v5/account/wallet-balance?$qs');
    final res = await http.get(uri, headers: _headers(queryString: qs)).timeout(const Duration(seconds: 10));
    final body = jsonDecode(res.body);
    if (body['retCode'] != 0) {
      throw Exception(body['retMsg'] ?? 'Authentication rejected');
    }
  }

  Future<double> fetchBalance() async {
    try {
      const qs = 'accountType=UNIFIED';
      final uri = Uri.parse('$_baseUrl/v5/account/wallet-balance?$qs');
      final res = await http.get(uri, headers: _headers(queryString: qs)).timeout(const Duration(seconds: 10));
      final body = jsonDecode(res.body);
      if (body['retCode'] == 0) {
        final list = body['result']?['list'] as List? ?? [];
        if (list.isNotEmpty) {
          return double.tryParse(list[0]['totalEquity']?.toString() ?? '0.0') ?? 0.0;
        }
      }
    } catch (e) {
      debugPrint('Execution processing balance error: $e');
    }
    return 0.0;
  }

  Future<Map<String, Position>> fetchPositions() async {
    final Map<String, Position> activePositions = {};
    try {
      const qs = 'category=linear&settleCoin=USDT';
      final uri = Uri.parse('$_baseUrl/v5/position/list?$qs');
      final res = await http.get(uri, headers: _headers(queryString: qs)).timeout(const Duration(seconds: 10));
      final body = jsonDecode(res.body);
      if (body['retCode'] == 0) {
        final list = body['result']?['list'] as List? ?? [];
        for (final item in list) {
          final double size = double.tryParse(item['size']?.toString() ?? '0') ?? 0;
          if (size > 0) {
            final sym = item['symbol']?.toString() ?? 'UNKNOWN';
            activePositions[sym] = Position(
              symbol: sym,
              side: item['side']?.toString().toUpperCase() ?? 'LONG',
              contracts: size,
              entryPrice: double.tryParse(item['entryPrice']?.toString() ?? '0') ?? 0,
              unrealizedPnl: double.tryParse(item['unrealisedPnl']?.toString() ?? '0') ?? 0,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Execution processing positions error: $e');
    }
    return activePositions;
  }

  Future<List<Trade>> fetchRecentTrades() async {
    final List<Trade> trades = [];
    final coins = ['BTCUSDT', 'ETHUSDT', 'SOLUSDT'];

    Future<List<Trade>> fetchForCoin(String coin) async {
      final List<Trade> coinTrades = [];
      try {
        final qs = 'category=linear&symbol=$coin&limit=5';
        final uri = Uri.parse('$_baseUrl/v5/order/history?$qs');
        final res = await http.get(uri, headers: _headers(queryString: qs)).timeout(const Duration(seconds: 10));
        final body = jsonDecode(res.body);

        if (body['retCode'] != 0) return [];

        final list = body['result']?['list'] as List? ?? [];
        for (final o in list) {
          if (o['orderStatus'] != 'Filled') continue;
          coinTrades.add(Trade(
            symbol: o['symbol']?.toString() ?? coin,
            direction: o['side']?.toString() == 'Buy' ? 'LONG' : 'SHORT',
            price: double.tryParse(o['avgPrice'].toString()) ?? 0,
            quantity: double.tryParse(o['qty'].toString()) ?? 0,
            timestamp: _formatTime(o['createdTime']?.toString() ?? '0'),
          ));
        }
      } catch (e) {
        debugPrint('Error fetching trades for $coin: $e');
      }
      return coinTrades;
    }

    final results = await Future.wait(coins.map((c) => fetchForCoin(c)));
    for (final list in results) {
      trades.addAll(list);
    }

    trades.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return trades;
  }

  Future<Map<String, dynamic>> fetchLivePrices() async {
    final Map<String, dynamic> output = {
      'BTCUSDT': {'price': '0.00', 'change': '0.00%'},
      'ETHUSDT': {'price': '0.00', 'change': '0.00%'},
      'SOLUSDT': {'price': '0.00', 'change': '0.00%'},
    };
    try {
      const qs = 'category=linear';
      final uri = Uri.parse('$_baseUrl/v5/market/tickers?$qs');
      final res = await http.get(uri, headers: _headers(queryString: qs)).timeout(const Duration(seconds: 10));
      final body = jsonDecode(res.body);
      if (body['retCode'] == 0) {
        final list = body['result']?['list'] as List? ?? [];
        for (final item in list) {
          final sym = item['symbol']?.toString();
          if (output.containsKey(sym)) {
            final lastPrice = double.tryParse(item['lastPrice']?.toString() ?? '0') ?? 0;
            final price24h = double.tryParse(item['prevPrice24h']?.toString() ?? '0') ?? 0;
            double change = 0.0;
            if (price24h > 0) {
              change = ((lastPrice - price24h) / price24h) * 100;
            }
            output[sym!] = {
              'price': lastPrice.toStringAsFixed(sym == 'SOLUSDT' ? 2 : 1),
              'change': '${change >= 0 ? "+" : ""}${change.toStringAsFixed(2)}%',
            };
          }
        }
      }
    } catch (e) {
      debugPrint('Ticker ingestion exception caught: $e');
    }
    return output;
  }

  String _formatTime(String msStr) {
    try {
      // Safe conversion alternative prevents runtime crash on null/empty inputs
      final ms = int.tryParse(msStr) ?? 0;
      if (ms == 0) return '--:--:--';
      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return '--:--:--';
    }
  }
}
