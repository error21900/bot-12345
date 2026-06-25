import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';  // ✅ added for debugPrint
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
    try {
      const qs = 'category=linear&coin=USDT';
      final uri = Uri.parse('$_baseUrl/v5/account/wallet-balance?$qs');
      final res = await http
          .get(uri, headers: _headers(queryString: qs))
          .timeout(const Duration(seconds: 10));
      final body = jsonDecode(res.body);

      if (body['retCode'] != 0) {
        throw Exception(body['retMsg'] ?? 'Authentication failed');
      }
      if (body['result'] == null) {
        throw Exception('Invalid account structure - result is null');
      }
      debugPrint('✅ Connection test successful!');
    } on SocketException {
      throw Exception(
          'Network error: Unable to reach Bybit servers. Check your internet connection.');
    } catch (e) {
      throw Exception('Connection failed: ${e.toString()}');
    }
  }

  Future<double> fetchBalance() async {
    try {
      const qs = 'category=linear&coin=USDT';
      final uri = Uri.parse('$_baseUrl/v5/account/wallet-balance?$qs');
      final res = await http
          .get(uri, headers: _headers(queryString: qs))
          .timeout(const Duration(seconds: 10));
      final body = jsonDecode(res.body);

      if (body['retCode'] == 0) {
        final list = body['result']?['list'] as List? ?? [];
        if (list.isNotEmpty) {
          final coinList = list[0]['coin'] as List? ?? [];
          for (var c in coinList) {
            if (c['coin'] == 'USDT') {
              return double.tryParse(c['walletBalance'].toString()) ?? 0.0;
            }
          }
          return double.tryParse(list[0]['totalEquity'].toString()) ?? 0.0;
        }
      }
      return 0.0;
    } catch (e) {
      debugPrint('Error fetching balance: $e');
      return 0.0;
    }
  }

  Future<Map<String, Position>> fetchPositions() async {
    final map = <String, Position>{};
    try {
      const qs = 'category=linear&settleCoin=USDT';
      final uri = Uri.parse('$_baseUrl/v5/position/list?$qs');
      final res = await http
          .get(uri, headers: _headers(queryString: qs))
          .timeout(const Duration(seconds: 10));
      final body = jsonDecode(res.body);

      if (body['retCode'] == 0) {
        final list = body['result']?['list'] as List? ?? [];
        for (var p in list) {
          final size = double.tryParse(p['size'].toString()) ?? 0.0;
          if (size == 0) continue;

          final sym = p['symbol']?.toString() ?? 'UNKNOWN';
          final side = p['side']?.toString().toLowerCase() ?? 'unknown';

          map[sym] = Position(
            symbol: sym,
            side: side,
            contracts: size,
            entryPrice: double.tryParse(p['entryPrice'].toString()) ?? 0.0,
            unrealizedPnl:
                double.tryParse(p['unrealizedPnl'].toString()) ?? 0.0,
          );
        }
      }
      return map;
    } catch (e) {
      debugPrint('Error fetching positions: $e');
      return {};
    }
  }

  Future<List<List<double>>> fetchKlines(
      {required String symbol,
      required String interval,
      int limit = 60}) async {
    try {
      final uri = Uri.parse(
          '$_baseUrl/v5/market/kline?category=linear&symbol=$symbol&interval=$interval&limit=$limit');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final body = jsonDecode(res.body);

      if (body['retCode'] == 0) {
        final list = body['result']?['list'] as List? ?? [];
        final resultList = <List<double>>[];
        for (var item in list) {
          resultList.add([
            double.tryParse(item[1].toString()) ?? 0.0,
            double.tryParse(item[2].toString()) ?? 0.0,
            double.tryParse(item[3].toString()) ?? 0.0,
            double.tryParse(item[4].toString()) ?? 0.0,
          ]);
        }
        return resultList.reversed.toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching klines: $e');
      return [];
    }
  }

  // FIX: Fetch all prices in parallel instead of sequential loop
  Future<Map<String, Map<String, dynamic>>> fetchLivePrices() async {
    const coins = ['BTCUSDT', 'SOLUSDT', 'LINKUSDT', 'XRPUSDT'];
    final result = <String, Map<String, dynamic>>{};

    Future<MapEntry<String, Map<String, dynamic>>> fetchOne(
        String coin) async {
      try {
        final uri = Uri.parse(
            '$_baseUrl/v5/market/tickers?category=linear&symbol=$coin');
        final res = await http.get(uri).timeout(const Duration(seconds: 5));
        final body = jsonDecode(res.body);

        if (body['retCode'] == 0) {
          final list = body['result']?['list'] as List? ?? [];
          if (list.isNotEmpty) {
            final item = list[0];
            return MapEntry(coin, {
              'lastPrice': item['lastPrice']?.toString() ?? '0',
              'price24hPcnt': item['price24hPcnt']?.toString() ?? '0',
            });
          }
        }
      } catch (e) {
        debugPrint('Error fetching price for $coin: $e');
      }
      return MapEntry(coin, {'lastPrice': '0', 'price24hPcnt': '0'});
    }

    final entries =
        await Future.wait(coins.map((c) => fetchOne(c)));
    for (final entry in entries) {
      result[entry.key] = entry.value;
    }
    return result;
  }

  Future<bool> placeOrder({
    required String symbol,
    required String side,
    required double qty,
    bool reduceOnly = false,
  }) async {
    try {
      final bodyMap = {
        'category': 'linear',
        'symbol': symbol,
        'side': side,
        'orderType': 'Market',
        'qty': qty.toString(),
        'timeInForce': 'GTC',
        'reduceOnly': reduceOnly,
      };
      final bodyStr = jsonEncode(bodyMap);
      final uri = Uri.parse('$_baseUrl/v5/order/create');
      final res = await http
          .post(uri, headers: _headers(body: bodyStr), body: bodyStr)
          .timeout(const Duration(seconds: 12));
      final resBody = jsonDecode(res.body);

      if (resBody['retCode'] == 0) {
        debugPrint('✅ ORDER SUCCESS: $symbol $side $qty');
        return true;
      } else {
        debugPrint('❌ ORDER FAILED: ${resBody['retMsg'] ?? 'Unknown error'}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ ORDER EXCEPTION: $e');
      return false;
    }
  }

  Future<void> setLeverage(String symbol, String leverage) async {
    try {
      final bodyMap = {
        'category': 'linear',
        'symbol': symbol,
        'buyLeverage': leverage,
        'sellLeverage': leverage,
      };
      final bodyStr = jsonEncode(bodyMap);
      final uri = Uri.parse('$_baseUrl/v5/position/set-leverage');
      await http
          .post(uri, headers: _headers(body: bodyStr), body: bodyStr)
          .timeout(const Duration(seconds: 5));
      debugPrint('✅ Leverage set to $leverage for $symbol');
    } catch (e) {
      debugPrint('Error setting leverage: $e');
    }
  }

  Future<List<Trade>> fetchRecentTrades() async {
    final trades = <Trade>[];
    const coins = ['BTCUSDT', 'SOLUSDT', 'LINKUSDT', 'XRPUSDT'];

    Future<List<Trade>> fetchForCoin(String coin) async {
      final coinTrades = <Trade>[];
      try {
        final qs = 'category=linear&symbol=$coin&limit=3';
        final uri = Uri.parse('$_baseUrl/v5/order/history?$qs');
        final res = await http
            .get(uri, headers: _headers(queryString: qs))
            .timeout(const Duration(seconds: 10));
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

  String _formatTime(String msStr) {
    try {
      final ms = int.parse(msStr);
      if (ms == 0) return '--:--:--';
      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return '--:--:--';
    }
  }
}

// ❌ REMOVED the custom debugPrint – we use Flutter's built-in one.
