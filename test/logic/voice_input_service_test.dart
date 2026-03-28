import 'package:flutter_test/flutter_test.dart';
import 'package:finance_navigator/features/fund_tracker/data/services/voice_input_service.dart';

void main() {
  group('VoiceParseResult', () {
    test('isComplete returns true when no missing fields and no ambiguity', () {
      final result = VoiceParseResult(
        type: 'fund',
        fundCode: '000001',
        shares: 1000,
        costNav: 1.2345,
        missingFields: [],
        confidence: 0.9,
      );
      expect(result.isComplete, true);
      expect(result.isFund, true);
      expect(result.isStock, false);
      expect(result.hasAmbiguity, false);
    });

    test('isComplete returns false when fields are missing', () {
      final result = VoiceParseResult(
        type: 'fund',
        fundCode: '000001',
        missingFields: ['shares', 'costNav'],
        confidence: 0.6,
      );
      expect(result.isComplete, false);
    });

    test('hasAmbiguity returns true when ambiguity present', () {
      final result = VoiceParseResult(
        type: 'ambiguous',
        ambiguity: VoiceAmbiguity(
          message: '您说的苹果是指？',
          options: [
            {'label': 'AAPL 苹果公司', 'value': 'AAPL'},
            {'label': '苹果基金', 'value': 'fund'},
          ],
        ),
      );
      expect(result.hasAmbiguity, true);
      expect(result.isComplete, false);
    });

    test('isFund and isStock correctly identify type', () {
      expect(VoiceParseResult(type: 'fund').isFund, true);
      expect(VoiceParseResult(type: 'fund').isStock, false);
      expect(VoiceParseResult(type: 'stock').isStock, true);
      expect(VoiceParseResult(type: 'stock').isFund, false);
      expect(VoiceParseResult(type: 'ambiguous').isFund, false);
      expect(VoiceParseResult(type: 'ambiguous').isStock, false);
    });

    test('fund result with all fields', () {
      final result = VoiceParseResult(
        type: 'fund',
        correctedText: '添加基金000001，5000份，净值1.2345',
        fundCode: '000001',
        fundName: '易方达蓝筹精选',
        shares: 5000.0,
        costNav: 1.2345,
        missingFields: [],
        confidence: 0.95,
        rawText: '添加基金000001，5000份，净值一点二三四五',
      );
      expect(result.isComplete, true);
      expect(result.fundCode, '000001');
      expect(result.shares, 5000.0);
      expect(result.costNav, 1.2345);
      expect(result.confidence, 0.95);
    });

    test('stock result with all fields', () {
      final result = VoiceParseResult(
        type: 'stock',
        correctedText: '买了200股茅台，成本1800',
        symbol: 'sh600519',
        stockName: '贵州茅台',
        market: 'A',
        shares: 200,
        costPrice: 1800,
        missingFields: [],
        confidence: 0.9,
      );
      expect(result.isComplete, true);
      expect(result.isStock, true);
      expect(result.symbol, 'sh600519');
      expect(result.market, 'A');
      expect(result.shares, 200);
      expect(result.costPrice, 1800);
    });

    test('partial result with totalAmount for fund', () {
      final result = VoiceParseResult(
        type: 'fund',
        fundCode: '005827',
        totalAmount: 50000,
        costNav: 1.8,
        missingFields: ['shares'],
        confidence: 0.7,
      );
      // 份额可由 totalAmount / costNav 计算
      final calculatedShares = result.totalAmount! / result.costNav!;
      expect(calculatedShares, closeTo(27777.78, 0.01));
    });

    test('empty text returns low confidence ambiguous result', () {
      final result = VoiceParseResult(
        type: 'ambiguous',
        rawText: '',
        missingFields: ['all'],
        confidence: 0,
      );
      expect(result.isComplete, false);
      expect(result.confidence, 0);
    });
  });

  group('VoiceAmbiguity', () {
    test('holds message and options', () {
      final ambiguity = VoiceAmbiguity(
        message: '您说的苹果是指？',
        options: [
          {'label': 'AAPL 苹果公司 (美股)', 'type': 'stock', 'symbol': 'AAPL', 'market': 'US'},
          {'label': '苹果基金', 'type': 'fund'},
        ],
      );
      expect(ambiguity.message, '您说的苹果是指？');
      expect(ambiguity.options.length, 2);
      expect(ambiguity.options[0]['symbol'], 'AAPL');
    });
  });

  group('VoiceInputService', () {
    test('singleton instance', () {
      final a = VoiceInputService();
      final b = VoiceInputService();
      expect(identical(a, b), true);
    });

    test('initial state: not listening, not available', () {
      final service = VoiceInputService();
      expect(service.isListening, false);
      // isAvailable is false before initialize()
      expect(service.isAvailable, false);
    });

    test('parseVoiceText with empty text returns ambiguous result', () async {
      final service = VoiceInputService();
      final result = await service.parseVoiceText('');
      expect(result.type, 'ambiguous');
      expect(result.confidence, 0);
      expect(result.missingFields, contains('all'));
    });

    test('parseVoiceText with whitespace-only returns ambiguous', () async {
      final service = VoiceInputService();
      final result = await service.parseVoiceText('   ');
      expect(result.type, 'ambiguous');
      expect(result.confidence, 0);
    });
  });

  group('Market validation for voice results', () {
    test('valid markets accepted', () {
      for (final m in ['A', 'HK', 'US']) {
        final result = VoiceParseResult(type: 'stock', market: m);
        expect(['A', 'HK', 'US'].contains(result.market), true);
      }
    });

    test('null market means not determined', () {
      final result = VoiceParseResult(type: 'stock', market: null);
      expect(result.market, null);
    });
  });

  group('Edge cases', () {
    test('dialect correction reflected in correctedText', () {
      final result = VoiceParseResult(
        type: 'stock',
        correctedText: '茅台200股',
        rawText: '茅台俩百股',
        symbol: 'sh600519',
        shares: 200,
        missingFields: ['costPrice'],
        confidence: 0.8,
      );
      expect(result.correctedText, '茅台200股');
      expect(result.rawText, '茅台俩百股');
      expect(result.isComplete, false);
    });

    test('US stock with decimal shares', () {
      final result = VoiceParseResult(
        type: 'stock',
        symbol: 'AAPL',
        market: 'US',
        shares: 10.5,
        costPrice: 175.0,
        missingFields: [],
        confidence: 0.9,
      );
      expect(result.shares, 10.5);
      expect(result.isComplete, true);
    });

    test('fund with amount and nav but no shares', () {
      final result = VoiceParseResult(
        type: 'fund',
        fundCode: '110011',
        totalAmount: 100000,
        costNav: 2.5,
        missingFields: ['shares'],
        confidence: 0.75,
      );
      // Caller can calculate: shares = totalAmount / costNav
      expect(result.totalAmount! / result.costNav!, 40000);
    });
  });
}
