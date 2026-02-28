import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

// ─── 子维度配置 ───
class _SubConfig {
  final List<String> keys;
  final Map<String, String> descriptions;
  final Map<String, double> defaultRatios; // 各子类默认比例（合计为 1.0）
  const _SubConfig({
    required this.keys,
    required this.descriptions,
    required this.defaultRatios,
  });
}

// 支持子维度展开的类别（4个）
const Map<String, _SubConfig> _subConfigs = {
  '稳健资产': _SubConfig(
    keys: ['定期存款/大额存单', '国债', '银行理财/债基'],
    descriptions: {
      '定期存款/大额存单': '1–5年定期，20万起享大额存单',
      '国债': '3年2.38% / 5年2.5%，免税',
      '银行理财/债基': '净值型R2，流动性优于定存',
    },
    defaultRatios: {
      '定期存款/大额存单': 0.5,
      '国债': 0.25,
      '银行理财/债基': 0.25,
    },
  ),
  '增值资产': _SubConfig(
    keys: ['A股', '港股', '美股'],
    descriptions: {
      'A股': '沪深300 / 中证500 / 主动基金',
      '港股': '港股通 / 港股ETF / H股',
      '美股': 'QDII纳指 / 标普500 / IBKR',
    },
    defaultRatios: {
      'A股': 0.67,
      '港股': 0.17,
      '美股': 0.16,
    },
  ),
  '另类资产': _SubConfig(
    keys: ['黄金', '港险/储蓄险', 'REITs'],
    descriptions: {
      '黄金': 'ETF / 纸黄金 / 黄金积存',
      '港险/储蓄险': 'IRR 4-6%，需赴港开户',
      'REITs': '公募REITs，分红稳定',
    },
    defaultRatios: {
      '黄金': 0.5,
      '港险/储蓄险': 0.3,
      'REITs': 0.2,
    },
  ),
  '高弹性资产': _SubConfig(
    keys: ['可转债', 'BTC+ETH', '其他加密'],
    descriptions: {
      '可转债': '低价偏债型保安全 / 高价偏股型博弹性',
      'BTC+ETH': '市值最大的两只，流动性最好、监管最清晰',
      '其他加密': '公链代币 / 山寨币，高风险高波动',
    },
    defaultRatios: {
      '可转债': 0.6,
      'BTC+ETH': 0.3,
      '其他加密': 0.1,
    },
  ),
};

// ─────────────────────────────────────────
class PlanningPage extends StatefulWidget {
  const PlanningPage({super.key});

  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  // ── L1：5大属性类别 ──
  static const List<String> _keys = [
    '流动资产', '稳健资产', '增值资产', '另类资产', '高弹性资产'
  ];

  static const Map<String, Color> _colors = {
    '流动资产': Color(0xFF10B981),
    '稳健资产': Color(0xFF3B82F6),
    '增值资产': Color(0xFFF59E0B),
    '另类资产': Color(0xFF8B5CF6),
    '高弹性资产': Color(0xFFEF4444),
  };

  static const Map<String, String> _descriptions = {
    '流动资产': '活期 · 货币基金 · 随时可取',
    '稳健资产': '国债 · 定存 · 银行理财',
    '增值资产': '股票 · 基金 · ETF',
    '另类资产': '黄金 · 港险 · REITs',
    '高弹性资产': '可转债 · BTC+ETH · 其他加密',
  };

  final Map<String, double> _allocation = {
    '流动资产': 15,
    '稳健资产': 40,
    '增值资产': 30,
    '另类资产': 10,
    '高弹性资产': 5,
  };

  late final Map<String, TextEditingController> _controllers;

  // ── L2：子维度 ──
  final Map<String, bool> _expanded = {
    '稳健资产': false,
    '增值资产': false,
    '另类资产': false,
    '高弹性资产': false,
  };

  // 仅在展开后才初始化（懒加载）
  final Map<String, Map<String, double>> _subAlloc = {};
  final Map<String, Map<String, TextEditingController>> _subCtrl = {};

