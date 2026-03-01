import 'package:dio/dio.dart';
import '../models/stock_holding.dart';

/// 统一股票行情服务
/// - A股/港股：新浪财经（免费，无需 key）
/// - 美股：Yahoo Finance（免费，无需 key）
class StockApiService {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
    },
  ));

  // ════════════════════════════════════════
  // A股 / 港股 — 新浪财经
  // URL: https://hq.sinajs.cn/list=sh600519
  // 返回: var hq_str_sh600519="贵州茅台,开盘,昨收,现价,最高,最低,...";
  // fields[0]=名称, [2]=昨收, [3]=现价
  // ════════════════════════════════════════
  Future<Map<String, dynamic>?> _fetchSinaQuote(String symbol) async {
    try {
      final res = await _dio.get(
        'https://hq.sinajs.cn/list=$symbol',
        options: Options(responseType: ResponseType.plain),
      );
      final body = res.data as String;
      final match = RegExp(r'"([^"]*)"').firstMatch(body);
      if (match == null || match.group(1)!.isEmpty) return null;
      final fields = match.group(1)!.split(',');
      if (fields.length < 6) return null;

      final name = fields[0].trim();
      final prevClose = double.tryParse(fields[2]) ?? 0;
      final current = double.tryParse(fields[3]) ?? 0;
      if (current <= 0 || name.isEmpty) return null;

      final changeAmount = current - prevClose;
      final changeRate =
          prevClose > 0 ? (changeAmount / prevClose * 100) : 0.0;

      return {
        'name': name,
        'current': current,
        'changeAmount': changeAmount,
        'changeRate': changeRate,
      };
    } catch (_) {
      return null;
    }
  }

  // ════════════════════════════════════════
  // 美股 — Yahoo Finance
  // URL: https://query1.finance.yahoo.com/v8/finance/chart/AAPL
  // ════════════════════════════════════════
  Future<Map<String, dynamic>?> _fetchYahooQuote(String symbol) async {
    try {
      final res = await _dio.get(
        'https://query1.finance.yahoo.com/v8/finance/chart/$symbol',
        queryParameters: {'interval': '1d', 'range': '1d'},
      );
      final result = (res.data['chart']['result'] as List?)?.first;
      if (result == null) return null;
      final meta = result['meta'] as Map<String, dynamic>;

      final current =
          (meta['regularMarketPrice'] as num?)?.toDouble() ?? 0;
      if (current <= 0) return null;

      final changeAmount =
          (meta['regularMarketChange'] as num?)?.toDouble() ?? 0;
      final changeRate =
          (meta['regularMarketChangePercent'] as num?)?.toDouble() ?? 0;
      final name =
          (meta['shortName'] ?? meta['longName'] ?? meta['symbol']) as String;

      return {
        'name': name,
        'current': current,
        'changeAmount': changeAmount,
        'changeRate': changeRate,
      };
    } catch (_) {
      return null;
    }
  }

  // ── 统一拉取行情（用于添加时验证 + 初始价填充）──
  Future<StockHolding?> fetchStockInfo(
      String symbol, String market) async {
    final data = market == 'US'
        ? await _fetchYahooQuote(symbol)
        : await _fetchSinaQuote(symbol);
    if (data == null) return null;

    final current = (data['current'] as num).toDouble();
    return StockHolding(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      symbol: symbol,
      stockName: data['name'] as String,
      market: market,
      shares: 0,
      costPrice: current,
      addedDate: DateTime.now().toIso8601String().substring(0, 10),
      currentPrice: current,
      changeRate: (data['changeRate'] as num).toDouble(),
      changeAmount: (data['changeAmount'] as num).toDouble(),
    );
  }

  // ── 刷新单只股票行情 ──
  Future<Map<String, dynamic>?> refreshQuote(
      String symbol, String market) async {
    if (market == 'US') return _fetchYahooQuote(symbol);
    return _fetchSinaQuote(symbol);
  }

  // ════════════════════════════════════════
  // 搜索
  // ════════════════════════════════════════

  Future<List<Map<String, String>>> searchStock(
      String keyword, String market) async {
    if (market == 'US') return _searchYahoo(keyword);
    return _searchSina(keyword, market);
  }

  /// 新浪 A股/港股 搜索
  /// type=11 沪, 12 深, 31 港股
  Future<List<Map<String, String>>> _searchSina(
      String keyword, String market) async {
    final type = market == 'HK' ? '31' : '11,12';
    try {
      final res = await _dio.get(
        'https://suggest3.sinajs.cn/suggest/type=$type&key=${Uri.encodeComponent(keyword)}&token=&rn=8',
        options: Options(responseType: ResponseType.plain),
      );
      final body = res.data as String;
      final match = RegExp(r'"([^"]*)"').firstMatch(body);
      if (match == null || match.group(1)!.isEmpty) return [];

      final results = <Map<String, String>>[];
      for (final item in match.group(1)!.split(';')) {
        final parts = item.split(',');
        if (parts.length < 3) continue;
        final typeCode = parts.length > 1 ? parts[1] : '';
        String prefix;
        if (typeCode == '11') {
          prefix = 'sh';
        } else if (typeCode == '12') {
          prefix = 'sz';
        } else if (typeCode == '31') {
          prefix = 'hk';
        } else {
          continue;
        }
        final code = parts.length > 2 ? parts[2] : '';
        final name = parts[0];
        if (code.isEmpty || name.isEmpty) continue;
        results.add({'symbol': '$prefix$code', 'name': name});
        if (results.length >= 6) break;
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// Yahoo Finance 美股搜索
  Future<List<Map<String, String>>> _searchYahoo(String keyword) async {
    try {
      final res = await _dio.get(
        'https://query2.finance.yahoo.com/v1/finance/search',
        queryParameters: {
          'q': keyword,
          'quotesCount': 8,
          'enableFuzzyQuery': false,
        },
      );
      final quotes = res.data['quotes'] as List? ?? [];
      return quotes
          .where((q) =>
              q['quoteType'] == 'EQUITY' || q['quoteType'] == 'ETF')
          .map<Map<String, String>>((q) => {
                'symbol': q['symbol'] as String,
                'name':
                    (q['shortname'] ?? q['longname'] ?? q['symbol'])
                        as String,
              })
          .take(6)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
