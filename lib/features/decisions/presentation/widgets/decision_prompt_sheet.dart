import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/decision_record.dart';
import '../providers/decision_provider.dart';

/// 轻量决策记录 BottomSheet
/// 从持仓操作（买入/加仓/减持）完成后弹出，预填类型/金额，用户只需填理由
class DecisionPromptSheet extends ConsumerStatefulWidget {
  final String productCategory;   // 预填产品类别
  final double amount;             // 预填金额（元）
  final String decisionType;       // DecisionType.*
  final String? holdingId;         // 关联持仓 ID（可选）
  final String holdingName;        // 显示用名称
  final List<String>? categoryOptions; // 可选择的类别子集，null = 全部

  const DecisionPromptSheet({
    super.key,
    required this.productCategory,
    required this.amount,
    required this.decisionType,
    this.holdingId,
    required this.holdingName,
    this.categoryOptions,
  });

  @override
  ConsumerState<DecisionPromptSheet> createState() =>
      _DecisionPromptSheetState();
}

class _DecisionPromptSheetState extends ConsumerState<DecisionPromptSheet> {
  final _rationaleCtrl = TextEditingController();
  late String _category;
  String _expectation = DecisionExpectation.priceUp;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _category = widget.productCategory;
    // 卖出默认"其他"预期
    if (widget.decisionType == DecisionType.sell) {
      _expectation = DecisionExpectation.other;
    }
  }

  @override
  void dispose() {
    _rationaleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_rationaleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写决策理由')),
      );
      return;
    }
    setState(() => _isSaving = true);

    final record = DecisionRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: widget.decisionType,
      productCategory: _category,
      amount: widget.amount,
      rationale: _rationaleCtrl.text.trim(),
      expectation: _expectation,
      linkedHoldingId: widget.holdingId,
      createdAt: DateTime.now(),
    );

    await ref.read(decisionRecordsProvider.notifier).addDecision(record);

    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('决策已记录，3个月后将自动复盘')),
      );
    }
  }

  void _skip() => Navigator.pop(context, false);

  @override
  Widget build(BuildContext context) {
    final amountStr = widget.amount >= 10000
        ? '${(widget.amount / 10000).toStringAsFixed(2)}万元'
        : '${widget.amount.toStringAsFixed(2)}元';

    final categories =
        widget.categoryOptions ?? decisionProductCategories;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 拖动条 ──
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 4),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // ── 标题 + 跳过按钮 ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '记录决策理由',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '3 / 6 / 12个月后自动复盘',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _skip,
                        child: const Text('跳过'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── 操作摘要（自动填充）──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _TypeBadge(widget.decisionType),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.holdingName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          amountStr,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── 产品类别 ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '产品类别',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: categories
                            .map((c) => ChoiceChip(
                                  label: Text(c,
                                      style:
                                          const TextStyle(fontSize: 12)),
                                  selected: _category == c,
                                  onSelected: (v) {
                                    if (v) {
                                      setState(() => _category = c);
                                    }
                                  },
                                  selectedColor: const Color(0xFF7C3AED),
                                  labelStyle: TextStyle(
                                    color: _category == c
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── 决策理由 ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '决策理由',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _rationaleCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: '为什么做这个决策？（如：利率下行通道锁定收益、看好AI板块等）',
                          hintStyle: TextStyle(
                              fontSize: 12,
                              color: AppColors.textHint),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF7C3AED), width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.all(14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── 决策预期 ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '决策预期',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          DecisionExpectation.rateDown,
                          DecisionExpectation.priceUp,
                          DecisionExpectation.riskHedge,
                          DecisionExpectation.other,
                        ]
                            .map((e) => ChoiceChip(
                                  label: Text(
                                      DecisionExpectation.label(e),
                                      style:
                                          const TextStyle(fontSize: 12)),
                                  selected: _expectation == e,
                                  onSelected: (v) {
                                    if (v) {
                                      setState(() => _expectation = e);
                                    }
                                  },
                                  selectedColor: const Color(0xFF7C3AED),
                                  labelStyle: TextStyle(
                                    color: _expectation == e
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── 记录按钮 ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        disabledBackgroundColor:
                            const Color(0xFF7C3AED).withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              '记录决策',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 类型徽章 ──
class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge(this.type);

  @override
  Widget build(BuildContext context) {
    final isBuy = type == DecisionType.buy;
    final color = isBuy ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        DecisionType.label(type),
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
