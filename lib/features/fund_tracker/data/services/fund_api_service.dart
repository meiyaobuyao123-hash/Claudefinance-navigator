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
  // 1. 获取基金实时估值 + 基本信息（JSONP 接口）
  //    返回: fundCode, name, dwjz(昨日净值), gsz(今日估值), gszzl(涨跌%), jzrq(净值日期)
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> fetchFundInfo(String fundCode) async {
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
    if (!text.contains('jsonpgz(')) {
      throw Exception('基金代码 $fundCode 不存在或接口暂时不可用');
    }

    // 剥离 JSONP 包装: jsonpgz({...}); -> {...}
    final jsonStr =
        text.substring(text.indexOf('(') + 1, text.lastIndexOf(')'));
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    return data;
    // 返回示例:
    // {
    //   "fundcode": "000001",
    //   "name": "华夏成长混合",
    //   "jzrq": "2024-02-28",   // 上一净值日期
    //   "dwjz": "0.7420",       // 上一交易日单位净值
    //   "gsz": "0.7395",        // 今日实时估值（盘中更新）
    //   "gszzl": "-0.34",       // 今日估算涨跌幅 %
    //   "gztime": "2024-02-28 15:00"
    // }
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
          // 格式: [code, pinyin, name, type, fullPinyin]
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
