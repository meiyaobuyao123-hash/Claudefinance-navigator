import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../../../../core/config/api_keys.dart';
import '../../../../core/constants/app_constants.dart';

// ─────────────────────────── 语音解析结果 ───────────────────────────

/// 语音识别 + AI 解析的统一结果
class VoiceParseResult {
  /// "fund" | "stock" | "ambiguous"
  final String type;

  /// AI 纠错后的文字
  final String correctedText;

  // ── 基金字段 ──
  final String? fundCode;
  final String? fundName;
  final double? shares;
  final double? costNav;
  final double? totalAmount;

  // ── 股票字段 ──
  final String? symbol;
  final String? stockName;
  final String? market; // "A" | "HK" | "US"
  final double? costPrice;

  /// 缺失的必填字段
  final List<String> missingFields;

  /// 歧义信息
  final VoiceAmbiguity? ambiguity;

  /// AI 置信度 0-1
  final double confidence;

  /// STT 原始文本
  final String rawText;

  VoiceParseResult({
    required this.type,
    this.correctedText = '',
    this.fundCode,
    this.fundName,
    this.shares,
    this.costNav,
    this.totalAmount,
    this.symbol,
    this.stockName,
    this.market,
    this.costPrice,
    this.missingFields = const [],
    this.ambiguity,
    this.confidence = 0.0,
    this.rawText = '',
  });

  /// 是否信息完整可直接提交
  bool get isComplete => missingFields.isEmpty && ambiguity == null;

  /// 是否有歧义需要用户选择
  bool get hasAmbiguity => ambiguity != null;

  /// 是否是基金
  bool get isFund => type == 'fund';

  /// 是否是股票
  bool get isStock => type == 'stock';
}

/// 歧义选项
class VoiceAmbiguity {
  final String message;
  final List<Map<String, String>> options;

  VoiceAmbiguity({required this.message, required this.options});
}

// ─────────────────────────── 语音输入服务 ───────────────────────────

/// 语音输入服务：STT + DeepSeek AI 解析
/// 处理方言纠错、信息不完整、歧义消解
class VoiceInputService {
  static final VoiceInputService _instance = VoiceInputService._();
  factory VoiceInputService() => _instance;
  VoiceInputService._();

  final SpeechToText _speech = SpeechToText();
  final Dio _dio = Dio();
  bool _isInitialized = false;

  /// 当前是否正在录音
  bool get isListening => _speech.isListening;

  /// STT 是否可用
  bool get isAvailable => _isInitialized;

  // ─────────────── 初始化 ───────────────

