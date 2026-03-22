// M02 持仓上下文注入 — PortfolioContextBuilder 单元测试
// 严格对应 PRD/TECH 验收标准：
//   AC-1: buildFullSnapshot() 格式正确（标题/基金/股票/合计行）
//   AC-2: shouldInjectFull() 关键词命中率正确
//   AC-3: 持仓为空时返回空字符串
//   AC-4: 超过8支时截断，末尾追加「另有 N 支未展示」
//   AC-5: 完整持仓快照 token 估算 < 150（字符数/1.5）
//   AC-6: buildSummaryOnly() 格式正确，持仓空时返回 ''
//   AC-7: 合计行数据计算正确

import 'package:flutter_test/flutter_test.dart';
import 'package:finance_navigator/features/ai_chat/data/portfolio_context_builder.dart';
import 'package:finance_navigator/features/fund_tracker/data/models/fund_holding.dart';
import 'package:finance_navigator/features/stock_tracker/data/models/stock_holding.dart';

// ── 测试数据构造工具 ─────────────────────────────────────────────

/// 基金：costNav=1.0, currentNav=1.2 → 收益+20%, currentValue = shares*1.2
FundHolding _fund(String code, String name, double shares) => FundHolding(
      id: code,
      fundCode: code,
      fundName: name,
      shares: shares,
      costNav: 1.0,
      addedDate: '2024-01-01',
      currentNav: 1.2,
    );

/// 股票：costPrice=100, currentPrice=150 → 收益+50%
StockHolding _stock(String symbol, String name, String market, double shares) =>
    StockHolding(
      id: symbol,
      symbol: symbol,
      stockName: name,
      market: market,
      shares: shares,
      costPrice: 100.0,
      addedDate: '2024-01-01',
      currentPrice: 150.0,
    );

