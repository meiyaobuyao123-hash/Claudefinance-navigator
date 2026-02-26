import 'package:flutter/material.dart';
import 'dart:math';
import '../../../../core/theme/app_theme.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppBar(title: Text('财务工具')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ToolCard(
            icon: Icons.calculate,
            title: '复利计算器',
            subtitle: '本金 × 利率 × 年限，看看钱能变多少',
            color: const Color(0xFF6366F1),
            onTap: () => _showCompoundInterest(context),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: Icons.flag,
            title: '目标倒推计算器',
            subtitle: '想要达成目标，现在需要存多少',
            color: const Color(0xFF10B981),
            onTap: () => _showGoalPlanner(context),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: Icons.trending_down,
            title: '通胀侵蚀测算',
            subtitle: '看看通胀会吃掉你多少购买力',
            color: const Color(0xFFEF4444),
            onTap: () => _showInflationCalc(context),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: Icons.compare_arrows,
            title: '产品收益对比',
            subtitle: '同等本金，哪种产品到期最多',
            color: const Color(0xFFF59E0B),
            onTap: () => _showProductComparison(context),
          ),
        ],
      ),
    );
  }

  void _showCompoundInterest(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _CompoundInterestSheet(),
    );
  }

  void _showGoalPlanner(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _GoalPlannerSheet(),
    );
  }

  void _showInflationCalc(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _InflationSheet(),
    );
  }

  void _showProductComparison(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ProductComparisonSheet(),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

// ===================== 复利计算器 =====================
class _CompoundInterestSheet extends StatefulWidget {
  const _CompoundInterestSheet();

  @override
  State<_CompoundInterestSheet> createState() => _CompoundInterestSheetState();
}

class _CompoundInterestSheetState extends State<_CompoundInterestSheet> {
  final _principalCtrl = TextEditingController(text: '1000000');
  final _rateCtrl = TextEditingController(text: '3.0');
  final _yearsCtrl = TextEditingController(text: '10');
  double? _result;

  void _calculate() {
    final principal = double.tryParse(_principalCtrl.text) ?? 0;
    final rate = (double.tryParse(_rateCtrl.text) ?? 0) / 100;
    final years = int.tryParse(_yearsCtrl.text) ?? 0;
    setState(() {
      _result = principal * pow(1 + rate, years);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '复利计算器',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          _InputField(label: '本金（元）', controller: _principalCtrl),
          const SizedBox(height: 12),
          _InputField(label: '年化收益率（%）', controller: _rateCtrl),
          const SizedBox(height: 12),
          _InputField(label: '投资年限（年）', controller: _yearsCtrl),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _calculate,
              child: const Text('计算'),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text('到期总资产', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Text(
                    '¥${_formatMoney(_result!)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '增值 ¥${_formatMoney(_result! - (double.tryParse(_principalCtrl.text) ?? 0))}',
                    style: const TextStyle(fontSize: 13, color: AppColors.success),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _formatMoney(double v) {
    if (v >= 100000000) return '${(v / 100000000).toStringAsFixed(2)}亿';
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(2)}万';
    return v.toStringAsFixed(2);
  }
}

// ===================== 目标倒推 =====================
class _GoalPlannerSheet extends StatefulWidget {
  const _GoalPlannerSheet();

  @override
  State<_GoalPlannerSheet> createState() => _GoalPlannerSheetState();
}

class _GoalPlannerSheetState extends State<_GoalPlannerSheet> {
  final _targetCtrl = TextEditingController(text: '3000000');
  final _rateCtrl = TextEditingController(text: '3.5');
  final _yearsCtrl = TextEditingController(text: '10');
  double? _result;

  void _calculate() {
    final target = double.tryParse(_targetCtrl.text) ?? 0;
    final rate = (double.tryParse(_rateCtrl.text) ?? 0) / 100;
    final years = int.tryParse(_yearsCtrl.text) ?? 0;
    setState(() {
      _result = target / pow(1 + rate, years);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '目标倒推计算器',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const Text(
            '想知道要达成目标，现在需要准备多少钱？',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          _InputField(label: '目标金额（元）', controller: _targetCtrl),
          const SizedBox(height: 12),
          _InputField(label: '预期年化收益率（%）', controller: _rateCtrl),
          const SizedBox(height: 12),
          _InputField(label: '投资年限（年）', controller: _yearsCtrl),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _calculate,
              child: const Text('计算'),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text('现在需要准备', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Text(
                    '¥${_formatMoney(_result!)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _formatMoney(double v) {
    if (v >= 100000000) return '${(v / 100000000).toStringAsFixed(2)}亿';
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(2)}万';
    return v.toStringAsFixed(2);
  }
}

// ===================== 通胀测算 =====================
class _InflationSheet extends StatefulWidget {
  const _InflationSheet();

  @override
  State<_InflationSheet> createState() => _InflationSheetState();
}

class _InflationSheetState extends State<_InflationSheet> {
  final _amountCtrl = TextEditingController(text: '1000000');
  final _inflationCtrl = TextEditingController(text: '3.0');
  final _yearsCtrl = TextEditingController(text: '10');
  double? _realValue;
  double? _lostValue;

  void _calculate() {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final inflation = (double.tryParse(_inflationCtrl.text) ?? 0) / 100;
    final years = int.tryParse(_yearsCtrl.text) ?? 0;
    setState(() {
      _realValue = amount / pow(1 + inflation, years);
      _lostValue = amount - _realValue!;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '通胀侵蚀测算',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          _InputField(label: '当前金额（元）', controller: _amountCtrl),
          const SizedBox(height: 12),
          _InputField(label: '年通胀率（%，参考3%）', controller: _inflationCtrl),
          const SizedBox(height: 12),
          _InputField(label: '年限（年）', controller: _yearsCtrl),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _calculate,
              child: const Text('计算'),
            ),
          ),
          if (_realValue != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('实际购买力', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Text(
                            '¥${_formatMoney(_realValue!)}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('被通胀吃掉', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Text(
                            '¥${_formatMoney(_lostValue!)}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.error),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _formatMoney(double v) {
    if (v >= 100000000) return '${(v / 100000000).toStringAsFixed(2)}亿';
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(2)}万';
    return v.toStringAsFixed(2);
  }
}

// ===================== 产品对比 =====================
class _ProductComparisonSheet extends StatefulWidget {
  const _ProductComparisonSheet();

  @override
  State<_ProductComparisonSheet> createState() => _ProductComparisonSheetState();
}

class _ProductComparisonSheetState extends State<_ProductComparisonSheet> {
  final _principalCtrl = TextEditingController(text: '1000000');
  final _yearsCtrl = TextEditingController(text: '5');

  static const List<Map<String, dynamic>> _products = [
    {'name': '活期存款', 'rate': 0.15, 'color': Color(0xFF94A3B8)},
    {'name': '货币基金', 'rate': 1.7, 'color': Color(0xFF6EE7B7)},
    {'name': '1年定存', 'rate': 1.35, 'color': Color(0xFF10B981)},
    {'name': '3年定存', 'rate': 1.75, 'color': Color(0xFF059669)},
    {'name': '国债(5年)', 'rate': 2.50, 'color': Color(0xFF3B82F6)},
    {'name': '银行理财', 'rate': 3.0, 'color': Color(0xFF6366F1)},
    {'name': '债券基金', 'rate': 3.5, 'color': Color(0xFF8B5CF6)},
    {'name': '增额终身寿', 'rate': 2.9, 'color': Color(0xFFF59E0B)},
    {'name': '沪深300 ETF', 'rate': 6.0, 'color': Color(0xFFEF4444)},
    {'name': '港元存款', 'rate': 4.2, 'color': Color(0xFFEC4899)},
  ];

  List<Map<String, dynamic>>? _results;

  void _calculate() {
    final principal = double.tryParse(_principalCtrl.text) ?? 1000000;
    final years = int.tryParse(_yearsCtrl.text) ?? 5;
    final results = _products.map((p) {
      final rate = (p['rate'] as double) / 100;
      final total = principal * pow(1 + rate, years);
      return {
        'name': p['name'],
        'rate': p['rate'],
        'total': total,
        'gain': total - principal,
        'color': p['color'],
      };
    }).toList()
      ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
    setState(() => _results = results);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '产品收益对比',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _InputField(label: '本金（元）', controller: _principalCtrl)),
              const SizedBox(width: 12),
              SizedBox(width: 100, child: _InputField(label: '年限（年）', controller: _yearsCtrl)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _calculate, child: const Text('对比')),
          ),
          if (_results != null) ...[
            const SizedBox(height: 12),
            ...(_results!.asMap().entries.map((entry) {
              final item = entry.value;
              final maxTotal = _results!.first['total'] as double;
              final ratio = (item['total'] as double) / maxTotal;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        item['name'] as String,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(height: 20, decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                          )),
                          FractionallySizedBox(
                            widthFactor: ratio,
                            child: Container(height: 20, decoration: BoxDecoration(
                              color: item['color'] as Color,
                              borderRadius: BorderRadius.circular(10),
                            )),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '¥${_formatMoney(item['total'] as double)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            })),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _formatMoney(double v) {
    if (v >= 100000000) return '${(v / 100000000).toStringAsFixed(1)}亿';
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}万';
    return v.toStringAsFixed(0);
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _InputField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
