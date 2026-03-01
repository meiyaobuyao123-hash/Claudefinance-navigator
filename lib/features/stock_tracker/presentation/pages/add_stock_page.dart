import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/stock_holding.dart';
import '../providers/stock_tracker_provider.dart';

class AddStockPage extends ConsumerStatefulWidget {
  const AddStockPage({super.key});

  @override
  ConsumerState<AddStockPage> createState() => _AddStockPageState();
}

class _AddStockPageState extends ConsumerState<AddStockPage> {
  // ── 市场选择 ──
  String _market = 'A'; // 'A' | 'HK' | 'US'

  // ── 表单 ──
  final _symbolCtrl = TextEditingController();
  final _sharesCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  // ── 状态 ──
  bool _isSearching = false;
  bool _isVerifying = false;
  bool _isSubmitting = false;
  StockHolding? _verified;        // 验证成功的股票信息
  List<Map<String, String>> _suggestions = [];
  String? _error;

  double get _shares => double.tryParse(_sharesCtrl.text) ?? 0;
  double get _price => double.tryParse(_priceCtrl.text) ?? 0;
  double get _totalCost => _shares * _price;
  bool get _canSubmit => _verified != null && _shares > 0 && _price > 0;

  @override
  void dispose() {
    _symbolCtrl.dispose();
    _sharesCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  // ── 搜索建议 ──
  Future<void> _onSearchChanged(String value) async {
    if (value.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _isSearching = true);
    final results =
        await ref.read(stockApiServiceProvider).searchStock(value, _market);
    if (mounted) setState(() { _suggestions = results; _isSearching = false; });
  }

  // ── 验证代码 ──
  Future<void> _verify(String symbol) async {
    setState(() {
      _isVerifying = true;
      _error = null;
      _verified = null;
      _suggestions = [];
    });
    final info =
        await ref.read(stockApiServiceProvider).fetchStockInfo(symbol, _market);
    if (!mounted) return;
    if (info == null) {
      setState(() {
        _error = '找不到该股票，请确认代码和市场是否正确';
        _isVerifying = false;
      });
      return;
    }
    setState(() {
      _verified = info;
      _isVerifying = false;
      _symbolCtrl.text = symbol;
      // 自动填充当前价作为成本价
      _priceCtrl.text = info.currentPrice.toStringAsFixed(
          _market == 'A' ? 2 : (_market == 'HK' ? 3 : 2));
    });
  }

  // ── 提交 ──
  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);
    final holding = StockHolding(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      symbol: _verified!.symbol,
      stockName: _verified!.stockName,
      market: _market,
      shares: _shares,
      costPrice: _price,
      addedDate: DateTime.now().toIso8601String().substring(0, 10),
      currentPrice: _verified!.currentPrice,
      changeRate: _verified!.changeRate,
      changeAmount: _verified!.changeAmount,
    );
    await ref.read(stockHoldingsProvider.notifier).addHolding(holding);
    if (mounted) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加 ${holding.stockName}')),
      );
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
        title: const Text('添加股票'),
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

              // ── 股票代码搜索 ──
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
              const SizedBox(height: 20),

              // ── 持仓数量 ──
              _buildLabel('持仓股数'),
              const SizedBox(height: 8),
              TextField(
                controller: _sharesCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: _market == 'US' ? '可输入小数（如 10.5）' : '整数股数',
                  suffixText: '股',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),

              // ── 成本价 ──
              _buildLabel('买入成本价'),
              const SizedBox(height: 8),
              TextField(
                controller: _priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: '每股买入价格',
                  suffixText: _market == 'US' ? '美元/股' : (_market == 'HK' ? '港元/股' : '元/股'),
                ),
                onChanged: (_) => setState(() {}),
              ),

              // ── 成本预览 ──
              if (_canSubmit) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      const Text('总成本',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary)),
                      const Spacer(),
                      Text(
                        _market == 'US'
                            ? '\$${_totalCost.toStringAsFixed(2)}'
                            : (_market == 'HK'
                                ? 'HK\$${_totalCost.toStringAsFixed(2)}'
                                : '¥${_totalCost >= 10000 ? '${(_totalCost / 10000).toStringAsFixed(2)}万' : _totalCost.toStringAsFixed(2)}'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // ── 提交按钮 ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canSubmit && !_isSubmitting ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    disabledBackgroundColor: AppColors.border,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('确认添加',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 市场选择器 ──
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

  // ── 代码输入框 ──
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
                  : (_market == 'HK' ? '如 00700 或 02800' : '如 AAPL 或 VOO'),
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
          onPressed: _isVerifying
              ? null
              : () => _verify(_symbolCtrl.text.trim()),
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

  // ── 搜索建议下拉 ──
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

  // ── 验证成功卡片 ──
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
                    ? v.currentPrice.toStringAsFixed(
                        _market == 'HK' ? 3 : 2)
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
