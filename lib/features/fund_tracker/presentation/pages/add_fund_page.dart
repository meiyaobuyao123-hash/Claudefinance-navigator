import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/fund_holding.dart';
import '../providers/fund_tracker_provider.dart';

class AddFundPage extends ConsumerStatefulWidget {
  const AddFundPage({super.key});

  @override
  ConsumerState<AddFundPage> createState() => _AddFundPageState();
}

class _AddFundPageState extends ConsumerState<AddFundPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _sharesCtrl = TextEditingController();
  final _costNavCtrl = TextEditingController();

  // 搜索/验证相关状态
  bool _isSearching = false;
  String? _fundName;
  String? _searchError;
  List<Map<String, String>> _suggestions = [];

  // 是否已验证基金代码
  bool get _isVerified => _fundName != null && _searchError == null;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _sharesCtrl.dispose();
    _costNavCtrl.dispose();
    super.dispose();
  }

  // ── 搜索基金（输入中实时）──
  Future<void> _onCodeChanged(String val) async {
    // 重置验证状态
    setState(() {
      _fundName = null;
      _searchError = null;
    });
    if (val.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    final api = ref.read(fundApiServiceProvider);
    final results = await api.searchFund(val.trim());
    if (!mounted) return;
    setState(() => _suggestions = results);
  }

  // ── 验证基金代码（查询实时估值接口）──
  Future<void> _verifyFundCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchError = null;
      _fundName = null;
      _suggestions = [];
    });

    try {
      final api = ref.read(fundApiServiceProvider);
      final info = await api.fetchFundInfo(code);
      final name = info['name']?.toString() ?? '';
      final navStr = info['dwjz']?.toString() ?? '';
      final nav = double.tryParse(navStr) ?? 0;

      if (!mounted) return;
      setState(() {
        _fundName = name;
        _isSearching = false;
        // 自动填入成本净值（参考当前净值）
        if (_costNavCtrl.text.isEmpty && nav > 0) {
          _costNavCtrl.text = nav.toStringAsFixed(4);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchError = '基金代码不存在或暂时不可用';
        _isSearching = false;
      });
    }
  }

  // ── 从搜索建议选择 ──
  void _selectSuggestion(Map<String, String> suggestion) {
    _codeCtrl.text = suggestion['code']!;
    setState(() {
      _suggestions = [];
      _fundName = null;
      _searchError = null;
    });
    _verifyFundCode();
  }

  // ── 提交添加 ──
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先验证基金代码')),
      );
      return;
    }

    final shares = double.parse(_sharesCtrl.text.trim());
    final costNav = double.parse(_costNavCtrl.text.trim());

    final holding = FundHolding(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fundCode: _codeCtrl.text.trim(),
      fundName: _fundName!,
      shares: shares,
      costNav: costNav,
      addedDate: _fmtDate(DateTime.now()),
    );

    await ref.read(fundHoldingsProvider.notifier).addHolding(holding);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加 ${holding.fundName}')),
      );
      context.pop();
    }
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('添加基金'),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── 基金代码 ───
                _SectionLabel('基金代码'),
                const SizedBox(height: 8),
                _buildCodeField(),
                // 搜索建议列表
                if (_suggestions.isNotEmpty) _buildSuggestions(),
                // 验证结果：成功
                if (_isVerified) _buildVerifiedBadge(),
                // 验证结果：失败
                if (_searchError != null) _buildErrorBadge(),

                const SizedBox(height: 20),

                // ─── 持仓份额 ───
                _SectionLabel('持仓份额'),
                const SizedBox(height: 8),
                _buildNumberField(
                  controller: _sharesCtrl,
                  hint: '例如：1000.00',
                  label: '份',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '请输入持仓份额';
                    final n = double.tryParse(v.trim());
                    if (n == null || n <= 0) return '请输入有效份额（大于0）';
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // ─── 成本净值 ───
                _SectionLabel('买入均价（成本净值）'),
                const SizedBox(height: 4),
                Text(
                  '填写你的实际买入均价，用于计算累计收益',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                _buildNumberField(
                  controller: _costNavCtrl,
                  hint: '例如：1.2345',
                  label: '元/份',
                  decimal: 4,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '请输入成本净值';
                    final n = double.tryParse(v.trim());
                    if (n == null || n <= 0) return '请输入有效净值（大于0）';
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // ─── 预估成本 ───
                _buildCostPreview(),

                const SizedBox(height: 32),

                // ─── 确认按钮 ───
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isVerified ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor:
                          AppColors.primary.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _isVerified ? '确认添加' : '请先验证基金代码',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── 基金代码输入框 ───
  Widget _buildCodeField() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _codeCtrl,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              hintText: '输入基金代码或名称，如 000001 或 沪深300',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            onChanged: _onCodeChanged,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '请输入基金代码或名称';
              return null;
            },
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isSearching ? null : _verifyFundCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('验证',
                style: TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ),
      ],
    );
  }

  // ─── 搜索建议下拉 ───
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
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: _suggestions
            .map((s) => InkWell(
                  onTap: () => _selectSuggestion(s),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Text(
                          s['code']!,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            s['name']!,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ─── 验证成功徽章 ───
  Widget _buildVerifiedBadge() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline,
              size: 18, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _fundName ?? '',
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.success,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 验证失败提示 ───
  Widget _buildErrorBadge() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Text(
            _searchError ?? '',
            style: TextStyle(fontSize: 13, color: AppColors.error),
          ),
        ],
      ),
    );
  }

  // ─── 数值输入框 ───
  Widget _buildNumberField({
    required TextEditingController controller,
    required String hint,
    required String label,
    int decimal = 2,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      decoration: InputDecoration(
        hintText: hint,
        suffixText: label,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      onChanged: (_) => setState(() {}),
      validator: validator,
    );
  }

  // ─── 成本预估（实时计算）───
  Widget _buildCostPreview() {
    final shares = double.tryParse(_sharesCtrl.text.trim());
    final costNav = double.tryParse(_costNavCtrl.text.trim());
    if (shares == null || costNav == null || shares <= 0 || costNav <= 0) {
      return const SizedBox.shrink();
    }
    final total = shares * costNav;
    final formatted = total >= 10000
        ? '${(total / 10000).toStringAsFixed(2)}万元'
        : '${total.toStringAsFixed(2)}元';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.calculate_outlined,
              size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            '持仓成本约  ',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          Text(
            formatted,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// ─── 区块标签 ───
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}
