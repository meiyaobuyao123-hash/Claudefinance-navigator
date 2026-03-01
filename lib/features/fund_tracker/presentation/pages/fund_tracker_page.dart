import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/fund_holding.dart';
import '../providers/fund_tracker_provider.dart';
import '../widgets/portfolio_chart.dart';
import '../../../stock_tracker/data/models/stock_holding.dart';
import '../../../stock_tracker/presentation/providers/stock_tracker_provider.dart';

// ─────────────────────────────────────────────
// 主页面
// ─────────────────────────────────────────────
class FundTrackerPage extends ConsumerStatefulWidget {
  const FundTrackerPage({super.key});

  @override
  ConsumerState<FundTrackerPage> createState() => _FundTrackerPageState();
}

class _FundTrackerPageState extends ConsumerState<FundTrackerPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await ref.read(fundHoldingsProvider.notifier).refreshAll();
    await ref.read(stockHoldingsProvider.notifier).refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(portfolioSummaryProvider);
    final funds = ref.watch(fundHoldingsProvider);
    final stocks = ref.watch(stockHoldingsProvider);
    final hasAny = funds.isNotEmpty || stocks.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/tools'),
        ),
        title: const Text('持仓总览'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 22),
            onPressed: () => context.push('/fund-tracker/alert-settings'),
            tooltip: '收益预警',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined, size: 22),
            onPressed: _refreshAll,
            tooltip: '刷新行情',
          ),
        ],
      ),
      body: hasAny
          ? RefreshIndicator(
              onRefresh: _refreshAll,
              color: AppColors.primary,
              child: NestedScrollView(
                headerSliverBuilder: (ctx, _) => [
                  SliverToBoxAdapter(
                    child: _buildSummaryCard(summary, funds),
                  ),
                  SliverToBoxAdapter(
                    child: Consumer(
                      builder: (ctx, r, _) {
                        final snaps = r.watch(portfolioSnapshotsProvider);
                        if (snaps.length < 2) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('近30日走势',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary)),
                                    const Spacer(),
                                    Text('${snaps.length}天',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textHint)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                PortfolioChart(values: snaps),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarDelegate(
                      TabBar(
                        controller: _tab,
                        tabs: const [
                          Tab(text: '基金'),
                          Tab(text: 'A股'),
                          Tab(text: '港股'),
                          Tab(text: '美股'),
                        ],
                        labelColor: AppColors.primary,
                        unselectedLabelColor: AppColors.textSecondary,
                        indicatorColor: AppColors.primary,
                        indicatorSize: TabBarIndicatorSize.label,
                        labelStyle: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tab,
                  children: [
                    _FundList(holdings: funds),
                    _StockList(
                        stocks:
                            stocks.where((s) => s.market == 'A').toList()),
                    _StockList(
                        stocks:
                            stocks.where((s) => s.market == 'HK').toList()),
                    _StockList(
                        stocks:
                            stocks.where((s) => s.market == 'US').toList()),
                  ],
                ),
              ),
            )
          : _buildEmptyState(context),
      floatingActionButton: hasAny
          ? ListenableBuilder(
              listenable: _tab,
              builder: (_, __) => FloatingActionButton(
                onPressed: () {
                  if (_tab.index == 0) {
                    context.push('/fund-tracker/add');
                  } else {
                    context.push('/fund-tracker/add-stock');
                  }
                },
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildSummaryCard(
      Map<String, double> summary, List<FundHolding> funds) {
    final totalReturn = summary['totalReturn'] ?? 0;
    final returnRate = summary['totalReturnRate'] ?? 0;
    final todayGain = summary['todayGain'] ?? 0;
    final isProfit = totalReturn >= 0;
    final returnColor = isProfit ? AppColors.error : AppColors.success;
    final anyHasEstimate = funds.any((h) => h.hasEstimate);

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
          const Text('总市值（元）',
              style: TextStyle(fontSize: 13, color: Colors.white70)),
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
                  sub:
                      '${isProfit ? '+' : ''}${returnRate.toStringAsFixed(2)}%',
                  valueColor: returnColor,
                ),
              ),
              Container(width: 1, height: 36, color: Colors.white24),
              Expanded(
                child: anyHasEstimate
                    ? _SummaryItem(
                        label: '今日盈亏',
                        value:
                            '${todayGain >= 0 ? '+' : ''}${_fmt(todayGain)}',
                        sub: todayGain >= 0 ? '▲ 盈利' : '▼ 亏损',
                        valueColor: todayGain >= 0
                            ? AppColors.error
                            : AppColors.success,
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
          const Text('还没有持仓',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            '添加基金或股票\n即可实时监控收益',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => context.push('/fund-tracker/add'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加基金'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => context.push('/fund-tracker/add-stock'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加股票'),
              ),
            ],
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

// ─────────────────────────────────────────────
// 固定 TabBar Delegate
// ─────────────────────────────────────────────
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height + 1;
  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          tabBar,
          const Divider(height: 1, color: AppColors.border),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) => tabBar != old.tabBar;
}

// ─────────────────────────────────────────────
// 基金 Tab
// ─────────────────────────────────────────────
class _FundList extends ConsumerWidget {
  final List<FundHolding> holdings;
  const _FundList({required this.holdings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (holdings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart, size: 48, color: AppColors.textHint),
            const SizedBox(height: 16),
            const Text('还没有基金持仓',
                style: TextStyle(
                    fontSize: 16, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.push('/fund-tracker/add'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加基金'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 32),
      itemCount: holdings.length,
      itemBuilder: (ctx, i) => _FundCard(holding: holdings[i]),
    );
  }
}

// ─────────────────────────────────────────────
// 股票 Tab
// ─────────────────────────────────────────────
class _StockList extends ConsumerWidget {
  final List<StockHolding> stocks;
  const _StockList({required this.stocks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (stocks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.show_chart, size: 48, color: AppColors.textHint),
            const SizedBox(height: 16),
            const Text('还没有股票持仓',
                style: TextStyle(
                    fontSize: 16, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.push('/fund-tracker/add-stock'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加股票'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 32),
      itemCount: stocks.length,
      itemBuilder: (ctx, i) => _StockCard(holding: stocks[i]),
    );
  }
}

// ─────────────────────────────────────────────
// 汇总子项
// ─────────────────────────────────────────────
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
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: valueColor)),
          Text(sub,
              style: const TextStyle(fontSize: 11, color: Colors.white60)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 基金持仓卡片
// ─────────────────────────────────────────────
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
                            Text(holding.fundCode,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textHint)),
                          ],
                        ),
                      ),
                      if (holding.isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
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
                                fontSize: 12,
                                color: AppColors.textHint)),
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
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
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
                            Text(holding.fundName,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(
                                '${holding.fundCode} · 持有 ${holding.shares.toStringAsFixed(2)} 份',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textHint)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
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
              ref
                  .read(fundHoldingsProvider.notifier)
                  .removeHolding(holding.id);
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

// ─────────────────────────────────────────────
// 数据格子
// ─────────────────────────────────────────────
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
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textHint)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: primary ? 14 : 13,
              fontWeight:
                  primary ? FontWeight.w700 : FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 股票持仓卡片
// ─────────────────────────────────────────────
class _StockCard extends ConsumerWidget {
  final StockHolding holding;
  const _StockCard({required this.holding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = holding;
    final hasData = h.currentPrice > 0;
    final isUp = h.changeRate >= 0;
    final changeColor = isUp ? AppColors.error : AppColors.success;

    final marketColor = h.market == 'A'
        ? AppColors.error
        : h.market == 'HK'
            ? const Color(0xFF007AFF)
            : const Color(0xFF34C759);
    final marketLabel =
        h.market == 'A' ? 'A股' : (h.market == 'HK' ? '港股' : '美股');
    final currency =
        h.market == 'US' ? '\$' : (h.market == 'HK' ? 'HK\$' : '¥');
    final priceDecimals = h.market == 'HK' ? 3 : 2;

    return Dismissible(
      key: Key(h.id),
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
            content: Text('确定删除 ${h.stockName}？'),
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
        ref.read(stockHoldingsProvider.notifier).removeHolding(h.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除 ${h.stockName}')),
        );
      },
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
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    h.stockName,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: marketColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    marketLabel,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: marketColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(h.symbol,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textHint)),
                          ],
                        ),
                      ),
                      if (h.isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (hasData) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$currency${h.currentPrice.toStringAsFixed(priceDecimals)}',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: changeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${isUp ? '+' : ''}${h.changeRate.toStringAsFixed(2)}%',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: changeColor),
                              ),
                            ),
                          ],
                        ),
                      ] else if (h.errorMsg != null)
                        Text(h.errorMsg!,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textHint)),
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
                            value: _fmtV(h.currentValue, currency),
                            primary: true),
                        _DataCell(
                            label: '累计收益',
                            value:
                                '${h.totalReturn >= 0 ? '+' : ''}${_fmtV(h.totalReturn, currency)}',
                            color: h.totalReturn >= 0
                                ? AppColors.error
                                : AppColors.success),
                        _DataCell(
                            label: '收益率',
                            value:
                                '${h.totalReturnRate >= 0 ? '+' : ''}${h.totalReturnRate.toStringAsFixed(2)}%',
                            color: h.totalReturnRate >= 0
                                ? AppColors.error
                                : AppColors.success),
                        _DataCell(
                            label: '今日盈亏',
                            value:
                                '${h.todayGain >= 0 ? '+' : ''}${_fmtV(h.todayGain, currency)}',
                            color: h.todayGain >= 0
                                ? AppColors.error
                                : AppColors.success),
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

  void _showOptions(BuildContext context, WidgetRef ref) {
    final h = holding;
    final shareDecimals = h.market == 'A' ? 0 : 2;
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
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.show_chart,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(h.stockName,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(
                                '${h.symbol} · 持有 ${h.shares.toStringAsFixed(shareDecimals)} 股',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textHint)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
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
                  title: const Text('增持',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500)),
                  subtitle: const Text('买入更多股票，自动摊薄成本'),
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
                          builder: (_) => _AddStockSheet(holding: h),
                        );
                      }
                    });
                  },
                ),
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
                  subtitle: const Text('记录卖出股数，显示已实现盈亏'),
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
                          builder: (_) => _ReduceStockSheet(holding: h),
                        );
                      }
                    });
                  },
                ),
                const Divider(height: 1),
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
                  subtitle: const Text('移除该股票的所有监控数据'),
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
        content: Text('确定删除「${holding.stockName}」？\n删除后数据将无法恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(stockHoldingsProvider.notifier)
                  .removeHolding(holding.id);
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已删除 ${holding.stockName}')));
            },
            child: const Text('删除',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  static String _fmtV(double v, String currency) {
    if (v.abs() >= 10000 && currency == '¥') {
      return '$currency${(v / 10000).toStringAsFixed(2)}万';
    }
    return '$currency${v.toStringAsFixed(2)}';
  }
}

