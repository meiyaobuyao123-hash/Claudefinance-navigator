import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
// google_mlkit_text_recognition 暂时移除（MLImage 不支持模拟器）
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/config/api_keys.dart';
import '../../../../core/constants/app_constants.dart';

/// OCR 识别结果
class OcrResult {
  final String? fundCode;
  final String? fundName;
  final double? shares;
  final double? costNav;
  final double? amount;
  final String? action; // "buy" | "sell"
  final double confidence;
  final String rawText; // OCR 原始文本（调试用）

  OcrResult({
    this.fundCode,
    this.fundName,
    this.shares,
    this.costNav,
    this.amount,
    this.action,
    this.confidence = 0.0,
    this.rawText = '',
  });

  /// 是否至少识别到了基金代码
  bool get hasCode => fundCode != null && fundCode!.isNotEmpty;

  /// 是否识别到了完整的加仓信息（代码+份额+净值）
  bool get isComplete =>
      hasCode && shares != null && shares! > 0 && costNav != null && costNav! > 0;

  /// 概要文字（用于 SnackBar 提示）
  String get summary {
    final parts = <String>[];
    if (fundName != null) parts.add(fundName!);
    if (fundCode != null) parts.add('($fundCode)');
    if (shares != null) parts.add('${shares!.toStringAsFixed(2)}份');
    if (costNav != null) parts.add('@ ${costNav!.toStringAsFixed(4)}');
    return parts.isEmpty ? '未识别到有效信息' : parts.join(' ');
  }
}

/// 基金截图 OCR 识别服务
/// 两阶段：1) ML Kit 中文 OCR → 2) DeepSeek AI 结构化解析
class OcrService {
  static final OcrService _instance = OcrService._();
  factory OcrService() => _instance;
  OcrService._();

  final _picker = ImagePicker();
  final _dio = Dio();

  // ─────────────────────────── 1. 选择图片 ───────────────────────────

  /// 从相机拍照
  Future<File?> pickFromCamera() => _pickImage(ImageSource.camera);

  /// 从相册选择
  Future<File?> pickFromGallery() => _pickImage(ImageSource.gallery);

  Future<File?> _pickImage(ImageSource source) async {
    try {
      final xFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (xFile == null) return null;
      return File(xFile.path);
    } catch (e) {
      debugPrint('[OcrService] pickImage error: $e');
      return null;
    }
  }

  // ─────────────────────────── 2. ML Kit OCR ───────────────────────────

  /// 从图片提取文字（中文 + 拉丁文混合识别）
  /// 注意：google_mlkit_text_recognition 暂时移除（MLImage 不支持模拟器）
  /// 真机部署时取消 pubspec 注释 + 恢复此方法的 MLKit 调用
  Future<String> recognizeText(File imageFile) async {
    // MLKit 暂不可用，返回空字符串触发 regex 降级
    debugPrint('[OcrService] MLKit 暂不可用（模拟器模式），跳过 OCR');
    return '';
  }

  // ─────────────────────────── 3. DeepSeek 解析 ───────────────────────────

