import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

// ─── 维度模式 ───
enum _DimMode { byAttribute, byRegion, byType }

// ─── 维度配置数据类 ───
class _DimConfig {
  final String label;
  final String icon;
  final List<String> keys;
  final Map<String, String> descriptions;
  final Map<String, Color> colors;
  final Map<String, double> defaults;
  final Map<String, double> optimized;
  const _DimConfig({
    required this.label,
    required this.icon,
    required this.keys,
    required this.descriptions,
    required this.colors,
    required this.defaults,
    required this.optimized,
  });
}

// ─── 静态配置：三种维度 ───
const Map<_DimMode, _DimConfig> _configs = {
  // ── 按属性（原有）──
  _DimMode.byAttribute: _DimConfig(
    label: '按属性',
    icon: '📊',
    keys: ['流动资产', '稳健资产', '增值资产', '另类资产', '高弹性资产'],
    descriptions: {
      '流动资产': '活期 · 货币基金 · 随时可取',
      '稳健资产': '国债 · 定存 · 银行理财',
      '增值资产': '股票 · 基金 · ETF',
      '另类资产': '黄金 · 港险 · REITs',
      '高弹性资产': '可转债 · 加密ETF',
    },
    colors: {
      '流动资产': Color(0xFF10B981),
      '稳健资产': Color(0xFF3B82F6),
      '增值资产': Color(0xFFF59E0B),
      '另类资产': Color(0xFF8B5CF6),
      '高弹性资产': Color(0xFFEF4444),
    },
    defaults: {
      '流动资产': 15,
      '稳健资产': 40,
      '增值资产': 30,
      '另类资产': 10,
      '高弹性资产': 5,
    },
    optimized: {
      '流动资产': 15,
      '稳健资产': 45,
      '增值资产': 28,
      '另类资产': 8,
      '高弹性资产': 4,
    },
  ),

  // ── 按地区 ──
  _DimMode.byRegion: _DimConfig(
    label: '按地区',
    icon: '🌍',
    keys: ['大陆资产', '香港资产', '美元区', '加密资产', '现金'],
    descriptions: {
      '大陆资产': 'A股 · 基金 · 大陆存款 · 国债',
      '香港资产': '港股 · 港元定存 · 储蓄险',
      '美元区': '美股ETF · 美债 · 美元存款',
      '加密资产': '港版比特币ETF · 以太坊ETF',
      '现金': '人民币现金 · 货币基金',
    },
    colors: {
      '大陆资产': Color(0xFFEF4444),
      '香港资产': Color(0xFF8B5CF6),
      '美元区': Color(0xFF3B82F6),
      '加密资产': Color(0xFFF59E0B),
      '现金': Color(0xFF10B981),
    },
    defaults: {
      '大陆资产': 55,
      '香港资产': 20,
      '美元区': 15,
      '加密资产': 5,
      '现金': 5,
    },
    optimized: {
      '大陆资产': 50,
      '香港资产': 20,
      '美元区': 20,
      '加密资产': 5,
      '现金': 5,
    },
  ),

  // ── 按类型 ──
  _DimMode.byType: _DimConfig(
    label: '按类型',
    icon: '🏷️',
    keys: ['现金货基', '固定收益', '权益类', '保险理财', '贵金属', '加密资产'],
    descriptions: {
      '现金货基': '活期 · 货币基金 · 短期理财',
      '固定收益': '定存 · 国债 · 债基 · 银行理财',
      '权益类': 'A股 · 港股 · 美股 · 宽基ETF',
      '保险理财': '增额终身寿 · 年金险 · 万能险',
      '贵金属': '黄金ETF · 纸黄金 · 黄金积存',
      '加密资产': '港版比特币ETF · 以太坊ETF',
    },
    colors: {
      '现金货基': Color(0xFF10B981),
      '固定收益': Color(0xFF3B82F6),
      '权益类': Color(0xFFF59E0B),
      '保险理财': Color(0xFF8B5CF6),
      '贵金属': Color(0xFFD97706),
      '加密资产': Color(0xFFEF4444),
    },
    defaults: {
      '现金货基': 10,
      '固定收益': 35,
      '权益类': 35,
      '保险理财': 10,
      '贵金属': 5,
      '加密资产': 5,
    },
    optimized: {
      '现金货基': 10,
      '固定收益': 35,
      '权益类': 35,
      '保险理财': 12,
      '贵金属': 6,
      '加密资产': 2,
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
  _DimMode _dimMode = _DimMode.byAttribute;
  bool _hasEvaluated = false;

  // 每种维度保存独立的配置比例（切换时数据保留）
  late final Map<_DimMode, Map<String, double>> _allocations;
  late Map<String, TextEditingController> _controllers;

  _DimConfig get _cfg => _configs[_dimMode]!;
  Map<String, double> get _alloc => _allocations[_dimMode]!;

  @override
  void initState() {
    super.initState();
    // 初始化每种模式的默认比例
    _allocations = {
      for (final entry in _configs.entries)
        entry.key: Map<String, double>.from(entry.value.defaults),
    };
    _controllers = _buildControllers(_dimMode);
  }

  Map<String, TextEditingController> _buildControllers(_DimMode mode) {
    final config = _configs[mode]!;
    final alloc = _allocations[mode]!;
    return {
      for (final k in config.keys)
        k: TextEditingController(text: alloc[k]!.toInt().toString()),
    };
  }

  void _switchMode(_DimMode mode) {
    if (mode == _dimMode) return;
    for (final c in _controllers.values) {
      c.dispose();
    }
    setState(() {
      _dimMode = mode;
      _hasEvaluated = false;
      _controllers = _buildControllers(mode);
    });
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _total => _alloc.values.fold(0, (a, b) => a + b);
  bool get _isValid => (_total - 100).abs() < 0.5;

  void _onChanged(String key, String raw) {
    final v = double.tryParse(raw);
    if (v != null) {
      setState(() {
        _alloc[key] = v.clamp(0, 100);
        _hasEvaluated = false;
      });
    }
  }

  // ─── 评估逻辑（按模式分派）───
  Map<String, dynamic> _evaluate() {
    switch (_dimMode) {
      case _DimMode.byAttribute:
        return _evalByAttribute();
      case _DimMode.byRegion:
        return _evalByRegion();
      case _DimMode.byType:
        return _evalByType();
    }
  }

  Map<String, dynamic> _evalByAttribute() {
    final liquid = _alloc['流动资产'] ?? 0;
    final stable = _alloc['稳健资产'] ?? 0;
    final growth = _alloc['增值资产'] ?? 0;
    final speculative = _alloc['高弹性资产'] ?? 0;
    final alt = _alloc['另类资产'] ?? 0;

    int score = 100;
    final issues = <Map<String, dynamic>>[];

    if (liquid < 10) {
      score -= 25;
      issues.add({'level': 'high', 'text': '流动资产仅 ${liquid.toInt()}%，应对紧急支出能力不足，建议保持 10–20%'});
    } else if (liquid > 30) {
      score -= 10;
      issues.add({'level': 'low', 'text': '流动资产 ${liquid.toInt()}% 偏高，大量资金停在低收益账户，跑不赢通胀'});
    }
    if (stable < 20) {
      score -= 15;
      issues.add({'level': 'medium', 'text': '稳健资产仅 ${stable.toInt()}%，整体组合波动风险偏高'});
    }
    if (growth + speculative > 60) {
      score -= 20;
      issues.add({'level': 'high', 'text': '高风险资产合计 ${(growth + speculative).toInt()}%，市场大幅下行时损失可能超过 30%'});
    }
    if (speculative > 20) {
      score -= 15;
      issues.add({'level': 'high', 'text': '高弹性资产 ${speculative.toInt()}% 偏高，波动极大，需要较强风险承受能力'});
    }
    if (alt == 0) {
      score -= 5;
      issues.add({'level': 'low', 'text': '未配置另类资产（黄金/港险/REITs），相关性分散有提升空间'});
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
    return {'score': score, 'style': style, 'issues': issues};
  }

  Map<String, dynamic> _evalByRegion() {
    final mainland = _alloc['大陆资产'] ?? 0;
    final hk = _alloc['香港资产'] ?? 0;
    final usd = _alloc['美元区'] ?? 0;
    final crypto = _alloc['加密资产'] ?? 0;
    final cash = _alloc['现金'] ?? 0;

    int score = 100;
    final issues = <Map<String, dynamic>>[];

    if (mainland > 80) {
      score -= 25;
      issues.add({'level': 'high', 'text': '大陆资产 ${mainland.toInt()}% 过于集中，单一市场风险高，建议境外敞口 ≥ 20%'});
    } else if (mainland > 70) {
      score -= 10;
      issues.add({'level': 'medium', 'text': '大陆资产 ${mainland.toInt()}% 偏高，适度增加海外配置可分散单一市场风险'});
    }
    if (hk + usd < 10) {
      score -= 20;
      issues.add({'level': 'high', 'text': '境外资产仅 ${(hk + usd).toInt()}%，缺乏国际化配置，无法对冲汇率与地缘政治风险'});
    }
    if (crypto > 10) {
      score -= 20;
      issues.add({'level': 'high', 'text': '加密资产 ${crypto.toInt()}% 偏高，波动极大，建议不超过总资产 5%'});
    } else if (crypto > 5) {
      score -= 8;
      issues.add({'level': 'medium', 'text': '加密资产 ${crypto.toInt()}% 处于较高水平，需具备极高风险承受能力'});
    }
    if (cash < 5) {
      score -= 15;
      issues.add({'level': 'high', 'text': '现金 ${cash.toInt()}% 过低，流动性不足，难以应对突发资金需求'});
    }
    if (usd > 40) {
      score -= 10;
      issues.add({'level': 'medium', 'text': '美元区 ${usd.toInt()}% 较高，需注意汇率波动风险及政策风险'});
    }

    score = score.clamp(0, 100);
    String style;
    if (mainland >= 70) {
      style = '本土集中型';
    } else if (hk + usd >= 40) {
      style = '国际化配置型';
    } else {
      style = '均衡多元型';
    }
    return {'score': score, 'style': style, 'issues': issues};
  }

  Map<String, dynamic> _evalByType() {
    final cash = _alloc['现金货基'] ?? 0;
    final fixed = _alloc['固定收益'] ?? 0;
    final equity = _alloc['权益类'] ?? 0;
    final insurance = _alloc['保险理财'] ?? 0;
    final gold = _alloc['贵金属'] ?? 0;
    final crypto = _alloc['加密资产'] ?? 0;

    int score = 100;
    final issues = <Map<String, dynamic>>[];

    if (cash < 5) {
      score -= 20;
      issues.add({'level': 'high', 'text': '现金货基仅 ${cash.toInt()}%，流动性不足，建议保持 5–15%'});
    } else if (cash > 20) {
      score -= 8;
      issues.add({'level': 'low', 'text': '现金货基 ${cash.toInt()}% 偏高，大量资金收益偏低，可适当转入固定收益'});
    }
    if (fixed < 20) {
      score -= 15;
      issues.add({'level': 'medium', 'text': '固定收益仅 ${fixed.toInt()}%，组合稳定性偏低，遇市场下行时回撤可能较大'});
    }
    if (equity > 60) {
      score -= 20;
      issues.add({'level': 'high', 'text': '权益类 ${equity.toInt()}% 偏高，高波动资产占比过大，熊市可能承受 30%+ 浮亏'});
    }
    if (insurance == 0) {
      score -= 5;
      issues.add({'level': 'low', 'text': '未配置保险理财（增额寿/年金），缺少"锁定收益 + 隔离风险"的底层保障'});
    }
    if (gold == 0) {
      score -= 5;
      issues.add({'level': 'low', 'text': '未配置贵金属，黄金在通胀/避险情境下与股债相关性低，适合作对冲'});
    }
    if (crypto > 10) {
      score -= 15;
      issues.add({'level': 'high', 'text': '加密资产 ${crypto.toInt()}%，建议严格控制在 5% 以内，仅适合极高风险偏好者'});
    }

    score = score.clamp(0, 100);
    String style;
    if (cash + fixed > 60) {
      style = '保守固收型';
    } else if (equity > 50) {
      style = '权益偏重型';
    } else {
      style = '多元均衡型';
    }
    return {'score': score, 'style': style, 'issues': issues};
  }

  void _applyOptimized() {
    final opt = _cfg.optimized;
    setState(() {
      for (final k in _cfg.keys) {
        _alloc[k] = opt[k]!.toDouble();
        _controllers[k]!.text = opt[k]!.toInt().toString();
      }
      _hasEvaluated = true;
    });
  }

  Color _scoreColor(int score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.warning;
    return AppColors.error;
  }

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

  // ─────────────── Header ───────────────
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
            '输入你的配置比例，获取健康评估与优化建议',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ─────────────── 评估器卡片 ───────────────
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
            // ── 标题行 ──
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
            const SizedBox(height: 14),

            // ── 维度切换器 ──
            _DimModeSwitcher(
              current: _dimMode,
              onChanged: _switchMode,
            ),
            const SizedBox(height: 16),

            // ── 彩色分配条 ──
            _AllocationBar(
              allocation: _alloc,
              keys: _cfg.keys,
              colors: _cfg.colors,
            ),
            const SizedBox(height: 20),

            // ── 资产输入行 ──
            ..._cfg.keys.map((k) => _AssetRow(
                  label: k,
                  desc: _cfg.descriptions[k]!,
                  color: _cfg.colors[k]!,
                  controller: _controllers[k]!,
                  onChanged: (v) => _onChanged(k, v),
                )),
            const SizedBox(height: 16),

            // ── 评估按钮 ──
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

  // ─────────────── 评估结果卡片 ───────────────
  Widget _buildResultCard(Map<String, dynamic> result) {
    final score = result['score'] as int;
    final style = result['style'] as String;
    final issues = result['issues'] as List<Map<String, dynamic>>;
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
                        '配置健康评分（${_cfg.label}维度）',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
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
                            padding: const EdgeInsets.only(bottom: 8, left: 3),
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
                          color: AppColors.primary.withValues(alpha: 0.08),
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

            // 风险提示
            if (issues.isNotEmpty) ...[
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
              ...issues.map((issue) => _IssueRow(issue: issue)),
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
            border:
                Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
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

// ─────────────── 维度切换器 ───────────────
class _DimModeSwitcher extends StatelessWidget {
  final _DimMode current;
  final ValueChanged<_DimMode> onChanged;

  const _DimModeSwitcher({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: _DimMode.values.map((mode) {
          final cfg = _configs[mode]!;
          final selected = mode == current;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                decoration: BoxDecoration(
                  color: selected ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(cfg.icon, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      cfg.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────── 合计徽章 ───────────────
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

// ─────────────── 分配条 ───────────────
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
          final frac = ((allocation[k] ?? 0) / total).clamp(0.0, 1.0);
          return Expanded(
            flex: (frac * 1000).round().clamp(1, 1000),
            child: Container(height: 8, color: colors[k]),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────── 资产输入行 ───────────────
class _AssetRow extends StatelessWidget {
  final String label;
  final String desc;
  final Color color;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _AssetRow({
    required this.label,
    required this.desc,
    required this.color,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                Text(desc,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          SizedBox(
            width: 72,
            child: TextField(
              controller: controller,
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────── 风险提示行 ───────────────
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
                style: TextStyle(fontSize: 13, color: color, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
