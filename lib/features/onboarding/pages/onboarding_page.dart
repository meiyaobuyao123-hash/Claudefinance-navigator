import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../models/user_profile.dart';
import '../providers/user_profile_provider.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int _step = 0;
  AssetRange? _assetRange;
  final Set<FinancialGoal> _goals = {};
  RiskReaction? _riskReaction;

  bool get _canNext => switch (_step) {
        0 => _assetRange != null,
        1 => _goals.isNotEmpty,
        2 => _riskReaction != null,
        _ => false,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildProgress(),
            Expanded(child: SingleChildScrollView(child: _buildStep())),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.psychology, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '让明理了解你',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: _skip,
            child: const Text(
              '跳过',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: List.generate(3, (i) {
          final active = i <= _step;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: switch (_step) {
        0 => _AssetRangeStep(
            selected: _assetRange,
            onChanged: (v) => setState(() => _assetRange = v),
          ),
        1 => _GoalStep(
            selected: _goals,
            onChanged: (v) => setState(() {
              if (_goals.contains(v)) {
                _goals.remove(v);
              } else if (_goals.length < 2) {
                _goals.add(v);
              }
            }),
          ),
        2 => _RiskStep(
            selected: _riskReaction,
            onChanged: (v) => setState(() => _riskReaction = v),
          ),
        _ => const SizedBox(),
      },
    );
  }

  Widget _buildBottomBar() {
    final isLast = _step == 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _canNext ? _onNext : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.border,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            isLast ? '开始对话' : '下一步',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  void _onNext() {
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _complete();
    }
  }

  Future<void> _complete() async {
    final profile = UserProfile(
      assetRange: _assetRange!,
      goals: _goals.toList(),
      riskReaction: _riskReaction!,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await ref.read(userProfileNotifierProvider.notifier).save(profile);
    if (mounted) context.go('/chat');
  }

  Future<void> _skip() async {
    await ref.read(userProfileNotifierProvider.notifier).markSkipped();
    if (mounted) context.go('/chat');
  }
}

// ── Step 1：资产量级 ─────────────────────────────────────────────
class _AssetRangeStep extends StatelessWidget {
  final AssetRange? selected;
  final ValueChanged<AssetRange> onChanged;

  const _AssetRangeStep({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '你目前有多少可以投资的钱？',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '帮我给出合适的产品门槛建议',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        ...AssetRange.values.map((r) => _OptionTile(
              label: r.label,
              selected: selected == r,
              onTap: () => onChanged(r),
            )),
      ],
    );
  }
}

// ── Step 2：核心目标 ─────────────────────────────────────────────
class _GoalStep extends StatelessWidget {
  final Set<FinancialGoal> selected;
  final ValueChanged<FinancialGoal> onChanged;

  const _GoalStep({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '你最主要的理财目标是？',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '最多选2个',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        ...FinancialGoal.values.map((g) => _OptionTile(
              label: g.label,
              selected: selected.contains(g),
              multiSelect: true,
              disabled: !selected.contains(g) && selected.length >= 2,
              onTap: () => onChanged(g),
            )),
      ],
    );
  }
}

// ── Step 3：风险偏好 ─────────────────────────────────────────────
class _RiskStep extends StatelessWidget {
  final RiskReaction? selected;
  final ValueChanged<RiskReaction> onChanged;

  const _RiskStep({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const scenarios = [
      '立刻止损卖出，睡不着觉',
      '有点担心，但观望不动',
      '正常，长期持有不在意',
      '加仓，这是买入机会',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '去年A股大跌20%，你会怎么做？',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '这个问题帮我判断你的真实风险承受能力',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        ...RiskReaction.values.mapIndexed((i, r) => _OptionTile(
              label: scenarios[i],
              sublabel: r.label,
              selected: selected == r,
              onTap: () => onChanged(r),
            )),
      ],
    );
  }
}

// ── 通用选项 tile ────────────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  final String label;
  final String? sublabel;
  final bool selected;
  final bool multiSelect;
  final bool disabled;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.sublabel,
    this.multiSelect = false,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: multiSelect ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: multiSelect ? BorderRadius.circular(4) : null,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.textHint,
                  width: 1.5,
                ),
                color: selected ? AppColors.primary : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                      color: disabled
                          ? AppColors.textHint
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (sublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sublabel!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  Iterable<R> mapIndexed<R>(R Function(int index, T element) fn) sync* {
    var i = 0;
    for (final e in this) {
      yield fn(i++, e);
    }
  }
}
