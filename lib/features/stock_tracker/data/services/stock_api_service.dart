import 'package:dio/dio.dart';
import '../models/stock_holding.dart';

/// 统一股票行情服务
/// ─ A股/港股：东方财富 API（UTF-8 JSON，免费无 key）
///   行情: https://push2.eastmoney.com/api/qt/stock/get?secid=1.600519
///   搜索: https://searchapi.eastmoney.com/api/suggest/get?input=600519
/// ─ 美股：Yahoo Finance（免费，无需 key）
class StockApiService {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    followRedirects: true,
    maxRedirects: 3,
    headers: {
      'User-Agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
      'Referer': 'https://www.eastmoney.com',
      'Accept': 'application/json, text/plain, */*',
    },
  ));

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 内部工具：新浪格式 → 东方财富 secid
  // sh600519  → "1.600519"
  // sz000001  → "0.000001"
  // hk00700   → "116.00700"
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  String _toSecid(String sinaSymbol) {
    if (sinaSymbol.startsWith('sh')) return '1.${sinaSymbol.substring(2)}';
    if (sinaSymbol.startsWith('sz')) return '0.${sinaSymbol.substring(2)}';
    if (sinaSymbol.startsWith('hk')) return '116.${sinaSymbol.substring(2)}';
    return sinaSymbol;
  }

  /// 价格缩放因子（东方财富 API 实测）
  /// A股: f43 以"分"存储 → ÷100 得 CNY（如 145502 → 1455.02）
  /// 港股: f43 以"厘"存储 → ÷1000 得 HKD（如 518000 → 518.000）
  double _priceScale(String sinaSymbol) {
    return sinaSymbol.startsWith('hk') ? 1000.0 : 100.0;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // A股 / 港股 行情 — 东方财富（UTF-8 JSON）
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<Map<String, dynamic>?> _fetchEastMoneyQuote(
      String sinaSymbol) async {
    try {
      final res = await _dio.get(
        'https://push2.eastmoney.com/api/qt/stock/get',
        queryParameters: {
          'secid': _toSecid(sinaSymbol),
          'fields': 'f43,f57,f58,f60',
          'ut': 'fa5fd1943c7b386f172d6893dbfba10b',
        },
      );

      final data = res.data['data'] as Map<String, dynamic>?;
      if (data == null) return null;

      final scale = _priceScale(sinaSymbol);
      final currentRaw = (data['f43'] as num?)?.toDouble() ?? 0;
      final prevCloseRaw = (data['f60'] as num?)?.toDouble() ?? 0;

      // 东方财富非交易时段 f43 可能返回 -2147483648（INT_MIN）
      if (currentRaw <= 0 || currentRaw > 2000000000) return null;

      final current = currentRaw / scale;
      final prevClose = prevCloseRaw / scale;
      final changeAmount = current - prevClose;
      final changeRate =
          prevClose > 0 ? (changeAmount / prevClose * 100) : 0.0;

      final name = (data['f58'] as String?) ?? '';
      return {
        'name': name.isEmpty ? sinaSymbol.toUpperCase() : name,
        'current': current,
        'changeAmount': changeAmount,
        'changeRate': changeRate,
      };
    } catch (_) {
      return null;
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 美股 — Yahoo Finance
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
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

      return {
        'name': (meta['shortName'] ?? meta['longName'] ?? meta['symbol'])
            as String,
        'current': current,
        'changeAmount':
            (meta['regularMarketChange'] as num?)?.toDouble() ?? 0,
        'changeRate':
            (meta['regularMarketChangePercent'] as num?)?.toDouble() ?? 0,
      };
    } catch (_) {
      return null;
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 新浪前缀自动补全（用户输入 → 内部 sinaSymbol）
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  String _toSinaSymbol(String symbol, String market) {
    // 先剥离任何已有前缀（用户可能输入 sh003816、或上次验证残留的 sh 前缀）
    String code = symbol.toLowerCase();
    if (code.startsWith('sh') || code.startsWith('sz') || code.startsWith('hk')) {
      code = code.substring(2);
    }
    if (market == 'HK') return 'hk$code';
    // A股：6开头→上海(sh)，0/3/2/8开头→深圳(sz)
    if (code.startsWith('6')) return 'sh$code';
    return 'sz$code';
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 公开接口：验证并获取股票信息
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<StockHolding?> fetchStockInfo(
      String symbol, String market) async {
    final apiSymbol =
        market == 'US' ? symbol : _toSinaSymbol(symbol, market);
    final data = market == 'US'
        ? await _fetchYahooQuote(apiSymbol)
        : await _fetchEastMoneyQuote(apiSymbol);
    if (data == null) return null;

    final current = (data['current'] as num).toDouble();
    return StockHolding(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      symbol: apiSymbol,
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

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 公开接口：刷新行情
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<Map<String, dynamic>?> refreshQuote(
      String symbol, String market) async {
    if (market == 'US') return _fetchYahooQuote(symbol);
    return _fetchEastMoneyQuote(_toSinaSymbol(symbol, market));
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 搜索 — 东方财富（UTF-8 JSON，A股+港股）
  // MktNum: "1"=沪, "0"=深, "116"=港股
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<List<Map<String, String>>> searchStock(
      String keyword, String market) async {
    if (market == 'US') return _searchYahoo(keyword);
    return _searchEastMoney(keyword, market);
  }

  Future<List<Map<String, String>>> _searchEastMoney(
      String keyword, String market) async {
    try {
      final res = await _dio.get(
        'https://searchapi.eastmoney.com/api/suggest/get',
        queryParameters: {
          'input': keyword,
          'type': '14',
          'token': 'D43BF722C8E33BDC906FB84D85E326E8',
          'count': '8',
        },
      );

      final items = (res.data['QuotationCodeTable']?['Data'] as List?) ?? [];
      final results = <Map<String, String>>[];

      for (final item in items) {
        final mktNum = item['MktNum']?.toString() ?? '';
        final code = item['Code']?.toString() ?? '';
        final name = item['Name']?.toString() ?? '';
        if (code.isEmpty || name.isEmpty) continue;

        // 按市场筛选并转换为新浪格式 symbol
        String sinaSymbol;
        if (market == 'A') {
          if (mktNum == '1') {
            sinaSymbol = 'sh$code';
          } else if (mktNum == '0') {
            sinaSymbol = 'sz$code';
          } else {
            continue; // 过滤港股/美股
          }
        } else if (market == 'HK') {
          if (mktNum == '116') {
            sinaSymbol = 'hk$code';
          } else {
            continue;
          }
        } else {
          continue;
        }

        results.add({'symbol': sinaSymbol, 'name': name});
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
                'name': (q['shortname'] ?? q['longname'] ?? q['symbol'])
                    as String,
              })
          .take(6)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
