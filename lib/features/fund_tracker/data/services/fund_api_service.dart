import 'dart:convert';
import 'package:dio/dio.dart';

/// 天天基金（东方财富）非官方免费接口封装
/// 移动端 Dio 调用不存在 CORS 限制
class FundApiService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  static const _mobileUA =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';

  // ─────────────────────────────────────────────
  // 1. 获取基金实时估值 + 基本信息
  //    优先：JSONP 盘中估值接口（适合股票型/混合型基金）
  //    降级：历史净值接口 + 搜索接口拼合（适合货币基金等无估值基金）
  //    返回: fundCode, name, dwjz(昨日/最新净值), gsz(估值), gszzl(涨跌%), jzrq(净值日期)
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> fetchFundInfo(String fundCode) async {
    // ── 尝试 JSONP 盘中估值接口 ──
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final response = await _dio.get(
        'http://fundgz.1234567.com.cn/js/$fundCode.js',
        queryParameters: {'rt': ts},
        options: Options(
          headers: {
            'User-Agent': _mobileUA,
            'Referer': 'https://fund.eastmoney.com/',
          },
          responseType: ResponseType.plain,
        ),
      );
      final text = response.data.toString();
      if (text.contains('jsonpgz(')) {
        final start = text.indexOf('(');
        final end = text.lastIndexOf(')');
        if (start < 0 || end < 0 || end <= start) throw FormatException('JSONP格式异常');
        final jsonStr = text.substring(start + 1, end);
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        // 确认 name 字段非空，否则走降级
        if ((data['name']?.toString() ?? '').isNotEmpty) {
          return data;
        }
      }
    } catch (_) {
      // JSONP 接口失败，继续尝试降级方案
    }

    // ── 降级方案：历史净值接口 + 搜索接口 ──
    // 货币基金/部分债基的 JSONP 估值接口为空，但历史净值接口完整
    String fundName = '';
    String latestDate = '';
    double latestNav = 0;
    double changeRate = 0;

    // 1. 历史净值接口获取最新净值（最权威的数据源）
    final history = await fetchFundHistory(fundCode, pageSize: 2);
    if (history.isEmpty) {
      throw Exception('基金代码 $fundCode 不存在');
    }
    latestNav = history.first['nav'] as double;
    latestDate = history.first['date'] as String;
    changeRate = history.first['changeRate'] as double;

    // 2. 搜索接口获取基金名称
    try {
      final results = await searchFund(fundCode);
      final match = results.firstWhere(
        (r) => r['code'] == fundCode,
        orElse: () => results.isNotEmpty ? results.first : <String, String>{},
      );
      fundName = match['name'] ?? '';
    } catch (_) {}

    // 3. 组装成与 JSONP 接口相同的数据结构
    return {
      'fundcode': fundCode,
      'name': fundName,
      'jzrq': latestDate,
      'dwjz': latestNav.toStringAsFixed(4),
      'gsz': latestNav.toStringAsFixed(4),   // 无盘中估值时，估值=最新净值
      'gszzl': changeRate.toStringAsFixed(2),
      'gztime': latestDate,
    };
  }

  // ─────────────────────────────────────────────
  // 2. 获取历史净值（纯 JSON 接口，最推荐）
  // ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchFundHistory(
    String fundCode, {
    int pageSize = 30,
  }) async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 60)); // 多取避免非交易日空缺
    final fmt = (DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final response = await _dio.get(
      'https://api.fund.eastmoney.com/f10/lsjz',
      queryParameters: {
        'fundCode': fundCode,
        'pageIndex': 1,
        'pageSize': pageSize,
        'startDate': fmt(start),
        'endDate': fmt(now),
      },
      options: Options(
        headers: {
          'User-Agent': _mobileUA,
          'Referer': 'http://fundf10.eastmoney.com/jjjz_$fundCode.html',
        },
      ),
    );

    final body = response.data as Map<String, dynamic>;
    if (body['ErrCode'] != 0) {
      throw Exception('历史净值接口错误: ${body['ErrMsg']}');
    }

    final list = body['Data']['LSJZList'] as List;
    return list.map((item) {
      final rateRaw = item['JZZZL'];
      double rate = 0;
      if (rateRaw != null && rateRaw.toString() != 'null' && rateRaw.toString().isNotEmpty) {
        rate = double.tryParse(rateRaw.toString()) ?? 0;
      }
      return {
        'date': item['FSRQ'] as String,
        'nav': double.parse(item['DWJZ'].toString()),
        'accNav': double.parse(item['LJJZ'].toString()),
        'changeRate': rate,
      };
    }).toList().cast<Map<String, dynamic>>();
  }

  // ─────────────────────────────────────────────
  // 3. 搜索基金（关键词/代码）
  // ─────────────────────────────────────────────
  Future<List<Map<String, String>>> searchFund(String keyword) async {
    if (keyword.trim().isEmpty) return [];
    try {
      final response = await _dio.get(
        'http://fund.eastmoney.com/api/fundSearch',
        queryParameters: {'m': 1, 'key': keyword.trim()},
        options: Options(
          headers: {'User-Agent': _mobileUA, 'Referer': 'https://fund.eastmoney.com/'},
          responseType: ResponseType.plain,
        ),
      );

      // 返回 JSONP 格式，尝试解析
      String text = response.data.toString().trim();
      // 去掉可能的 callback 包装
      if (text.startsWith('[') || text.startsWith('{')) {
        // 纯 JSON
      } else if (text.contains('(')) {
        text = text.substring(text.indexOf('(') + 1, text.lastIndexOf(')'));
      }

      final decoded = jsonDecode(text);
      List raw = [];
      if (decoded is List) {
        raw = decoded;
      } else if (decoded is Map && decoded.containsKey('Datas')) {
        raw = decoded['Datas'] as List;
      }

      return raw.take(10).map<Map<String, String>>((item) {
        if (item is List) {
          // 格式: [code, pinyin, name, type, fullPinyin]，至少需要3个元素
          if (item.length < 3) {
            return {'code': item.isNotEmpty ? item[0].toString() : '', 'name': ''};
          }
          return {'code': item[0].toString(), 'name': item[2].toString()};
        }
        return {
          'code': (item['FCODE'] ?? item['code'] ?? '').toString(),
          'name': (item['SHORTNAME'] ?? item['name'] ?? '').toString(),
        };
      }).where((m) => m['code']!.isNotEmpty).toList();
    } catch (_) {
      // 搜索接口不稳定，失败时降级为空结果
      return [];
    }
  }
}
