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
                  SliverToBoxAdapter(child: _buildSummaryCard(summary, holdings)),
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
  Widget _buildSummaryCard(Map<String, double> summary, List<FundHolding> holdings) {
    final totalReturn = summary['totalReturn'] ?? 0;
    final returnRate = summary['totalReturnRate'] ?? 0;
    final todayGain = summary['todayGain'] ?? 0;
    final isProfit = totalReturn >= 0;
    final returnColor = isProfit ? AppColors.error : AppColors.success; // 红涨绿跌（A股习惯）
    // 是否所有持仓今日都没有盘中估值
    final anyHasEstimate = holdings.any((h) => h.hasEstimate);

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
                child: anyHasEstimate
                    ? _SummaryItem(
                        label: '今日盈亏',
                        value: '${todayGain >= 0 ? '+' : ''}${_fmt(todayGain)}',
                        sub: todayGain >= 0 ? '▲ 盈利' : '▼ 亏损',
                        valueColor:
                            todayGain >= 0 ? AppColors.error : AppColors.success,
                      )
                    : const _SummaryItem(
                        label: '今日盈亏',
                        value: '-- --',
                        sub: '暂无估值',
                        valueColor: Colors.white54,
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
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 24),
            SizedBox(height: 2),
            Text('删除', style: TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
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
                  child: const Text('删除',
                      style: TextStyle(color: AppColors.error))),
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
      // ── 卡片内容：点击打开操作菜单 ──
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => _showOptions(context, ref),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                                color: holding.hasEstimate
                                    ? changeColor.withOpacity(0.1)
                                    : AppColors.textHint.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                holding.hasEstimate
                                    ? '${isUp ? '+' : ''}${changeRate.toStringAsFixed(2)}%'
                                    : '未开盘',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: holding.hasEstimate
                                        ? changeColor
                                        : AppColors.textHint),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '净值 ${holding.currentNav.toStringAsFixed(4)}',
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
                            value: holding.hasEstimate
                                ? '${holding.todayGain >= 0 ? '+' : ''}${_fmtV(holding.todayGain)}'
                                : '--',
                            color: holding.hasEstimate
                                ? (holding.todayGain >= 0
                                    ? AppColors.error
                                    : AppColors.success)
                                : AppColors.textHint),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── 点击卡片弹出操作菜单 ───
  void _showOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拖拽条
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 基金信息头
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.bar_chart,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
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
                            Text(
                              '${holding.fundCode} · 持有 ${holding.shares.toStringAsFixed(2)} 份',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textHint),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // ── 加仓 ──
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add,
                        color: AppColors.primary, size: 20),
                  ),
                  title: const Text('加仓',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500)),
                  subtitle: const Text('买入更多份额，自动摊薄成本'),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.textHint),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Future.delayed(const Duration(milliseconds: 200), () {
                      if (context.mounted) {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) =>
                              _AddPositionSheet(holding: holding),
                        );
                      }
                    });
                  },
                ),
                // ── 减持 ──
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.remove,
                        color: AppColors.warning, size: 20),
                  ),
                  title: const Text('减持（卖出）',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500)),
                  subtitle: const Text('记录卖出份额，显示已实现盈亏'),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.textHint),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Future.delayed(const Duration(milliseconds: 200), () {
                      if (context.mounted) {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => _ReduceSheet(holding: holding),
                        );
                      }
                    });
                  },
                ),
                const Divider(height: 1),
                // ── 删除 ──
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline,
                        color: AppColors.error, size: 20),
                  ),
                  title: const Text('删除持仓',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.error)),
                  subtitle: const Text('移除该基金的所有监控数据'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _confirmDelete(context, ref);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除持仓'),
        content: Text('确定删除「${holding.fundName}」？\n删除后数据将无法恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(fundHoldingsProvider.notifier).removeHolding(holding.id);
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已删除 ${holding.fundName}')));
            },
            child: const Text('删除',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
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

// ════════════════════════════════════════════════════
// ─── 减持 BottomSheet ───
// ════════════════════════════════════════════════════
class _ReduceSheet extends ConsumerStatefulWidget {
  final FundHolding holding;
  const _ReduceSheet({required this.holding});

  @override
  ConsumerState<_ReduceSheet> createState() => _ReduceSheetState();
}

class _ReduceSheetState extends ConsumerState<_ReduceSheet> {
  final _ctrl = TextEditingController();
  double _soldShares = 0;

  FundHolding get h => widget.holding;
  // 优先用估值，降级用净值
  double get _nav =>
      (h.hasEstimate && h.estimatedNav > 0) ? h.estimatedNav : h.currentNav;
  double get _remaining => h.shares - _soldShares;
  double get _saleAmount => _soldShares * (_nav > 0 ? _nav : h.costNav);
  double get _realizedPnl =>
      _soldShares * ((_nav > 0 ? _nav : h.costNav) - h.costNav);
  bool get _isValid => _soldShares > 0 && _soldShares <= h.shares;
  bool get _isFullExit => _remaining <= 0.001;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 拖拽条
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
              // 标题
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('减持',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text(h.fundName,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // 当前持仓信息条
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _SheetInfoCell(
                        label: '持仓份额',
                        value: '${h.shares.toStringAsFixed(2)}份'),
                    _SheetInfoCell(
                        label: '成本净值',
                        value: h.costNav.toStringAsFixed(4)),
                    _SheetInfoCell(
                        label: _nav > 0
                            ? (h.hasEstimate ? '今日估值' : '最新净值')
                            : '净值',
                        value: _nav > 0 ? _nav.toStringAsFixed(4) : '--'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // 输入框
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('卖出份额',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _ctrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        hintText: '最多 ${h.shares.toStringAsFixed(2)} 份',
                        suffixText: '份',
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.warning, width: 1.5),
                        ),
                      ),
                      onChanged: (v) => setState(
                          () => _soldShares = double.tryParse(v) ?? 0),
                    ),
                  ],
                ),
              ),
              // 实时计算结果
              if (_isValid) ...[
                const SizedBox(height: 14),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _realizedPnl >= 0
                        ? AppColors.success.withOpacity(0.06)
                        : AppColors.error.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _realizedPnl >= 0
                          ? AppColors.success.withOpacity(0.25)
                          : AppColors.error.withOpacity(0.25),
                    ),
                  ),
                  child: Column(
                    children: [
                      _SheetResultRow(
                          label: '预计卖出金额',
                          value: '¥${_saleAmount.toStringAsFixed(2)}'),
                      const SizedBox(height: 8),
                      _SheetResultRow(
                        label: '已实现盈亏',
                        value:
                            '${_realizedPnl >= 0 ? '+' : ''}¥${_realizedPnl.toStringAsFixed(2)}',
                        valueColor: _realizedPnl >= 0
                            ? AppColors.error
                            : AppColors.success,
                      ),
                      const SizedBox(height: 8),
                      _SheetResultRow(
                        label: '减持后剩余',
                        value: _isFullExit
                            ? '0 份（清仓）'
                            : '${_remaining.toStringAsFixed(2)} 份',
                        valueColor:
                            _isFullExit ? AppColors.textHint : null,
                      ),
                    ],
                  ),
                ),
                if (_isFullExit)
                  const Padding(
                    padding:
                        EdgeInsets.only(left: 20, right: 20, top: 6),
                    child: Text(
                      '⚠️ 减持后将自动清除该持仓记录',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textHint),
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              // 确认按钮
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isValid ? _confirm : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      disabledBackgroundColor: AppColors.border,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      _isFullExit ? '确认清仓' : '确认减持',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirm() {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    if (_isFullExit) {
      ref.read(fundHoldingsProvider.notifier).removeHolding(h.id);
      messenger.showSnackBar(SnackBar(
          content: Text(
              '${h.fundName} 已清仓  盈亏 ${_realizedPnl >= 0 ? '+' : ''}¥${_realizedPnl.toStringAsFixed(2)}')));
    } else {
      ref
          .read(fundHoldingsProvider.notifier)
          .updateHolding(h.id,
              newShares: _remaining, newCostNav: h.costNav);
      messenger.showSnackBar(SnackBar(
          content:
              Text('减持成功，剩余 ${_remaining.toStringAsFixed(2)} 份')));
    }
  }
}