  bool _hasEvaluated = false;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final k in _keys)
        k: TextEditingController(text: _allocation[k]!.toInt().toString()),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final subMap in _subCtrl.values) {
      for (final c in subMap.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  // ── 基础计算 ──
  double get _total => _allocation.values.fold(0, (a, b) => a + b);
  bool get _isValid => (_total - 100).abs() < 0.5;

  double _subTotal(String parentKey) {
    final sub = _subAlloc[parentKey];
    if (sub == null) return 0;
    return sub.values.fold(0, (a, b) => a + b);
  }

  bool _subValid(String parentKey) {
    if (!(_expanded[parentKey] ?? false)) return true;
    if (!_subAlloc.containsKey(parentKey)) return true;
    return (_subTotal(parentKey) - (_allocation[parentKey] ?? 0)).abs() < 0.5;
  }

  // ── 事件处理 ──
  void _onL1Changed(String key, String raw) {
    final v = double.tryParse(raw);
    if (v != null) {
      setState(() {
        _allocation[key] = v.clamp(0, 100);
        _hasEvaluated = false;
      });
    }
  }

  void _onL2Changed(String parentKey, String subKey, String raw) {
    final v = double.tryParse(raw);
    if (v != null) {
      setState(() {
        _subAlloc[parentKey]![subKey] = v.clamp(0, 100);
        _hasEvaluated = false;
      });
    }
  }

  void _toggleExpand(String key) {
    setState(() {
      final wasExpanded = _expanded[key]!;
      if (!wasExpanded && !_subAlloc.containsKey(key)) {
        // 首次展开：按父类值等比初始化子类
        _initSubValues(key);
      }
      _expanded[key] = !wasExpanded;
      _hasEvaluated = false;
    });
  }

  void _initSubValues(String key) {
    final config = _subConfigs[key]!;
    final parentValue = _allocation[key]!;
    final subValues = <String, double>{};
    double allocated = 0;

    for (int i = 0; i < config.keys.length; i++) {
      final subKey = config.keys[i];
      if (i == config.keys.length - 1) {
        // 最后一项填余量，避免四舍五入误差
        subValues[subKey] = (parentValue - allocated).clamp(0, parentValue);
      } else {
        final v = (parentValue * config.defaultRatios[subKey]!).roundToDouble();
        subValues[subKey] = v;
        allocated += v;
      }
    }

    // 处理旧控制器
    if (_subCtrl.containsKey(key)) {
      for (final c in _subCtrl[key]!.values) {
        c.dispose();
      }
    }

    _subAlloc[key] = subValues;
    _subCtrl[key] = {
      for (final subKey in config.keys)
        subKey: TextEditingController(
          text: subValues[subKey]!.toInt().toString(),
        ),
    };
  }

  // ─── 评估逻辑 ───
  Map<String, dynamic> _evaluate() {
    final liquid = _allocation['流动资产'] ?? 0;
    final stable = _allocation['稳健资产'] ?? 0;
    final growth = _allocation['增值资产'] ?? 0;
    final speculative = _allocation['高弹性资产'] ?? 0;
    final alt = _allocation['另类资产'] ?? 0;

    int score = 100;
    final l1Issues = <Map<String, dynamic>>[];
    final l2Issues = <Map<String, dynamic>>[];

    // ──────────────────────────────────────
    // L1：5大属性（始终运行）
    // ──────────────────────────────────────
    if (liquid < 10) {
      score -= 25;
      l1Issues.add({'level': 'high', 'text': '流动资产仅 ${liquid.toInt()}%，应对紧急支出能力不足，建议保持 10–20%'});
    } else if (liquid > 30) {
      score -= 10;
      l1Issues.add({'level': 'low', 'text': '流动资产 ${liquid.toInt()}% 偏高，大量资金停在低收益账户，跑不赢通胀'});
    }

    if (stable < 20) {
      score -= 15;
      l1Issues.add({'level': 'medium', 'text': '稳健资产仅 ${stable.toInt()}%，整体组合波动风险偏高'});
    }

    if (growth + speculative > 60) {
      score -= 20;
      l1Issues.add({'level': 'high', 'text': '高风险资产合计 ${(growth + speculative).toInt()}%，大熊市可能承受 30%+ 浮亏'});
    }

    if (speculative > 20) {
      score -= 15;
      l1Issues.add({'level': 'high', 'text': '高弹性资产 ${speculative.toInt()}% 偏高，波动极大，需较强风险承受能力'});
    }

    if (alt == 0) {
      score -= 5;
      l1Issues.add({'level': 'low', 'text': '未配置另类资产（黄金/港险/REITs），相关性分散有提升空间'});
    }

    // ──────────────────────────────────────
    // L2：子维度（仅展开且已填写时运行）
    // ──────────────────────────────────────

    // 稳健资产子维度
    if ((_expanded['稳健资产'] ?? false) && _subAlloc.containsKey('稳健资产')) {
      final sub = _subAlloc['稳健资产']!;
      final deposit = sub['定期存款/大额存单'] ?? 0;
      final bond = sub['银行理财/债基'] ?? 0;
      if (stable > 0 && deposit / stable > 0.9) {
        score -= 5;
        l2Issues.add({'level': 'low', 'text': '稳健资产中定存占 ${deposit.toInt()}%（90%+），流动性差，建议配 10–20% 债基'});
      }
      if (stable > 0 && bond / stable > 0.9) {
        score -= 5;
        l2Issues.add({'level': 'medium', 'text': '稳健资产全在净值型理财/债基，存在波动风险，建议搭配定存/国债作稳定底仓'});
      }
    }

    // 增值资产子维度
    if ((_expanded['增值资产'] ?? false) && _subAlloc.containsKey('增值资产')) {
      final sub = _subAlloc['增值资产']!;
      final aShares = sub['A股'] ?? 0;
      final hkShares = sub['港股'] ?? 0;
      final usShares = sub['美股'] ?? 0;
      final growthTotal = aShares + hkShares + usShares;

      if (growthTotal > 0) {
        if (aShares / growthTotal > 0.8) {
          score -= 10;
          l2Issues.add({'level': 'high', 'text': '增值资产中A股占 ${(aShares / growthTotal * 100).toInt()}%，境内权益集中，建议增加港股/美股分散单一市场风险'});
        }
        if (hkShares + usShares == 0) {
          score -= 5;
          l2Issues.add({'level': 'medium', 'text': '增值资产无境外敞口，可考虑QDII（标普/纳指）或港股通，对冲人民币汇率风险'});
        } else if (usShares / growthTotal > 0.6) {
          score -= 8;
          l2Issues.add({'level': 'medium', 'text': '美股占增值资产 ${(usShares / growthTotal * 100).toInt()}%，集中度过高，注意美元汇率及估值风险'});
        }
      }
    }

    // 高弹性资产子维度
    if ((_expanded['高弹性资产'] ?? false) && _subAlloc.containsKey('高弹性资产')) {
      final sub = _subAlloc['高弹性资产']!;
      final btcEth = sub['BTC+ETH'] ?? 0;
      final otherCrypto = sub['其他加密'] ?? 0;
      final cb = sub['可转债'] ?? 0;
      final cryptoTotal = btcEth + otherCrypto;

      if (speculative > 0 && otherCrypto / speculative > 0.5) {
        score -= 10;
        l2Issues.add({'level': 'high', 'text': '其他加密占高弹性资产 ${(otherCrypto / speculative * 100).toInt()}%，山寨币风险极高，建议优先布局BTC+ETH'});
      }
      if (speculative > 0 && cryptoTotal / speculative > 0.8) {
        score -= 8;
        l2Issues.add({'level': 'medium', 'text': '高弹性资产中加密占比 ${(cryptoTotal / speculative * 100).toInt()}%，可考虑搭配部分可转债降低整体波动'});
      }
      if (speculative > 0 && cb == 0 && cryptoTotal > 0) {
        score -= 5;
        l2Issues.add({'level': 'low', 'text': '未配置可转债，可转债兼具"债底保底 + 股性弹性"，适合作为加密资产的缓冲配置'});
      }
    }

    // 另类资产子维度
    if ((_expanded['另类资产'] ?? false) && _subAlloc.containsKey('另类资产')) {
      final sub = _subAlloc['另类资产']!;
      final gold = sub['黄金'] ?? 0;
      final insurance = sub['港险/储蓄险'] ?? 0;
      if (alt > 0 && gold == 0) {
        score -= 3;
        l2Issues.add({'level': 'low', 'text': '另类中未配黄金，通胀/避险行情下缺少对冲工具，黄金ETF门槛低、流动性好'});
      }
      if (alt > 0 && insurance == 0) {
        score -= 3;
        l2Issues.add({'level': 'low', 'text': '未配港险，香港储蓄险IRR约4-6%，适合长期稳健增值，可考虑赴港开户'});
      }
    }

    score = score.clamp(0, 100);

    String style;
    if (liquid + stable > 70) {
      style = '稳健保守型';
    } else if (growth + speculative > 55) {
      style = '积极进取型';
    } else {
      style = '均衡配置型';
    }

    return {
      'score': score,
      'style': style,
      'l1Issues': l1Issues,
      'l2Issues': l2Issues,
      'hasL2': l2Issues.isNotEmpty,
    };
  }

  void _applyOptimized() {
    setState(() {
      _allocation['流动资产'] = 15;
      _allocation['稳健资产'] = 45;
      _allocation['增值资产'] = 28;
      _allocation['另类资产'] = 8;
      _allocation['高弹性资产'] = 4;
      for (final k in _keys) {
        _controllers[k]!.text = _allocation[k]!.toInt().toString();
      }
      // 同步更新已展开的子维度
      for (final key in _expanded.keys) {
        if (_expanded[key]! && _subAlloc.containsKey(key)) {
          _initSubValues(key);
        }
      }
      _hasEvaluated = true;
    });
  }

  Color _scoreColor(int score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.warning;
    return AppColors.error;
  }

  // ─────────────── Build ───────────────
  @override
  Widget build(BuildContext context) {
    final result = _isValid && _hasEvaluated ? _evaluate() : null;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildEvaluatorCard()),
            if (result != null)
              SliverToBoxAdapter(child: _buildResultCard(result)),
            SliverToBoxAdapter(child: _buildAiEntry()),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '资产配置',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '输入配置比例，可展开细分子维度获取更精准建议',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluatorCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '当前配置',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                _TotalBadge(total: _total, isValid: _isValid),
              ],
            ),
            const SizedBox(height: 16),

            // 彩色分配条
            _AllocationBar(
                allocation: _allocation, keys: _keys, colors: _colors),
            const SizedBox(height: 20),

            // 资产行（含子维度展开）
            ..._keys.map((k) => _buildAssetSection(k)),
            const SizedBox(height: 16),

            // 评估按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isValid
                    ? () => setState(() => _hasEvaluated = true)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.surfaceVariant,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: AppColors.textHint,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  _isValid
                      ? '评估我的配置'
                      : '各项合计须等于 100%（当前 ${_total.toInt()}%）',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 单个资产行（含可选子维度展开区）
  Widget _buildAssetSection(String key) {
    final hasSubDim = _subConfigs.containsKey(key);
    final isExpanded = _expanded[key] ?? false;
    final color = _colors[key]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 主行 ──
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(key,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary)),
                    Text(_descriptions[key]!,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              // "细分" 展开按钮（只有 3 个类别有）
              if (hasSubDim) ...[
                GestureDetector(
                  onTap: () => _toggleExpand(key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isExpanded
                          ? color.withValues(alpha: 0.12)
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isExpanded ? '收起' : '细分',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isExpanded
                                ? color
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          isExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 14,
                          color: isExpanded
                              ? color
                              : AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              // 百分比输入框
              SizedBox(
                width: 72,
                child: TextField(
                  controller: _controllers[key]!,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: color),
                  decoration: InputDecoration(
                    suffixText: '%',
                    suffixStyle: TextStyle(fontSize: 14, color: color),
                    filled: true,
                    fillColor: color.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 10),
                  ),
                  onChanged: (v) => _onL1Changed(key, v),
                ),
              ),
            ],
          ),
        ),

        // ── 子维度展开区 ──
        if (hasSubDim && isExpanded && _subAlloc.containsKey(key)) ...[
          _buildSubSection(key),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _buildSubSection(String parentKey) {
    final config = _subConfigs[parentKey]!;
    final color = _colors[parentKey]!;
    final subTotal = _subTotal(parentKey);
    final parentVal = _allocation[parentKey] ?? 0;
    final isMatch = (subTotal - parentVal).abs() < 0.5;

    return Container(
      margin: const EdgeInsets.only(left: 20, bottom: 14),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMatch
              ? color.withValues(alpha: 0.2)
              : AppColors.error.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题 + 子类合计提示
          Row(
            children: [
              Text(
                '细分配置',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isMatch
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '合计 ${subTotal.toInt()}% / 应为 ${parentVal.toInt()}%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isMatch ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 子类输入行
          ...config.keys.map((subKey) {
            final subColor = color.withValues(alpha: 0.75);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subKey,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary)),
                        Text(config.descriptions[subKey]!,
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: TextField(
                      controller: _subCtrl[parentKey]![subKey]!,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: subColor),
                      decoration: InputDecoration(
                        suffixText: '%',
                        suffixStyle:
                            TextStyle(fontSize: 11, color: subColor),
                        filled: true,
                        fillColor: color.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 8),
                      ),
                      onChanged: (v) =>
                          _onL2Changed(parentKey, subKey, v),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─────────────── 评估结果卡片 ───────────────
  Widget _buildResultCard(Map<String, dynamic> result) {
    final score = result['score'] as int;
    final style = result['style'] as String;
    final l1Issues = result['l1Issues'] as List<Map<String, dynamic>>;
    final l2Issues = result['l2Issues'] as List<Map<String, dynamic>>;
    final hasL2 = result['hasL2'] as bool;
    final color = _scoreColor(score);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 评分区
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '配置健康评分',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$score',
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w700,
                              color: color,
                              height: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                                bottom: 8, left: 3),
                            child: Text('分',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.textSecondary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          style,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 76,
                  height: 76,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 7,
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                      Text(
                        score >= 80
                            ? '优'
                            : score >= 60
                                ? '良'
                                : '待改善',
                        style: TextStyle(
                          fontSize: score >= 80 ? 17 : 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // L1 风险提示
            if (l1Issues.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 16),
              const Text(
                '风险提示',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              ...l1Issues.map((issue) => _IssueRow(issue: issue)),
            ],

            // L2 细分维度提示（仅有子维度数据时显示）
            if (hasL2) ...[
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    '细分维度提示',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '基于你的细分数据',
                      style: TextStyle(
                          fontSize: 10, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...l2Issues.map((issue) => _IssueRow(issue: issue)),
            ],

            const SizedBox(height: 16),

            // 优化建议按钮
            OutlinedButton(
              onPressed: _applyOptimized,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                minimumSize: const Size(double.infinity, 0),
              ),
              child: const Text(
                '查看优化建议配置',
                style:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────── 问明理入口 ───────────────
  Widget _buildAiEntry() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GestureDetector(
        onTap: () => context.go('/chat'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.psychology_outlined,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '不知道该怎么填？问明理',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'AI 顾问帮你梳理适合的配置方向',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────── 子组件 ───────────────

class _TotalBadge extends StatelessWidget {
  final double total;
  final bool isValid;
  const _TotalBadge({required this.total, required this.isValid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isValid
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '合计 ${total.toInt()}%',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isValid ? AppColors.success : AppColors.error,
        ),
      ),
    );
  }
}

class _AllocationBar extends StatelessWidget {
  final Map<String, double> allocation;
  final List<String> keys;
  final Map<String, Color> colors;
  const _AllocationBar(
      {required this.allocation, required this.keys, required this.colors});

  @override
  Widget build(BuildContext context) {
    final total = allocation.values.fold(0.0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Row(
        children: keys.map((k) {
          final frac =
              ((allocation[k] ?? 0) / total).clamp(0.0, 1.0);
          return Expanded(
            flex: (frac * 1000).round().clamp(1, 1000),
            child: Container(height: 8, color: colors[k]),
          );
        }).toList(),
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  final Map<String, dynamic> issue;
  const _IssueRow({required this.issue});

  @override
  Widget build(BuildContext context) {
    final level = issue['level'] as String;
    final text = issue['text'] as String;
    final color = level == 'high'
        ? AppColors.error
        : level == 'medium'
            ? AppColors.warning
            : AppColors.textSecondary;
    final emoji =
        level == 'high' ? '🔴' : level == 'medium' ? '🟡' : '🟢';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style:
                    TextStyle(fontSize: 13, color: color, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
