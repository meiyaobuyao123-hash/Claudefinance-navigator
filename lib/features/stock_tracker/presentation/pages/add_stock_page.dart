import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/stock_holding.dart';
import '../providers/stock_tracker_provider.dart';
import '../../../fund_tracker/data/services/voice_input_service.dart';
import '../../../fund_tracker/presentation/widgets/voice_input_button.dart';
import '../../../decisions/data/models/decision_record.dart';
import '../../../decisions/presentation/widgets/decision_prompt_sheet.dart';

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
      // 显示 API 规范化后的代码（如 sh600519），与持仓保持一致
      _symbolCtrl.text = info.symbol;
      // 自动填充当前价作为成本价
      _priceCtrl.text = info.currentPrice.toStringAsFixed(
          _market == 'A' ? 2 : (_market == 'HK' ? 3 : 2));
    });
  }

  // ── 语音识别结果处理 ──
  void _onVoiceResult(VoiceParseResult result) {
    // 填充市场
    if (result.market != null && ['A', 'HK', 'US'].contains(result.market)) {
      setState(() => _market = result.market!);
    }
    // 填充股数
    if (result.shares != null && result.shares! > 0) {
      _sharesCtrl.text = result.shares!.toStringAsFixed(_market == 'US' ? 2 : 0);
    }
    // 填充成本价
    if (result.costPrice != null && result.costPrice! > 0) {
      _priceCtrl.text = result.costPrice!.toStringAsFixed(2);
    }

    // 有代码 → 直接验证
    if (result.symbol != null && result.symbol!.isNotEmpty) {
      _symbolCtrl.text = result.symbol!;
      setState(() {});
      _verify(result.symbol!);
      return;
    }

    setState(() {});

    // 无代码但有名称 → 自动搜索，弹出候选确认
    final name = result.stockName ?? '';
    if (name.isNotEmpty) {
      _autoSearchAndConfirm(name);
    }
  }

  // ── 自动搜索股票并弹出确认弹窗 ──
  Future<void> _autoSearchAndConfirm(String name) async {
    setState(() => _isSearching = true);
    final results = await ref.read(stockApiServiceProvider).searchStock(name, _market);
    if (!mounted) return;
    setState(() => _isSearching = false);

    if (results.isEmpty) {
      // 无结果：直接填入名称到搜索框，让用户手动选
      _symbolCtrl.text = name;
      setState(() {});
      return;
    }

    // 弹出候选列表让用户确认
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _StockCandidateSheet(
        stockName: name,
        candidates: results.take(6).toList(),
        onSelect: (candidate) {
          _symbolCtrl.text = candidate['symbol'] ?? '';
          setState(() {});
          _verify(candidate['symbol'] ?? '');
        },
      ),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加 ${holding.stockName}')),
      );
      // 弹出决策记录提示（可跳过），关闭后返回
      final categoryForMarket =
          _market == 'HK' ? '港股' : (_market == 'US' ? '美股ETF' : 'A股ETF');
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DecisionPromptSheet(
          productCategory: categoryForMarket,
          amount: _totalCost,
          decisionType: DecisionType.buy,
          holdingId: holding.id,
          holdingName: holding.stockName,
          categoryOptions: const ['A股ETF', '港股', '美股ETF', '主动基金', '其他'],
        ),
      );
      if (mounted) context.pop();
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
              const SizedBox(height: 16),

              // ── 语音输入 ──
              _buildVoiceSection(),
              const SizedBox(height: 20),

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
            decoration: InputDecoration(
              hintText: _market == 'A'
                  ? '输入代码或名称，如 600519 或 贵州茅台'
                  : (_market == 'HK'
                      ? '输入代码或名称，如 00700 或 腾讯'
                      : '输入代码或名称，如 AAPL 或 Apple'),
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

  // ── 语音输入区域 ──
  Widget _buildVoiceSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.06),
            AppColors.primary.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_outlined,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text(
                '语音输入',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'AI',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '说出股票名称、股数和成本价，AI自动识别',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          VoiceInputButton(
            inputContext: 'stock',
            onResult: _onVoiceResult,
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

// ── 股票候选确认弹窗 ────────────────────────────────────────────────
class _StockCandidateSheet extends StatelessWidget {
  final String stockName;
  final List<Map<String, String>> candidates;
  final void Function(Map<String, String> candidate) onSelect;

  const _StockCandidateSheet({
    required this.stockName,
    required this.candidates,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 手柄
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.search, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '找到以下「$stockName」相关股票，请确认选择：',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: candidates.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final c = candidates[i];
                return InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    onSelect(c);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            c['symbol'] ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            c['name'] ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.check_circle_outline,
                            size: 18, color: AppColors.primary),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '没有合适的，手动输入',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