// ════════════════════════════════════════════════════
// 基金减持 BottomSheet
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
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    padding: EdgeInsets.only(left: 20, right: 20, top: 6),
                    child: Text(
                      '⚠️ 减持后将自动清除该持仓记录',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textHint),
                    ),
                  ),
              ],
              const SizedBox(height: 20),
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
// 基金加仓 BottomSheet
// ════════════════════════════════════════════════════
class _AddPositionSheet extends ConsumerStatefulWidget {
  final FundHolding holding;
  const _AddPositionSheet({required this.holding});

  @override
  ConsumerState<_AddPositionSheet> createState() => _AddPositionSheetState();
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

// ════════════════════════════════════════════════════
// 股票增持 BottomSheet
// ════════════════════════════════════════════════════
class _AddStockSheet extends ConsumerStatefulWidget {
  final StockHolding holding;
  const _AddStockSheet({required this.holding});

  @override
  ConsumerState<_AddStockSheet> createState() => _AddStockSheetState();
}

class _AddStockSheetState extends ConsumerState<_AddStockSheet> {
  final _sharesCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  double _addShares = 0;
  double _addPrice = 0;

  StockHolding get h => widget.holding;
  double get _newTotalShares => h.shares + _addShares;
  double get _newAvgCost => (_addShares > 0 && _addPrice > 0)
      ? (h.shares * h.costPrice + _addShares * _addPrice) / _newTotalShares
      : h.costPrice;
  bool get _isValid => _addShares > 0 && _addPrice > 0;

