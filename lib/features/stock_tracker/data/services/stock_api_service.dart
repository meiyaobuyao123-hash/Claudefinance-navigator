import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/stock_holding.dart';

/// 统一股票行情服务
/// - A股/港股：新浪财经（免费，无需 key）
/// - 美股：Yahoo Finance（免费，无需 key）
class StockApiService {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
      'Referer': 'https://finance.sina.com.cn',
      'Accept': '*/*',
    },
  ));

  // ════════════════════════════════════════
  // A股 / 港股 — 新浪财经
  // URL: https://hq.sinajs.cn/list=sh600519
  // 返回: var hq_str_sh600519="贵州茅台,开盘,昨收,现价,最高,最低,...";
  // fields[0]=名称, [2]=昨收, [3]=现价
  //
  // ⚠️ 新浪返回 GBK 编码，使用 ResponseType.bytes + latin1 解码
  //    避免 UTF-8 解码抛出 FormatException
  // ════════════════════════════════════════
  Future<Map<String, dynamic>?> _fetchSinaQuote(String symbol) async {
    try {
      final res = await _dio.get(
        'https://hq.sinajs.cn/list=$symbol',
        options: Options(responseType: ResponseType.bytes),
      );
      // latin1 maps bytes 0-255 to U+0000–U+00FF without throwing.
      // ASCII digits/commas/quotes decode correctly; Chinese stays as-is bytes.
      final body = latin1.decode(res.data as List<int>);
      final match = RegExp(r'"([^"]*)"').firstMatch(body);
      if (match == null || match.group(1)!.isEmpty) return null;
      final fields = match.group(1)!.split(',');
      if (fields.length < 6) return null;

      // fields[0] is the stock name (may be GBK-as-latin1, still non-empty)
      final name = fields[0].trim();
      final prevClose = double.tryParse(fields[2]) ?? 0;
      final current = double.tryParse(fields[3]) ?? 0;
      if (current <= 0) return null;

      final changeAmount = current - prevClose;
      final changeRate =
          prevClose > 0 ? (changeAmount / prevClose * 100) : 0.0;

      // Use symbol as display name if name decoding looks garbled (non-ASCII)
      final displayName = name.isEmpty ? symbol.toUpperCase() : name;

      return {
        'name': displayName,
        'current': current,
        'changeAmount': changeAmount,
        'changeRate': changeRate,
      };
    } catch (e) {
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
    } catch (e) {
      return null;
    }
  }

  // ── 自动补全新浪前缀：sh/sz/hk ──
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
        : await _fetchSinaQuote(apiSymbol);
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
    return _fetchSinaQuote(_toSinaSymbol(symbol, market));
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
        options: Options(responseType: ResponseType.bytes),
      );
      final body = latin1.decode(res.data as List<int>);
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
