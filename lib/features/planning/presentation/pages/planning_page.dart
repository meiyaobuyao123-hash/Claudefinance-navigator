import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class PlanningPage extends StatefulWidget {
  const PlanningPage({super.key});

  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  // 五大资产类别及初始比例
  final _keys = ['流动资产', '稳健资产', '增值资产', '另类资产', '高弹性资产'];

  final Map<String, double> _allocation = {
    '流动资产': 15,
    '稳健资产': 40,
    '增值资产': 30,
    '另类资产': 10,
    '高弹性资产': 5,
  };

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
    '高弹性资产': '可转债 · 加密ETF',
  };

  late final Map<String, TextEditingController> _controllers;
  bool _hasEvaluated = false;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final k in _keys)
        k: TextEditingController(text: _allocation[k]!.toInt().toString())
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _total => _allocation.values.fold(0, (a, b) => a + b);
  bool get _isValid => (_total - 100).abs() < 0.5;

  void _onChanged(String key, String raw) {
    final v = double.tryParse(raw);
    if (v != null) {
      setState(() {
        _allocation[key] = v.clamp(0, 100);
        _hasEvaluated = false;
      });
    }
  }

  Map<String, dynamic> _evaluate() {
    final liquid = _allocation['流动资产'] ?? 0;
    final stable = _allocation['稳健资产'] ?? 0;
    final growth = _allocation['增值资产'] ?? 0;
    final speculative = _allocation['高弹性资产'] ?? 0;
    final alt = _allocation['另类资产'] ?? 0;

    int score = 100;
    final issues = <Map<String, dynamic>>[];

    // 流动性检查
    if (liquid < 10) {
      score -= 25;
      issues.add({'level': 'high', 'text': '流动资产仅 ${liquid.toInt()}%，应对紧急支出能力不足，建议保持 10–20%'});
    } else if (liquid > 30) {
      score -= 10;
      issues.add({'level': 'low', 'text': '流动资产 ${liquid.toInt()}% 偏高，大量资金停在低收益账户，跑不赢通胀'});
    }

    // 稳健层检查
    if (stable < 20) {
      score -= 15;
      issues.add({'level': 'medium', 'text': '稳健资产仅 ${stable.toInt()}%，整体组合波动风险偏高'});
    }

    // 进攻层过高
    if (growth + speculative > 60) {
      score -= 20;
      issues.add({'level': 'high', 'text': '高风险资产合计 ${(growth + speculative).toInt()}%，市场大幅下行时损失可能超过 30%'});
    }

    // 高弹性过高
    if (speculative > 20) {
      score -= 15;
      issues.add({'level': 'high', 'text': '高弹性资产 ${speculative.toInt()}% 偏高，波动极大，需要较强风险承受能力'});
    }

    // 分散化不足
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
              color: Colors.black.withOpacity(0.04),
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
            _AllocationBar(allocation: _allocation, keys: _keys, colors: _colors),
            const SizedBox(height: 20),

            // 资产类别输入行
            ..._keys.map((k) => _AssetRow(
                  label: k,
                  desc: _descriptions[k]!,
                  color: _colors[k]!,
                  controller: _controllers[k]!,
                  onChanged: (v) => _onChanged(k, v),
                )),
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
                  _isValid ? '评估我的配置' : '各项合计须等于 100%（当前 ${_total.toInt()}%）',
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
              color: Colors.black.withOpacity(0.04),
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
                          color: AppColors.primary.withOpacity(0.08),
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
                // 环形评分
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
            color: AppColors.primary.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
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
            ? AppColors.success.withOpacity(0.1)
            : AppColors.error.withOpacity(0.1),
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
                fillColor: color.withOpacity(0.08),
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
