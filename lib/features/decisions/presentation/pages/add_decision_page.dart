import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/decision_record.dart';
import '../providers/decision_provider.dart';

class AddDecisionPage extends ConsumerStatefulWidget {
  const AddDecisionPage({super.key});

  @override
  ConsumerState<AddDecisionPage> createState() => _AddDecisionPageState();
}

class _AddDecisionPageState extends ConsumerState<AddDecisionPage> {
  String _type = DecisionType.buy;
  String _category = decisionProductCategories.first;
  String _expectation = DecisionExpectation.rateDown;
  final _amountCtrl = TextEditingController();
  final _rationaleCtrl = TextEditingController();
  bool _saving = false;

  static const _types = [
    DecisionType.buy,
    DecisionType.sell,
    DecisionType.rebalance,
    DecisionType.renew,
    DecisionType.pass_,
  ];

  static const _expectations = [
    DecisionExpectation.rateDown,
    DecisionExpectation.priceUp,
    DecisionExpectation.riskHedge,
    DecisionExpectation.other,
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _rationaleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效金额'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (_rationaleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写决策理由'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _saving = true);
    final record = DecisionRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: _type,
      productCategory: _category,
      amount: amount,
      rationale: _rationaleCtrl.text.trim(),
      expectation: _expectation,
      createdAt: DateTime.now(),
    );

    await ref.read(decisionRecordsProvider.notifier).addDecision(record);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('决策已记录，3个月后将自动复盘'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('记录一次决策'),
        backgroundColor: AppColors.surface,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('保存', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('决策类型', _buildTypeSelector()),
            const SizedBox(height: 16),
            _section('产品类别', _buildCategorySelector()),
            const SizedBox(height: 16),
            _section('涉及金额（元）', _buildAmountField()),
            const SizedBox(height: 16),
            _section('决策理由（用自己的话描述）', _buildRationaleField()),
            const SizedBox(height: 16),
            _section('你的预期', _buildExpectationSelector()),
            const SizedBox(height: 24),
            _buildHintCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      )),
      const SizedBox(height: 8),
      child,
    ],
  );

  Widget _buildTypeSelector() => Wrap(
    spacing: 8,
    children: _types.map((t) => ChoiceChip(
      label: Text(DecisionType.label(t)),
      selected: _type == t,
      onSelected: (_) => setState(() => _type = t),
      selectedColor: AppColors.primary.withOpacity(0.15),
      labelStyle: TextStyle(
        color: _type == t ? AppColors.primary : AppColors.textSecondary,
        fontWeight: _type == t ? FontWeight.w600 : FontWeight.normal,
      ),
    )).toList(),
  );

  Widget _buildCategorySelector() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: decisionProductCategories.map((c) => ChoiceChip(
      label: Text(c, style: const TextStyle(fontSize: 13)),
      selected: _category == c,
      onSelected: (_) => setState(() => _category = c),
      selectedColor: AppColors.primary.withOpacity(0.15),
      labelStyle: TextStyle(
        color: _category == c ? AppColors.primary : AppColors.textSecondary,
        fontWeight: _category == c ? FontWeight.w600 : FontWeight.normal,
      ),
    )).toList(),
  );

  Widget _buildAmountField() => TextField(
    controller: _amountCtrl,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      hintText: '例如：500000',
      prefixText: '¥ ',
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    ),
  );

  Widget _buildRationaleField() => TextField(
    controller: _rationaleCtrl,
    maxLines: 3,
    decoration: InputDecoration(
      hintText: '例如："利率要降了，提前锁定3年" 或 "跌了20%，觉得是低点加仓"',
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    ),
  );

  Widget _buildExpectationSelector() => Wrap(
    spacing: 8,
    children: _expectations.map((e) => ChoiceChip(
      label: Text(DecisionExpectation.label(e)),
      selected: _expectation == e,
      onSelected: (_) => setState(() => _expectation = e),
      selectedColor: AppColors.primary.withOpacity(0.15),
      labelStyle: TextStyle(
        color: _expectation == e ? AppColors.primary : AppColors.textSecondary,
        fontWeight: _expectation == e ? FontWeight.w600 : FontWeight.normal,
      ),
    )).toList(),
  );

  Widget _buildHintCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
    ),
    child: Row(
      children: [
        const Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 18),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'App 会在 3个月、6个月、1年后自动复盘这次决策，告诉你当时的判断是否正确。',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
        ),
      ],
    ),
  );
}
