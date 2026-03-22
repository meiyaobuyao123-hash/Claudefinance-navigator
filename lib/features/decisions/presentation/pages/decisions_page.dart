import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/decision_record.dart';
import '../providers/decision_provider.dart';

class DecisionsPage extends ConsumerWidget {
  const DecisionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decisions = ref.watch(decisionRecordsProvider);
    final pending = decisions.where((r) => r.hasPendingReview).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('决策日记'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () => context.push('/decisions/add'),
          ),
        ],
      ),
      body: decisions.isEmpty
          ? _buildEmpty(context)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (pending > 0) _PendingBanner(count: pending),
                if (pending > 0) const SizedBox(height: 16),
                ...decisions.map((r) => _DecisionCard(record: r)),
              ],
            ),
      floatingActionButton: decisions.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => context.push('/decisions/add'),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildEmpty(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.history_edu_outlined, size: 64, color: AppColors.textHint),
        const SizedBox(height: 16),
        const Text('还没有记录任何决策', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        const Text(
          '记录每一次理财决策，\n3个月后 App 会告诉你判断是否正确',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textHint, height: 1.6),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => context.push('/decisions/add'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('记录第一条决策'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
        ),
      ],
    ),
  );
}

// ─── 待复盘提示横幅 ───
class _PendingBanner extends StatelessWidget {
  final int count;
  const _PendingBanner({required this.count});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8E1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFFFD54F)),
    ),
    child: Row(
      children: [
        const Icon(Icons.notifications_active_outlined, color: Color(0xFFF9A825), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '你有 $count 条决策可以复盘了',
            style: const TextStyle(fontSize: 14, color: Color(0xFF795548), fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

// ─── 单条决策卡片 ───
class _DecisionCard extends ConsumerWidget {
  final DecisionRecord record;
  const _DecisionCard({required this.record});

  Color get _verdictColor {
    switch (record.latestVerdict) {
      case 'correct': return AppColors.success;
      case 'incorrect': return AppColors.error;
      default: return AppColors.textHint;
    }
  }

  String get _verdictLabel {
    switch (record.latestVerdict) {
      case 'correct': return '✅ 判断正确';
      case 'incorrect': return '❌ 有待反思';
      default: return record.hasPendingReview ? '🔔 可以复盘了' : '⏳ 复盘中';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = record.nextCheckpointDue;
    final daysUntilNext = due != null
        ? due.difference(DateTime.now()).inDays
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                _TypeBadge(type: record.type),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    record.productCategory,
                    style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  _verdictLabel,
                  style: TextStyle(fontSize: 12, color: _verdictColor, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // ─── Amount + Date ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(
              children: [
                Text(
                  '¥${_formatAmount(record.amount)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Text(
                  _formatDate(record.createdAt),
                  style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ],
            ),
          ),

          // ─── Rationale ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.format_quote, size: 16, color: AppColors.textHint),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      record.rationale,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Latest Checkpoint ───
          if (record.checkpoints.isNotEmpty)
            _CheckpointCard(checkpoint: record.checkpoints.last),

          // ─── Run Review Button ───
          if (record.hasPendingReview)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(decisionRecordsProvider.notifier).runReview(record);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('复盘完成'), backgroundColor: AppColors.success),
                      );
                    }
                  },
                  icon: const Icon(Icons.replay, size: 16),
                  label: Text('立即复盘（${record.checkpoints.isEmpty ? '3个月' : record.checkpoints.length == 1 ? '6个月' : '1年'}节点）'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 14, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(
                    daysUntilNext != null && daysUntilNext > 0
                        ? '下次复盘：${daysUntilNext}天后'
                        : record.nextCheckpointDue == null
                            ? '全部复盘已完成'
                            : '今天可以复盘',
                    style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _confirmDelete(context, ref),
                    child: const Icon(Icons.delete_outline, size: 18, color: AppColors.textHint),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条决策记录？'),
        content: const Text('删除后无法恢复，历史复盘记录也会一并删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(decisionRecordsProvider.notifier).deleteDecision(record.id);
            },
            child: const Text('删除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}千万';
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(v >= 100000 ? 0 : 1)}万';
    return v.toStringAsFixed(0);
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ─── 复盘检查点展示 ───
class _CheckpointCard extends StatelessWidget {
  final DecisionCheckpoint checkpoint;
  const _CheckpointCard({required this.checkpoint});

  Color get _color {
    switch (checkpoint.verdict) {
      case 'correct': return AppColors.success;
      case 'incorrect': return AppColors.error;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${checkpoint.period}复盘',
                  style: TextStyle(fontSize: 11, color: _color, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              Text(
                '${checkpoint.date.year}-${checkpoint.date.month.toString().padLeft(2, '0')}-${checkpoint.date.day.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            checkpoint.judgement,
            style: TextStyle(fontSize: 13, color: _color, height: 1.5),
          ),
        ],
      ),
    ),
  );
}

// ─── 决策类型徽章 ───
class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  Color get _color {
    switch (type) {
      case DecisionType.buy: return AppColors.success;
      case DecisionType.sell: return AppColors.error;
      case DecisionType.rebalance: return AppColors.primary;
      case DecisionType.renew: return const Color(0xFF9C27B0);
      case DecisionType.pass_: return AppColors.textHint;
      default: return AppColors.textHint;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: _color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      DecisionType.label(type),
      style: TextStyle(fontSize: 11, color: _color, fontWeight: FontWeight.w600),
    ),
  );
}
