import 'package:dio/dio.dart';

/// 实时市场行情服务（产品导航页展示用）
/// ─ 货币基金7日年化：东方财富 FundMMF 接口
/// ─ A股/港股 ETF：东方财富行情接口
/// ─ 黄金 Au9999：东方财富商品接口
/// ─ 美股 ETF：Yahoo Finance
class MarketRateService {
  static final _instance = MarketRateService._();
  MarketRateService._();
  factory MarketRateService() => _instance;

  static const _mobileUA =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: {
      'User-Agent': _mobileUA,
      'Referer': 'https://www.eastmoney.com',
      'Accept': 'application/json, text/plain, */*',
    },
  ));

  // ─── 货币基金7日年化 ───
  // fundCode: '000198' (余额宝)
  // 返回年化收益率（单位：%），如 1.7730
  Future<double?> fetchMoneyFundYield(String fundCode) async {
    try {
      final res = await _dio.get(
        'https://fundmobapi.eastmoney.com/FundMApi/FundMMF.ashx',
        queryParameters: {
          'FCODE': fundCode,
          'plat': 'Android',
          'appVersion': '9.0.0',
          'product': 'EFund',
          'Version': '1',
        },
      );
      final datas = res.data['Datas'] as Map<String, dynamic>?;
      if (datas == null) return null;
      final sjz = datas['SJZ']?.toString();
      if (sjz == null || sjz.isEmpty || sjz == 'null') return null;
      return double.tryParse(sjz);
    } catch (_) {
      return null;
    }
  }

  // ─── A股/港股 ETF 实时价格（东方财富）───
  // sinaSymbol 格式：'sz510300', 'sz510500', 'hk02800'
  Future<Map<String, dynamic>?> fetchETFQuote(String sinaSymbol) async {
    try {
      final secid = _toSecid(sinaSymbol);
      final scale = sinaSymbol.startsWith('hk') ? 1000.0 : 100.0;
      final res = await _dio.get(
        'https://push2.eastmoney.com/api/qt/stock/get',
        queryParameters: {
          'secid': secid,
          'fields': 'f43,f57,f58,f60',
          'ut': 'fa5fd1943c7b386f172d6893dbfba10b',
        },
      );
      final data = res.data['data'] as Map<String, dynamic>?;
      if (data == null) return null;
      final currentRaw = (data['f43'] as num?)?.toDouble() ?? 0;
      final prevCloseRaw = (data['f60'] as num?)?.toDouble() ?? 0;
      if (currentRaw <= 0 || currentRaw > 2000000000) return null;
      final current = currentRaw / scale;
      final prevClose = prevCloseRaw / scale;
      final changeRate =
          prevClose > 0 ? ((current - prevClose) / prevClose * 100) : 0.0;
      return {'current': current, 'changeRate': changeRate};
    } catch (_) {
      return null;
    }
  }

  // ─── 黄金 Au9999 现货价格（东方财富）───
  // 上海黄金交易所现货，单位：元/克
  Future<Map<String, dynamic>?> fetchGoldPrice() async {
    try {
      final res = await _dio.get(
        'https://push2.eastmoney.com/api/qt/stock/get',
        queryParameters: {
          'secid': '151.Au9999',
          'fields': 'f43,f58,f60',
          'ut': 'fa5fd1943c7b386f172d6893dbfba10b',
        },
      );
      final data = res.data['data'] as Map<String, dynamic>?;
      if (data == null) return null;
      final currentRaw = (data['f43'] as num?)?.toDouble() ?? 0;
      final prevCloseRaw = (data['f60'] as num?)?.toDouble() ?? 0;
      if (currentRaw <= 0 || currentRaw > 2000000000) return null;
      // 东方财富黄金价格以"分"计（实测），除以100得元/克
      final current = currentRaw / 100.0;
      final prevClose = prevCloseRaw / 100.0;
      final changeRate =
          prevClose > 0 ? ((current - prevClose) / prevClose * 100) : 0.0;
      return {'current': current, 'changeRate': changeRate};
    } catch (_) {
      return null;
    }
  }

  // ─── 美股 ETF 实时价格（Yahoo Finance）───
  Future<Map<String, dynamic>?> fetchUSETFQuote(String symbol) async {
    try {
      final res = await _dio.get(
        'https://query1.finance.yahoo.com/v8/finance/chart/$symbol',
        queryParameters: {'interval': '1d', 'range': '1d'},
      );
      final result = (res.data['chart']['result'] as List?)?.first;
      if (result == null) return null;
      final meta = result['meta'] as Map<String, dynamic>;
      final current = (meta['regularMarketPrice'] as num?)?.toDouble() ?? 0;
      if (current <= 0) return null;
      return {
        'current': current,
        'changeRate':
            (meta['regularMarketChangePercent'] as num?)?.toDouble() ?? 0,
      };
    } catch (_) {
      return null;
    }
  }

  // ─── 内部：新浪格式 → 东方财富 secid ───
  String _toSecid(String sinaSymbol) {
    if (sinaSymbol.startsWith('sh')) return '1.${sinaSymbol.substring(2)}';
    if (sinaSymbol.startsWith('sz')) return '0.${sinaSymbol.substring(2)}';
    if (sinaSymbol.startsWith('hk')) return '116.${sinaSymbol.substring(2)}';
    return sinaSymbol;
  }
}