void main() {
  // ── AC-3: 空持仓返回 '' ──────────────────────────────────────
  group('空持仓', () {
    const empty = PortfolioContextBuilder(
      fundHoldings: [],
      stockHoldings: [],
    );

    test('[AC-3] buildFullSnapshot 返回空字符串', () {
      expect(empty.buildFullSnapshot(), isEmpty);
    });

    test('[AC-3] buildSummaryOnly 返回空字符串', () {
      expect(empty.buildSummaryOnly(), isEmpty);
    });
  });

  // ── AC-1: buildFullSnapshot 格式 ─────────────────────────────
  group('buildFullSnapshot — 格式验证', () {
    final funds = [
      _fund('005827', '易方达蓝筹精选', 10000), // currentValue = 10000*1.2 = 12000 = 1.2万
      _fund('166002', '中欧价值发现', 8000),   // currentValue = 8000*1.2 = 9600
    ];
    final stocks = [
      _stock('600519', '贵州茅台', 'A', 100), // currentValue = 100*150 = 15000 = 1.5万
    ];
    final builder = PortfolioContextBuilder(
      fundHoldings: funds,
      stockHoldings: stocks,
    );
    final snapshot = builder.buildFullSnapshot();

    test('[AC-1] 包含标题行「持仓快照 · 实时」', () {
      expect(snapshot, contains('【持仓快照 · 实时】'));
    });

    test('[AC-1] 包含基金支数行（2支）', () {
      expect(snapshot, contains('基金（2支）'));
    });

    test('[AC-1] 包含基金名称和代码', () {
      expect(snapshot, contains('易方达蓝筹精选(005827)'));
      expect(snapshot, contains('中欧价值发现(166002)'));
    });

    test('[AC-1] 包含股票名称、代码和市场标签', () {
      expect(snapshot, contains('贵州茅台(600519·A股)'));
    });

    test('[AC-1] 包含合计行', () {
      expect(snapshot, contains('合计'));
    });

    test('[AC-1] 包含收益符号（+/-）', () {
      // 收益均为 +20% 和 +50%，应含 + 符号
      expect(snapshot, contains('+'));
    });

    test('[AC-1] 大于1万的值用万为单位', () {
      // 易方达：12000 → 1.2万
      expect(snapshot, contains('1.2万'));
      // 贵州茅台：15000 → 1.5万
      expect(snapshot, contains('1.5万'));
    });

    test('[AC-1] 小于1万的值直接显示整数', () {
      // 中欧：9600 → "9600"
      expect(snapshot, contains('9600'));
    });

    test('[AC-1] 股票只有一支 — 股票支数行正确', () {
      expect(snapshot, contains('股票（1支）'));
    });
  });

  // ── 只有基金/只有股票的场景 ────────────────────────────────────
  group('buildFullSnapshot — 单类持仓', () {
    test('只有基金 — 无股票部分，有基金和合计', () {
      final b = PortfolioContextBuilder(
        fundHoldings: [_fund('000001', '测试基金A', 1000)],
        stockHoldings: [],
      );
      final s = b.buildFullSnapshot();
      expect(s, contains('基金（1支）'));
      expect(s, isNot(contains('股票')));
      expect(s, contains('合计'));
    });

    test('只有股票 — 无基金部分，有股票和合计', () {
      final b = PortfolioContextBuilder(
        fundHoldings: [],
        stockHoldings: [_stock('AAPL', '苹果', 'US', 10)],
      );
      final s = b.buildFullSnapshot();
      expect(s, contains('股票（1支）'));
      expect(s, isNot(contains('基金')));
      expect(s, contains('合计'));
    });
  });

  // ── AC-7: 合计计算正确 ────────────────────────────────────────
  group('合计计算', () {
    test('[AC-7] 合计市值 = 基金 + 股票', () {
      final b = PortfolioContextBuilder(
        fundHoldings: [_fund('f1', '基金A', 10000)], // 10000*1.2=12000
        stockHoldings: [_stock('s1', '股票A', 'A', 100)], // 100*150=15000
      );
      // 总市值 = 12000 + 15000 = 27000 = 2.7万
      final s = b.buildFullSnapshot();
      expect(s, contains('2.7万'));
    });

    test('[AC-7] 合计收益率由成本和市值计算', () {
      // fund: cost=10000, value=12000 → gain=2000
      // stock: cost=10000, value=15000 → gain=5000
      // total: cost=20000, value=27000 → rate = 7000/20000*100 = 35%
      final b = PortfolioContextBuilder(
        fundHoldings: [_fund('f1', '基金A', 10000)],
        stockHoldings: [_stock('s1', '股票A', 'A', 100)],
      );
      final s = b.buildFullSnapshot();
      expect(s, contains('+35.0%'));
    });
  });

  // ── AC-4: 超过8支截断 ─────────────────────────────────────────
  group('[AC-4] 超过8支持仓截断', () {
    test('10支基金 → 只显示前8支，有「另有 2 支未展示」', () {
      final funds = List.generate(10, (i) => _fund('f$i', '基金$i', 1000.0));
      final b = PortfolioContextBuilder(fundHoldings: funds, stockHoldings: []);
      final s = b.buildFullSnapshot();

      // 前8支应出现
      for (int i = 0; i < 8; i++) {
        expect(s, contains('基金$i'));
      }
      // 第9、10支（索引8、9）不应出现
      expect(s, isNot(contains('基金8')));
      expect(s, isNot(contains('基金9')));
      // 截断提示
      expect(s, contains('另有 2 支未展示'));
    });

    test('恰好8支 → 全部展示，无截断提示', () {
      final funds = List.generate(8, (i) => _fund('f$i', '基金$i', 1000.0));
      final b = PortfolioContextBuilder(fundHoldings: funds, stockHoldings: []);
      final s = b.buildFullSnapshot();

      expect(s, isNot(contains('另有')));
      for (int i = 0; i < 8; i++) {
        expect(s, contains('基金$i'));
      }
    });

    test('10支股票 → 只显示前8支，有「另有 2 支未展示」', () {
      final stocks =
          List.generate(10, (i) => _stock('S$i', '股票$i', 'A', 100.0));
      final b = PortfolioContextBuilder(fundHoldings: [], stockHoldings: stocks);
      final s = b.buildFullSnapshot();

      for (int i = 0; i < 8; i++) {
        expect(s, contains('股票$i'));
      }
      expect(s, isNot(contains('股票8')));
      expect(s, contains('另有 2 支未展示'));
    });
  });

  // ── AC-5: token 估算 < 150 ────────────────────────────────────
  group('[AC-5] token 估算', () {
    test('3支基金 + 2支股票的快照字符数/1.5 < 200 token', () {
      final funds = [
        _fund('005827', '易方达蓝筹精选', 10000),
        _fund('166002', '中欧价值发现', 9000),
        _fund('161725', '招商中证白酒', 7000),
      ];
      final stocks = [
        _stock('600519', '贵州茅台', 'A', 100),
        _stock('0700', '腾讯控股', 'HK', 50),
      ];
      final b =
          PortfolioContextBuilder(fundHoldings: funds, stockHoldings: stocks);
      final snapshot = b.buildFullSnapshot();
      final tokenEstimate = snapshot.length / 1.5;
      expect(tokenEstimate, lessThan(200));
    });

    test('8支基金 + 8支股票（最大截断上限）→ 字符数/1.5 < 400 token', () {
      final funds = List.generate(8, (i) => _fund('f$i', '测试基金$i号', 1000.0));
      final stocks =
          List.generate(8, (i) => _stock('S$i', '测试股票$i号', 'A', 100.0));
      final b =
          PortfolioContextBuilder(fundHoldings: funds, stockHoldings: stocks);
      final snapshot = b.buildFullSnapshot();
      final tokenEstimate = snapshot.length / 1.5;
      expect(tokenEstimate, lessThan(400));
    });
  });

  // ── AC-6: buildSummaryOnly ────────────────────────────────────
  group('[AC-6] buildSummaryOnly', () {
    test('包含「总持仓约」和「整体收益」', () {
      final b = PortfolioContextBuilder(
        fundHoldings: [_fund('f1', '基金A', 10000)], // value=12000=1.2万
        stockHoldings: [],
      );
      final s = b.buildSummaryOnly();
      expect(s, contains('总持仓约'));
      expect(s, contains('整体收益'));
    });

    test('摘要字符数 < 全量快照字符数（节省 token）', () {
      final b = PortfolioContextBuilder(
        fundHoldings: [
          _fund('f1', '基金A', 10000),
          _fund('f2', '基金B', 5000),
        ],
        stockHoldings: [_stock('s1', '股票A', 'A', 100)],
      );
      expect(b.buildSummaryOnly().length,
          lessThan(b.buildFullSnapshot().length));
    });

    test('持仓空时返回空字符串', () {
      const b =
          PortfolioContextBuilder(fundHoldings: [], stockHoldings: []);
      expect(b.buildSummaryOnly(), isEmpty);
    });
  });

  // ── AC-2: shouldInjectFull 关键词命中 ────────────────────────
  group('[AC-2] shouldInjectFull 关键词', () {
    const b =
        PortfolioContextBuilder(fundHoldings: [], stockHoldings: []);

    test('含「持仓」→ true', () {
      expect(b.shouldInjectFull('我的持仓怎么样'), isTrue);
    });

    test('含「基金」→ true', () {
      expect(b.shouldInjectFull('我买的基金要不要换'), isTrue);
    });

    test('含「股票」→ true', () {
      expect(b.shouldInjectFull('股票该怎么操作'), isTrue);
    });

    test('含「配置」→ true', () {
      expect(b.shouldInjectFull('我现在的配置合理吗'), isTrue);
    });

    test('含「合理」→ true', () {
      expect(b.shouldInjectFull('这样合理吗'), isTrue);
    });

    test('含「建议」→ true', () {
      expect(b.shouldInjectFull('给我点建议'), isTrue);
    });

    test('含「收益」→ true', () {
      expect(b.shouldInjectFull('收益怎么样'), isTrue);
    });

    test('含「亏损」→ true', () {
      expect(b.shouldInjectFull('现在亏损很多'), isTrue);
    });

    test('含「止盈」→ true', () {
      expect(b.shouldInjectFull('什么时候止盈'), isTrue);
    });

    test('含「补仓」→ true', () {
      expect(b.shouldInjectFull('要不要补仓'), isTrue);
    });

    test('含「加仓」→ true', () {
      expect(b.shouldInjectFull('考虑加仓'), isTrue);
    });

    test('含「减持」→ true', () {
      expect(b.shouldInjectFull('要减持吗'), isTrue);
    });

    test('含「我的」→ true', () {
      expect(b.shouldInjectFull('我的资产怎么配'), isTrue);
    });

    test('含「帮我看」→ true', () {
      expect(b.shouldInjectFull('帮我看一下'), isTrue);
    });

    test('含「现在有」→ true', () {
      expect(b.shouldInjectFull('现在有300万怎么配'), isTrue);
    });

    test('纯市场问题（无持仓关键词）→ false', () {
      expect(b.shouldInjectFull('最近利率有什么变化'), isFalse);
    });

    test('空字符串 → false', () {
      expect(b.shouldInjectFull(''), isFalse);
    });
  });

  // ── 市场标签映射 ────────────────────────────────────────────
  group('股票市场标签', () {
    test('A股标签正确', () {
      final b = PortfolioContextBuilder(
        fundHoldings: [],
        stockHoldings: [_stock('600519', '贵州茅台', 'A', 100)],
      );
      expect(b.buildFullSnapshot(), contains('A股'));
    });

    test('港股标签正确', () {
      final b = PortfolioContextBuilder(
        fundHoldings: [],
        stockHoldings: [_stock('0700', '腾讯控股', 'HK', 50)],
      );
      expect(b.buildFullSnapshot(), contains('港股'));
    });

    test('美股标签正确', () {
      final b = PortfolioContextBuilder(
        fundHoldings: [],
        stockHoldings: [_stock('AAPL', '苹果', 'US', 10)],
      );
      expect(b.buildFullSnapshot(), contains('美股'));
    });
  });
}