  /// 将 OCR 文字发送给 DeepSeek，提取结构化基金交易信息
  Future<OcrResult> parseWithAI(String ocrText) async {
    if (ocrText.trim().isEmpty) {
      return OcrResult(rawText: ocrText, confidence: 0);
    }

    const systemPrompt = '''你是基金交易截图解析器。从用户提供的 OCR 文字中提取基金交易信息。

规则：
1. fundCode：6位数字基金代码（如 000001、110011、005827）
2. fundName：基金全称或简称
3. shares：确认份额/持有份额（数字，单位"份"）
4. costNav：确认净值/买入净值/成交净值（小数，如 1.2345）
5. amount：买入金额/交易金额（数字，单位"元"）
6. action：买入(buy)/卖出(sell)/赎回(sell)
7. confidence：你对识别结果的置信度（0-1之间的小数）

必须且只返回一个 JSON 对象，不要返回其他任何内容。
无法识别的字段设为 null。
示例返回：{"fundCode":"000001","fundName":"易方达蓝筹精选混合","shares":1234.56,"costNav":1.2345,"amount":10000.00,"action":"buy","confidence":0.85}''';

    try {
      final response = await _dio.post(
        AppConstants.deepseekApiUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${ApiKeys.deepseekApiKey}',
            'Content-Type': 'application/json',
          },
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 10),
        ),
        data: {
          'model': 'deepseek-chat',
          'max_tokens': 256,
          'temperature': 0.1,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': 'OCR文字：\n$ocrText'},
          ],
        },
      );

      final content =
          response.data['choices'][0]['message']['content'] as String;
      return _parseJsonResult(content, ocrText);
    } catch (e) {
      debugPrint('[OcrService] DeepSeek parse error: $e');
      // AI 解析失败，尝试本地 regex 降级
      return _regexFallback(ocrText);
    }
  }

  /// 解析 DeepSeek 返回的 JSON
  OcrResult _parseJsonResult(String content, String rawText) {
    try {
      // 提取 JSON（可能被 ```json ``` 包裹）
      String jsonStr = content.trim();
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(jsonStr);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(0)!;
      }

      final map = json.decode(jsonStr) as Map<String, dynamic>;
      return OcrResult(
        fundCode: map['fundCode']?.toString(),
        fundName: map['fundName']?.toString(),
        shares: _toDouble(map['shares']),
        costNav: _toDouble(map['costNav']),
        amount: _toDouble(map['amount']),
        action: map['action']?.toString(),
        confidence: _toDouble(map['confidence']) ?? 0.0,
        rawText: rawText,
      );
    } catch (e) {
      debugPrint('[OcrService] JSON parse error: $e, content=$content');
      return _regexFallback(rawText);
    }
  }

  // ─────────────────────────── 4. Regex 降级 ───────────────────────────

  /// 当 AI 解析失败时，用正则提取基本信息
  OcrResult _regexFallback(String text) {
    String? fundCode;
    double? shares;
    double? costNav;
    double? amount;

    // 基金代码：独立的6位数字
    final codeMatch = RegExp(r'(?:基金代码|代码)[：:\s]*(\d{6})').firstMatch(text);
    if (codeMatch != null) {
      fundCode = codeMatch.group(1);
    } else {
      // 尝试匹配任意独立6位数字
      final anyCode = RegExp(r'\b(\d{6})\b').firstMatch(text);
      if (anyCode != null) fundCode = anyCode.group(1);
    }

    // 确认份额
    final sharesMatch =
        RegExp(r'(?:确认份额|持有份额|份额)[：:\s]*([\d,]+\.?\d*)')
            .firstMatch(text);
    if (sharesMatch != null) {
      shares = _toDouble(sharesMatch.group(1)?.replaceAll(',', ''));
    }

    // 确认净值
    final navMatch =
        RegExp(r'(?:确认净值|成交净值|买入净值|净值)[：:\s]*(\d+\.?\d*)')
            .firstMatch(text);
    if (navMatch != null) {
      costNav = _toDouble(navMatch.group(1));
    }

    // 买入金额
    final amountMatch =
        RegExp(r'(?:买入金额|交易金额|申购金额|金额)[：:\s]*([\d,]+\.?\d*)')
            .firstMatch(text);
    if (amountMatch != null) {
      amount = _toDouble(amountMatch.group(1)?.replaceAll(',', ''));
    }

    return OcrResult(
      fundCode: fundCode,
      shares: shares,
      costNav: costNav,
      amount: amount,
      action: 'buy',
      confidence: fundCode != null ? 0.4 : 0.1,
      rawText: text,
    );
  }

  // ─────────────────────────── 5. 一键识别入口 ───────────────────────────

  /// 完整识别流程：选图 → OCR → AI 解析
  Future<OcrResult?> recognizeFromImage(ImageSource source) async {
    // 1. 选图
    final imageFile = await _pickImage(source);
    if (imageFile == null) return null; // 用户取消

    // 2. OCR
    final ocrText = await recognizeText(imageFile);
    if (ocrText.trim().isEmpty) {
      return OcrResult(rawText: '', confidence: 0);
    }

    // 3. AI 解析
    return parseWithAI(ocrText);
  }

  // ─────────────────────────── 工具方法 ───────────────────────────

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', ''));
    return null;
  }
}