  @override
  void dispose() {
    _sharesCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency =
        h.market == 'US' ? '\$' : (h.market == 'HK' ? 'HK\$' : '¥');
    final shareDecimals = h.market == 'A' ? 0 : 2;

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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('增持',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text(h.stockName,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(height: 14),
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
                        label: '当前股数',
                        value:
                            '${h.shares.toStringAsFixed(shareDecimals)}股'),
                    _SheetInfoCell(
                        label: '均价',
                        value:
                            '$currency${h.costPrice.toStringAsFixed(2)}'),
                    _SheetInfoCell(
                        label: '持仓市值',
                        value: h.currentValue > 0
                            ? '$currency${h.currentValue.toStringAsFixed(0)}'
                            : '--'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('增持股数',
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
                      decoration: InputDecoration(
                        hintText: h.market == 'US'
                            ? '可输入小数（如 10.5）'
                            : '本次买入股数',
                        suffixText: '股',
                      ),
                      onChanged: (v) => setState(
                          () => _addShares = double.tryParse(v) ?? 0),
                    ),
                    const SizedBox(height: 12),
                    const Text('买入价格',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        hintText: '本次买入成本价',
                        suffixText: '${currency}每股',
                      ),
                      onChanged: (v) => setState(
                          () => _addPrice = double.tryParse(v) ?? 0),
                    ),
                  ],
                ),
              ),
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
                          label: '本次增持金额',
                          value:
                              '$currency${(_addShares * _addPrice).toStringAsFixed(2)}'),
                      const SizedBox(height: 8),
                      _SheetResultRow(
                          label: '增持后总股数',
                          value:
                              '${_newTotalShares.toStringAsFixed(shareDecimals)} 股'),
                      const SizedBox(height: 8),
                      _SheetResultRow(
                        label: '摊薄后均价',
                        value:
                            '$currency${_newAvgCost.toStringAsFixed(2)}',
                        valueColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
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
                    child: const Text('确认增持',
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
    final currency =
        h.market == 'US' ? '\$' : (h.market == 'HK' ? 'HK\$' : '¥');
    Navigator.pop(context);
    ref.read(stockHoldingsProvider.notifier).updateHolding(
          h.id,
          newShares: _newTotalShares,
          newCostPrice: _newAvgCost,
        );
    messenger.showSnackBar(SnackBar(
        content: Text(
            '增持成功  新均价 $currency${_newAvgCost.toStringAsFixed(2)}/股')));
  }
}