  /// 初始化语音识别引擎
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          debugPrint('[VoiceInput] STT error: ${error.errorMsg}');
        },
        onStatus: (status) {
          debugPrint('[VoiceInput] STT status: $status');
        },
      );
      debugPrint('[VoiceInput] initialized: $_isInitialized');
      return _isInitialized;
    } catch (e) {
      debugPrint('[VoiceInput] init error: $e');
      return false;
    }
  }

  // ─────────────── 语音识别（STT）───────────────

  /// 开始监听语音
  /// [onResult] 实时返回识别文本（用于 UI 显示）
  /// [localeId] 语言，默认中文
  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    String localeId = 'zh-CN',
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) throw Exception('语音识别不可用，请检查麦克风权限');
    }

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      localeId: localeId,
      listenMode: ListenMode.dictation,
      cancelOnError: false,
      partialResults: true,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
  }

  /// 停止监听
  Future<void> stopListening() async {
    await _speech.stop();
  }

  /// 取消监听
  Future<void> cancelListening() async {
    await _speech.cancel();
  }

  // ─────────────── AI 解析（DeepSeek）───────────────

  /// 解析语音文本 → 结构化基金/股票信息
  /// [sttText] STT 识别出的原始文本
  /// [context] 上下文提示，如 "fund"(在基金页) 或 "stock"(在股票页)
  Future<VoiceParseResult> parseVoiceText(
    String sttText, {
    String context = 'auto',
  }) async {
    if (sttText.trim().isEmpty) {
      return VoiceParseResult(
        type: 'ambiguous',
        rawText: sttText,
        missingFields: ['all'],
        confidence: 0,
      );
    }

    final contextHint = context == 'fund'
        ? '用户当前在【添加基金】页面，优先识别为基金。'
        : context == 'stock'
            ? '用户当前在【添加股票】页面，优先识别为股票。'
            : '自动判断用户要添加的是基金还是股票。';

    const systemPrompt = '''你是一个金融语音助手。用户通过语音输入了以下文字（可能有方言口误或语音识别错误）。

请完成以下任务：
1. 纠正可能的语音识别错误（如"茅台俩百股"→"茅台200股"，"一点二三四五"→"1.2345"）
2. 判断用户要添加的是【基金】还是【股票】
3. 提取所有能识别的字段
4. 标注缺失的必填字段
5. 如果有歧义（如"苹果"可能是股票也可能是基金），列出可能的选项
6. 如果用户提供了总金额和净值/价格，自动计算份额/股数

常见股票名称映射：
- 茅台/贵州茅台 → symbol: "sh600519", market: "A"
- 腾讯 → symbol: "hk00700", market: "HK"
- 苹果/Apple → symbol: "AAPL", market: "US"
- 特斯拉/Tesla → symbol: "TSLA", market: "US"
- 中国平安 → symbol: "sh601318", market: "A"
- 招商银行 → symbol: "sh600036", market: "A"
- 比亚迪(A股) → symbol: "sz002594", market: "A"

基金代码特征：6位纯数字（如000001、110011、005827）
A股代码：6位数字（沪市60开头、深市00/30开头）
港股代码：5位数字（如00700）
美股代码：英文字母（如AAPL、TSLA）

基金必填字段：fundCode, shares, costNav
股票必填字段：symbol, market, shares, costPrice

必须且只返回一个JSON对象，不要返回其他任何内容：
{
  "type": "stock" | "fund" | "ambiguous",
  "correctedText": "纠错后的完整文字",
  "data": {
    "fundCode": "000001" 或 null,
    "fundName": "基金名称" 或 null,
    "shares": 数字 或 null,
    "costNav": 数字 或 null,
    "totalAmount": 数字 或 null,
    "symbol": "sh600519" 或 null,
    "stockName": "股票名称" 或 null,
    "market": "A" | "HK" | "US" 或 null,
    "costPrice": 数字 或 null
  },
  "missingFields": ["缺失字段1", "缺失字段2"],
  "ambiguity": null 或 {"message": "说明", "options": [{"label": "选项1", "value": "值1"}, ...]},
  "confidence": 0.85
}''';

    try {
      final response = await _dio.post(
        AppConstants.deepseekApiUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${ApiKeys.deepseekVoiceKey}',
            'Content-Type': 'application/json',
          },
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 10),
        ),
        data: {
          'model': 'deepseek-chat',
          'max_tokens': 512,
          'temperature': 0.1,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {
              'role': 'user',
              'content': '$contextHint\n\n语音识别文字：\n$sttText',
            },
          ],
        },
      );

      final content =
          response.data['choices'][0]['message']['content'] as String;
      return _parseAIResponse(content, sttText);
    } catch (e) {
      debugPrint('[VoiceInput] DeepSeek parse error: $e');
      // AI 失败时返回基础结果
      return VoiceParseResult(
        type: 'ambiguous',
        correctedText: sttText,
        rawText: sttText,
        missingFields: ['all'],
        confidence: 0.1,
      );
    }
  }

  /// 解析 DeepSeek 返回的 JSON
  VoiceParseResult _parseAIResponse(String content, String rawText) {
    try {
      String jsonStr = content.trim();
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(jsonStr);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(0)!;
      }

      final map = json.decode(jsonStr) as Map<String, dynamic>;
      final data = map['data'] as Map<String, dynamic>? ?? {};
      final missingList = (map['missingFields'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      // 解析歧义
      VoiceAmbiguity? ambiguity;
      if (map['ambiguity'] != null && map['ambiguity'] is Map) {
        final amb = map['ambiguity'] as Map<String, dynamic>;
        final opts = (amb['options'] as List<dynamic>?)
                ?.map((e) => Map<String, String>.from(
                    (e as Map).map((k, v) => MapEntry(k.toString(), v.toString()))))
                .toList() ??
            [];
        ambiguity = VoiceAmbiguity(
          message: amb['message']?.toString() ?? '',
          options: opts,
        );
      }

      return VoiceParseResult(
        type: map['type']?.toString() ?? 'ambiguous',
        correctedText: map['correctedText']?.toString() ?? rawText,
        fundCode: data['fundCode']?.toString(),
        fundName: data['fundName']?.toString(),
        shares: _toDouble(data['shares']),
        costNav: _toDouble(data['costNav']),
        totalAmount: _toDouble(data['totalAmount']),
        symbol: data['symbol']?.toString(),
        stockName: data['stockName']?.toString(),
        market: data['market']?.toString(),
        costPrice: _toDouble(data['costPrice']),
        missingFields: missingList,
        ambiguity: ambiguity,
        confidence: _toDouble(map['confidence']) ?? 0.0,
        rawText: rawText,
      );
    } catch (e) {
      debugPrint('[VoiceInput] JSON parse error: $e, content=$content');
      return VoiceParseResult(
        type: 'ambiguous',
        correctedText: rawText,
        rawText: rawText,
        missingFields: ['all'],
        confidence: 0.1,
      );
    }
  }

  // ─────────────── 工具方法 ───────────────

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', ''));
    return null;
  }
}
