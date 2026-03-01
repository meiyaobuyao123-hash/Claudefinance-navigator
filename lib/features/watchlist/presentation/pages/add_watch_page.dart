import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../stock_tracker/data/models/stock_holding.dart';
import '../../../stock_tracker/presentation/providers/stock_tracker_provider.dart';
import '../../data/models/watch_item.dart';
import '../providers/watchlist_provider.dart';

/// 添加自选页（仅搜索+验证，无需输入份额/成本）
class AddWatchPage extends ConsumerStatefulWidget {
  const AddWatchPage({super.key});

  @override
  ConsumerState<AddWatchPage> createState() => _AddWatchPageState();
}

class _AddWatchPageState extends ConsumerState<AddWatchPage> {
  String _market = 'A';

  final _symbolCtrl = TextEditingController();

  bool _isSearching = false;
  bool _isVerifying = false;
  bool _isSubmitting = false;
  StockHolding? _verified;
  List<Map<String, String>> _suggestions = [];
  String? _error;

  @override
  void dispose() {
    _symbolCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String value) async {
    if (value.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _isSearching = true);
    final results =
        await ref.read(stockApiServiceProvider).searchStock(value, _market);
    if (mounted) {
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _verify(String symbol) async {
    final sym = symbol.trim();
    if (sym.isEmpty) return;
    setState(() {
      _isVerifying = true;
      _error = null;
      _verified = null;
      _suggestions = [];
    });
    final info =
        await ref.read(stockApiServiceProvider).fetchStockInfo(sym, _market);
    if (!mounted) return;
    if (info == null) {
      setState(() {
        _error = '找不到该股票，请确认代码和市场';
        _isVerifying = false;
      });
      return;
    }
    setState(() {
      _verified = info;
      _isVerifying = false;
      _symbolCtrl.text = info.symbol;
    });
  }

  Future<void> _submit() async {
    if (_verified == null) return;

    // 检查重复
    final existing = ref.read(watchlistProvider);
    if (existing.any((w) => w.symbol == _verified!.symbol)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('该股票已在自选列表中')));
      return;
    }

    setState(() => _isSubmitting = true);
    final item = WatchItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      symbol: _verified!.symbol,
      name: _verified!.stockName,
      market: _market,
      addedPrice: _verified!.currentPrice,
      addedDate: DateTime.now().toIso8601String().substring(0, 10),
    );

    await ref.read(watchlistProvider.notifier).addItem(item);

    if (mounted) {
      context.pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已添加 ${item.name} 到自选')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('添加自选'),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 市场选择 ──
              _buildMarketSelector(),
              const SizedBox(height: 24),

              // ── 代码搜索 ──
              _buildLabel('股票代码'),
              const SizedBox(height: 8),
              _buildSymbolInput(),
              if (_suggestions.isNotEmpty) _buildSuggestions(),

              // ── 验证结果 ──
              if (_verified != null) ...[
                const SizedBox(height: 12),
                _buildVerifiedCard(),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.error)),
              ],

              const SizedBox(height: 32),

              // ── 提交按钮 ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _verified != null && !_isSubmitting
                      ? _submit
                      : null,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.star_border, size: 20),
                  label: Text(_isSubmitting ? '添加中…' : '添加到自选'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    disabledBackgroundColor: AppColors.border,
                  ),
                ),
              ),

              const SizedBox(height: 12),
              const Text(
                '长按自选列表中的股票可设置价格提醒',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarketSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final entry in [
            ('A', 'A股'),
            ('HK', '港股'),
            ('US', '美股'),
          ])
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _market = entry.$1;
                  _verified = null;
                  _suggestions = [];
                  _error = null;
                  _symbolCtrl.clear();
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _market == entry.$1
                        ? AppColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    entry.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _market == entry.$1
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSymbolInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _symbolCtrl,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: _market == 'A'
                ? [FilteringTextInputFormatter.digitsOnly]
                : [],
            decoration: InputDecoration(
              hintText: _market == 'A'
                  ? '如 600519（上海）或 000001（深圳）'
                  : (_market == 'HK' ? '如 00700 或 02800' : '如 AAPL 或 SPY'),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : null,
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed:
              _isVerifying ? null : () => _verify(_symbolCtrl.text.trim()),
          style: ElevatedButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: _isVerifying
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('验证'),
        ),
      ],
    );
  }

  Widget _buildSuggestions() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: _suggestions
            .map((s) => ListTile(
                  dense: true,
                  title: Text(s['name'] ?? '',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text(s['symbol'] ?? '',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textHint)),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      size: 12, color: AppColors.textHint),
                  onTap: () {
                    _symbolCtrl.text = s['symbol'] ?? '';
                    _verify(s['symbol'] ?? '');
                  },
                ))
            .toList(),
      ),
    );
  }

  Widget _buildVerifiedCard() {
    final v = _verified!;
    final isUp = v.changeRate >= 0;
    final color = isUp ? AppColors.error : AppColors.success;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_circle_outline,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.stockName,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                Text(v.symbol,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textHint)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                v.currentPrice > 0
                    ? v.currentPrice
                        .toStringAsFixed(_market == 'HK' ? 3 : 2)
                    : '--',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${isUp ? '+' : ''}${v.changeRate.toStringAsFixed(2)}%',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
      );
}
