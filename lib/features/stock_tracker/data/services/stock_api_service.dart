import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/stock_holding.dart';

/// 统一股票行情服务
/// - A股/港股：腾讯财经（UTF-8，免费无 key）https://qt.gtimg.cn/q=sh600519
/// - 美股：Yahoo Finance（免费，无需 key）
class StockApiService {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
      'Referer': 'https://finance.qq.com',
      'Accept': '*/*',
    },
  ));

  // ════════════════════════════════════════
  // A股 / 港股 — 腾讯财经（UTF-8）
  // URL: https://qt.gtimg.cn/q=sh600519
  // 返回: v_sh600519="1~贵州茅台~600519~1455.02~1466.12~1455.02~1468.89~1450.01~...";
  // fields[1]=名称, [3]=现价, [4]=昨收
  // ════════════════════════════════════════
  Future<Map<String, dynamic>?> _fetchTencentQuote(String symbol) async {
    try {
      final res = await _dio.get(
        'https://qt.gtimg.cn/q=$symbol',
        options: Options(responseType: ResponseType.plain),
      );
      final body = res.data as String;
      final match = RegExp(r'"([^"]*)"').firstMatch(body);
      if (match == null || match.group(1)!.isEmpty) return null;
      final fields = match.group(1)!.split('~');
      if (fields.length < 10) return null;

      final name = fields[1].trim();
      final current = double.tryParse(fields[3]) ?? 0;
      final prevClose = double.tryParse(fields[4]) ?? 0;
      if (current <= 0) return null;

      final changeAmount = current - prevClose;
      final changeRate =
          prevClose > 0 ? (changeAmount / prevClose * 100) : 0.0;

      return {
        'name': name.isEmpty ? symbol.toUpperCase() : name,
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

  // ── 自动补全腾讯/新浪前缀：sh/sz/hk ──
  // 用户输入 "600519" → "sh600519"，"000001" → "sz000001"，"00700" → "hk00700"
  // 若已有前缀则原样返回
  String _toSinaSymbol(String symbol, String market) {
    final lower = symbol.toLowerCase();
    if (lower.startsWith('sh') ||
        lower.startsWith('sz') ||
        lower.startsWith('hk')) {
      return lower; // 已带前缀
    }
    if (market == 'HK') return 'hk$symbol';
    // A股：6开头→上海(sh)，0/3开头→深圳(sz)
    if (symbol.startsWith('6')) return 'sh$symbol';
    return 'sz$symbol';
  }

  // ── 统一拉取行情（用于添加时验证 + 初始价填充）──
  Future<StockHolding?> fetchStockInfo(
      String symbol, String market) async {
    final apiSymbol =
        market == 'US' ? symbol : _toSinaSymbol(symbol, market);
    final data = market == 'US'
        ? await _fetchYahooQuote(apiSymbol)
        : await _fetchTencentQuote(apiSymbol);
    if (data == null) return null;

    final current = (data['current'] as num).toDouble();
    return StockHolding(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      symbol: apiSymbol, // 存带前缀的完整代码，刷新时直接用
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
    // symbol 已是带前缀格式（sh600519），直接用
    return _fetchTencentQuote(_toSinaSymbol(symbol, market));
  }

  // ════════════════════════════════════════
  // 搜索
  // ════════════════════════════════════════

  Future<List<Map<String, String>>> searchStock(
      String keyword, String market) async {
    if (market == 'US') return _searchYahoo(keyword);
    return _searchSina(keyword, market);
  }

  /// 新浪 A股/港股 搜索（suggest3.sinajs.cn 返回 UTF-8）
  /// type=11 沪, 12 深, 31 港股
  Future<List<Map<String, String>>> _searchSina(
      String keyword, String market) async {
    final type = market == 'HK' ? '31' : '11,12';
    try {
      final res = await _dio.get(
        'https://suggest3.sinajs.cn/suggest/type=$type&key=${Uri.encodeComponent(keyword)}&token=&rn=8',
        options: Options(responseType: ResponseType.bytes),
      );
      // suggest3.sinajs.cn 返回 UTF-8，若出现乱码 fallback 到 latin1
      String body;
      try {
        body = utf8.decode(res.data as List<int>);
      } catch (_) {
        body = latin1.decode(res.data as List<int>);
      }
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