// ════════════════════════════════════════════════════
// 股票减持 BottomSheet
// ════════════════════════════════════════════════════
class _ReduceStockSheet extends ConsumerStatefulWidget {
  final StockHolding holding;
  const _ReduceStockSheet({required this.holding});

  @override
  ConsumerState<_ReduceStockSheet> createState() =>
      _ReduceStockSheetState();
}

class _ReduceStockSheetState extends ConsumerState<_ReduceStockSheet> {
  final _ctrl = TextEditingController();
  double _soldShares = 0;

  StockHolding get h => widget.holding;
  double get _price => h.currentPrice > 0 ? h.currentPrice : h.costPrice;
  double get _remaining => h.shares - _soldShares;
  double get _saleAmount => _soldShares * _price;
  double get _realizedPnl => _soldShares * (_price - h.costPrice);
  bool get _isValid => _soldShares > 0 && _soldShares <= h.shares;
  bool get _isFullExit => _remaining <= 0.0001;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency =
        h.market == 'US' ? '\$' : (h.market == 'HK' ? 'HK\$' : '¥');
    final shareDecimals = h.market == 'A' ? 0 : 2;

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
                    Text(h.stockName,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(height: 14),
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
                        label: '持仓股数',
                        value:
                            '${h.shares.toStringAsFixed(shareDecimals)}股'),
                    _SheetInfoCell(
                        label: '成本价',
                        value:
                            '$currency${h.costPrice.toStringAsFixed(2)}'),
                    _SheetInfoCell(
                        label: h.currentPrice > 0 ? '当前价格' : '价格',
                        value: h.currentPrice > 0
                            ? '$currency${h.currentPrice.toStringAsFixed(2)}'
                            : '--'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('卖出股数',
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
                        hintText:
                            '最多 ${h.shares.toStringAsFixed(shareDecimals)} 股',
                        suffixText: '股',
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
                          value:
                              '$currency${_saleAmount.toStringAsFixed(2)}'),
                      const SizedBox(height: 8),
                      _SheetResultRow(
                        label: '已实现盈亏',
                        value:
                            '${_realizedPnl >= 0 ? '+' : ''}$currency${_realizedPnl.toStringAsFixed(2)}',
                        valueColor: _realizedPnl >= 0
                            ? AppColors.error
                            : AppColors.success,
                      ),
                      const SizedBox(height: 8),
                      _SheetResultRow(
                        label: '减持后剩余',
                        value: _isFullExit
                            ? '0 股（清仓）'
                            : '${_remaining.toStringAsFixed(shareDecimals)} 股',
                        valueColor:
                            _isFullExit ? AppColors.textHint : null,
                      ),
                    ],
                  ),
                ),
                if (_isFullExit)
                  const Padding(
                    padding: EdgeInsets.only(left: 20, right: 20, top: 6),
                    child: Text(
                      '⚠️ 减持后将自动清除该持仓记录',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textHint),
                    ),
                  ),
              ],
              const SizedBox(height: 20),
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
    final currency =
        h.market == 'US' ? '\$' : (h.market == 'HK' ? 'HK\$' : '¥');
    final shareDecimals = h.market == 'A' ? 0 : 2;
    Navigator.pop(context);
    if (_isFullExit) {
      ref.read(stockHoldingsProvider.notifier).removeHolding(h.id);
      messenger.showSnackBar(SnackBar(
          content: Text(
              '${h.stockName} 已清仓  盈亏 ${_realizedPnl >= 0 ? '+' : ''}$currency${_realizedPnl.toStringAsFixed(2)}')));
    } else {
      ref.read(stockHoldingsProvider.notifier).updateHolding(
            h.id,
            newShares: _remaining,
            newCostPrice: h.costPrice,
          );
      messenger.showSnackBar(SnackBar(
          content: Text(
              '减持成功，剩余 ${_remaining.toStringAsFixed(shareDecimals)} 股')));
    }
  }
}

// ─────────────────────────────────────────────
// Sheet 辅助 widget
// ─────────────────────────────────────────────
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
