import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/fund_holding.dart';
import '../providers/fund_tracker_provider.dart';

class FundTrackerPage extends ConsumerWidget {
  const FundTrackerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdings = ref.watch(fundHoldingsProvider);
    final summary = ref.watch(portfolioSummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/tools'),
        ),
        title: const Text('基金组合'),
        actions: [
          // 刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh_outlined, size: 22),
            onPressed: () => ref.read(fundHoldingsProvider.notifier).refreshAll(),
            tooltip: '刷新行情',
          ),
          // 添加按钮
          IconButton(
            icon: const Icon(Icons.add, size: 24),
            onPressed: () => context.push('/fund-tracker/add'),
            tooltip: '添加基金',
          ),
        ],
      ),
      body: holdings.isEmpty
          ? _buildEmptyState(context)
          : RefreshIndicator(
              onRefresh: () => ref.read(fundHoldingsProvider.notifier).refreshAll(),
              color: AppColors.primary,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildSummaryCard(summary)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Text(
                        '持仓明细  ${holdings.length}只',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _FundCard(holding: holdings[index]),
                      childCount: holdings.length,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
      // 悬浮添加按钮（空状态时不显示，已在顶部）
      floatingActionButton: holdings.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => context.push('/fund-tracker/add'),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  // ─── 汇总卡片 ───
  Widget _buildSummaryCard(Map<String, double> summary) {
    final totalReturn = summary['totalReturn'] ?? 0;
    final returnRate = summary['totalReturnRate'] ?? 0;
    final todayGain = summary['todayGain'] ?? 0;
    final isProfit = totalReturn >= 0;
    final returnColor = isProfit ? AppColors.error : AppColors.success; // 红涨绿跌（A股习惯）

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '总市值（元）',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            _fmt(summary['totalValue'] ?? 0),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  label: '累计收益',
                  value: '${isProfit ? '+' : ''}${_fmt(totalReturn)}',
                  sub: '${isProfit ? '+' : ''}${returnRate.toStringAsFixed(2)}%',
                  valueColor: returnColor,
                ),
              ),
              Container(width: 1, height: 36, color: Colors.white24),
              Expanded(
                child: _SummaryItem(
                  label: '今日盈亏',
                  value: '${todayGain >= 0 ? '+' : ''}${_fmt(todayGain)}',
                  sub: todayGain >= 0 ? '▲ 盈利' : '▼ 亏损',
                  valueColor: todayGain >= 0 ? AppColors.error : AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 空状态 ───
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_outlined,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          const Text(
            '还没有持仓',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            '添加基金代码和持仓份额\n即可实时监控收益',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => context.push('/fund-tracker/add'),
            icon: const Icon(Icons.add),
            label: const Text('添加第一只基金'),
          ),
        ],
      ),
    );
  }

  static String _fmt(double v) {
    if (v.abs() >= 100000000) return '${(v / 100000000).toStringAsFixed(2)}亿';
    if (v.abs() >= 10000) return '${(v / 10000).toStringAsFixed(2)}万';
    return v.toStringAsFixed(2);
  }
}

// ─── 汇总子项 ───
class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color valueColor;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.sub,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: valueColor)),
          Text(sub, style: const TextStyle(fontSize: 11, color: Colors.white60)),
        ],
      ),
    );
  }
}

// ─── 单只基金卡片 ───
class _FundCard extends ConsumerWidget {
  final FundHolding holding;
  const _FundCard({required this.holding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasData = holding.currentNav > 0 || holding.estimatedNav > 0;
    final changeRate = holding.changeRate;
    final isUp = changeRate >= 0;
    final changeColor = isUp ? AppColors.error : AppColors.success;

    return Dismissible(
      key: Key(holding.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('删除持仓'),
            content: Text('确定删除 ${holding.fundName}？'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('删除', style: TextStyle(color: AppColors.error))),
            ],
          ),
        );
      },
      onDismissed: (_) {
        ref.read(fundHoldingsProvider.notifier).removeHolding(holding.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除 ${holding.fundName}')),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // 顶部：基金名 + 今日涨跌
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        holding.fundName,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        holding.fundCode,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textHint),
                      ),
                    ],
                  ),
                ),
                if (holding.isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (hasData) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: changeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${isUp ? '+' : ''}${changeRate.toStringAsFixed(2)}%',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: changeColor),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '估值 ${holding.estimatedNav > 0 ? holding.estimatedNav.toStringAsFixed(4) : holding.currentNav.toStringAsFixed(4)}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textHint),
                      ),
                    ],
                  ),
                ] else if (holding.errorMsg != null)
                  Text(holding.errorMsg!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textHint)),
              ],
            ),

            if (hasData) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              // 底部：持仓数据
              Row(
                children: [
                  _DataCell(
                      label: '持仓市值',
                      value: _fmtV(holding.currentValue),
                      primary: true),
                  _DataCell(
                      label: '累计收益',
                      value:
                          '${holding.totalReturn >= 0 ? '+' : ''}${_fmtV(holding.totalReturn)}',
                      color: holding.totalReturn >= 0
                          ? AppColors.error
                          : AppColors.success),
                  _DataCell(
                      label: '收益率',
                      value:
                          '${holding.totalReturnRate >= 0 ? '+' : ''}${holding.totalReturnRate.toStringAsFixed(2)}%',
                      color: holding.totalReturnRate >= 0
                          ? AppColors.error
                          : AppColors.success),
                  _DataCell(
                      label: '今日盈亏',
                      value:
                          '${holding.todayGain >= 0 ? '+' : ''}${_fmtV(holding.todayGain)}',
                      color: holding.todayGain >= 0
                          ? AppColors.error
                          : AppColors.success),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _fmtV(double v) {
    if (v.abs() >= 10000) return '${(v / 10000).toStringAsFixed(2)}万';
    return v.toStringAsFixed(2);
  }
}

class _DataCell extends StatelessWidget {
  final String label;
  final String value;
  final bool primary;
  final Color? color;

  const _DataCell({
    required this.label,
    required this.value,
    this.primary = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: primary ? 14 : 13,
              fontWeight: primary ? FontWeight.w700 : FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