// ════════════════════════════════════════════════════
// ─── 加仓 BottomSheet ───
// ════════════════════════════════════════════════════
class _AddPositionSheet extends ConsumerStatefulWidget {
  final FundHolding holding;
  const _AddPositionSheet({required this.holding});

  @override
  ConsumerState<_AddPositionSheet> createState() =>
      _AddPositionSheetState();
}

class _AddPositionSheetState extends ConsumerState<_AddPositionSheet> {
  final _sharesCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  double _addShares = 0;
  double _addPrice = 0;

  FundHolding get h => widget.holding;
  double get _newTotalShares => h.shares + _addShares;
  double get _newAvgCost => (_addShares > 0 && _addPrice > 0)
      ? (h.shares * h.costNav + _addShares * _addPrice) / _newTotalShares
      : h.costNav;
  bool get _isValid => _addShares > 0 && _addPrice > 0;

  @override
  void dispose() {
    _sharesCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 拖拽条
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
              // 标题
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('加仓',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text(h.fundName,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // 当前持仓信息条
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _SheetInfoCell(
                        label: '当前份额',
                        value: '${h.shares.toStringAsFixed(2)}份'),
                    _SheetInfoCell(
                        label: '当前均价',
                        value: h.costNav.toStringAsFixed(4)),
                    _SheetInfoCell(
                        label: '持仓市值',
                        value: h.currentValue > 0
                            ? '¥${h.currentValue.toStringAsFixed(0)}'
                            : '--'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // 输入区
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('加仓份额',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _sharesCtrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        hintText: '本次买入份额',
                        suffixText: '份',
                      ),
                      onChanged: (v) => setState(
                          () => _addShares = double.tryParse(v) ?? 0),
                    ),
                    const SizedBox(height: 12),
                    const Text('买入净值',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        hintText: '本次买入成本净值',
                        suffixText: '元/份',
                      ),
                      onChanged: (v) => setState(
                          () => _addPrice = double.tryParse(v) ?? 0),
                    ),
                  ],
                ),
              ),
              // 实时计算结果
              if (_isValid) ...[
                const SizedBox(height: 14),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.15)),
                  ),
                  child: Column(
                    children: [
                      _SheetResultRow(
                          label: '本次加仓金额',
                          value:
                              '¥${(_addShares * _addPrice).toStringAsFixed(2)}'),
                      const SizedBox(height: 8),
                      _SheetResultRow(
                          label: '加仓后总份额',
                          value:
                              '${_newTotalShares.toStringAsFixed(2)} 份'),
                      const SizedBox(height: 8),
                      _SheetResultRow(
                        label: '摊薄后均价',
                        value: _newAvgCost.toStringAsFixed(4),
                        valueColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              // 确认按钮
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isValid ? _confirm : null,
                    style: ElevatedButton.styleFrom(
                      disabledBackgroundColor: AppColors.border,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('确认加仓',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirm() {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    ref.read(fundHoldingsProvider.notifier).updateHolding(
          h.id,
          newShares: _newTotalShares,
          newCostNav: _newAvgCost,
        );
    messenger.showSnackBar(SnackBar(
        content: Text(
            '加仓成功  新均价 ${_newAvgCost.toStringAsFixed(4)} 元/份')));
  }
}

// ─── Sheet 辅助 widget：信息列 ───
class _SheetInfoCell extends StatelessWidget {
  final String label;
  final String value;
  const _SheetInfoCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textHint)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

// ─── Sheet 辅助 widget：计算结果行 ───
class _SheetResultRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _SheetResultRow(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary)),
      ],
    );
  }
}
