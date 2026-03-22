import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/market_rate_service.dart';

/// 单个产品的实时行情数据
class LiveRateData {
  final String displayRate; // 展示文字，如 "1.77%" 或 "¥695.8 (+0.31%)"
  final double? changeRate; // 涨跌幅 %（可空）
  final DateTime updatedAt;
  final bool isUp;

  const LiveRateData({
    required this.displayRate,
    this.changeRate,
    required this.updatedAt,
    this.isUp = true,
  });
}

/// 全产品实时行情 Provider
/// key = productId（与 ProductModel.id 对应）
class MarketRatesNotifier
    extends AsyncNotifier<Map<String, LiveRateData>> {
  @override
  Future<Map<String, LiveRateData>> build() => _fetchAll();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchAll);
  }

  Future<Map<String, LiveRateData>> _fetchAll() async {
    final svc = MarketRateService();
    final result = <String, LiveRateData>{};
    final now = DateTime.now();

    // ─── 货币基金7日年化（余额宝 000198）───
    final moneyYield = await svc.fetchMoneyFundYield('000198');
    if (moneyYield != null) {
      result['cn_money_fund'] = LiveRateData(
        displayRate: '7日年化 ${moneyYield.toStringAsFixed(4)}%',
        updatedAt: now,
        isUp: moneyYield >= 0,
      );
    }

    // ─── 沪深300 ETF (sz510300)──
    final csi300 = await svc.fetchETFQuote('sz510300');
    if (csi300 != null) {
      final price = csi300['current'] as double;
      final chg = csi300['changeRate'] as double;
      result['cn_etf'] = LiveRateData(
        displayRate:
            '沪深300 ¥${price.toStringAsFixed(3)} (${chg >= 0 ? '+' : ''}${chg.toStringAsFixed(2)}%)',
        changeRate: chg,
        updatedAt: now,
        isUp: chg >= 0,
      );
    }

    // ─── 黄金ETF (sh518880) ───
    final gold = await svc.fetchGoldPrice();
    if (gold != null) {
      final price = gold['current'] as double;
      final chg = gold['changeRate'] as double;
      result['cn_paper_gold'] = LiveRateData(
        displayRate:
            '黄金ETF ¥${price.toStringAsFixed(3)} (${chg >= 0 ? '+' : ''}${chg.toStringAsFixed(2)}%)',
        changeRate: chg,
        updatedAt: now,
        isUp: chg >= 0,
      );
    }

    // ─── 美股 VOO ───
    final voo = await svc.fetchUSETFQuote('VOO');
    if (voo != null) {
      final price = voo['current'] as double;
      final chg = voo['changeRate'] as double;
      result['hk_overseas_etf'] = LiveRateData(
        displayRate:
            'VOO \$${price.toStringAsFixed(2)} (${chg >= 0 ? '+' : ''}${chg.toStringAsFixed(2)}%)',
        changeRate: chg,
        updatedAt: now,
        isUp: chg >= 0,
      );
    }

    return result;
  }
}

final marketRatesProvider =
    AsyncNotifierProvider<MarketRatesNotifier, Map<String, LiveRateData>>(
  MarketRatesNotifier.new,
);
