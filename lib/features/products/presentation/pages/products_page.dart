import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/market_rate_provider.dart';
import '../../../../data/datasources/products_data.dart';
import '../../../../data/models/product_model.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedRegion = 'all';
  int? _selectedRisk; // null = 全部风险
  String _searchText = '';
  final _searchCtrl = TextEditingController();

  final List<Map<String, dynamic>> _tabs = [
    {'key': 'all', 'label': '全部'},
    {'key': 'mainland', 'label': '🇨🇳 大陆'},
    {'key': 'hongkong', 'label': '🇭🇰 香港'},
    {'key': 'crypto', 'label': '₿ 加密'},
  ];

  static const _riskLabels = {
    1: 'R1 极低',
    2: 'R2 低',
    3: 'R3 中',
    4: 'R4 高',
    5: 'R5 极高',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedRegion = _tabs[_tabController.index]['key'];
          _selectedRisk = null; // 切区域时重置风险筛选
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ProductModel> get _filteredProducts {
    var list = _selectedRegion == 'all'
        ? ProductsData.all
        : ProductsData.byRegion(_selectedRegion);
    if (_selectedRisk != null) {
      list = list.where((p) => p.riskLevel == _selectedRisk).toList();
    }
    if (_searchText.isNotEmpty) {
      final q = _searchText.toLowerCase();
      list = list
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.shortName.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('产品库'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((t) => Tab(text: t['label'])).toList(),
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
        ),
      ),
      body: Column(
        children: [
          // ─── 搜索框 ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchText = v),
              decoration: InputDecoration(
                hintText: '搜索产品名称或类别…',
                prefixIcon: const Icon(Icons.search, color: AppColors.textHint, size: 20),
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18, color: AppColors.textHint),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchText = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          // ─── 风险筛选条 ───
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _RiskChip(
                  label: '全部',
                  selected: _selectedRisk == null,
                  color: AppColors.primary,
                  onTap: () => setState(() => _selectedRisk = null),
                ),
                ..._riskLabels.entries.map((e) => _RiskChip(
                      label: e.value,
                      selected: _selectedRisk == e.key,
                      color: _riskColor(e.key),
                      onTap: () => setState(() =>
                          _selectedRisk = _selectedRisk == e.key ? null : e.key),
                    )),
              ],
            ),
          ),
          // ─── 产品数量提示 ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                Text(
                  '共 ${products.length} 种产品',
                  style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ],
            ),
          ),
          // ─── 列表 ───
          Expanded(
            child: products.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 48, color: AppColors.textHint),
                        SizedBox(height: 12),
                        Text('没有找到匹配的产品',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      return _ProductCard(
                        product: products[index],
                        onTap: () => context.go('/products/${products[index].id}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _riskColor(int level) {
    switch (level) {
      case 1: return AppColors.riskLevel1;
      case 2: return AppColors.riskLevel2;
      case 3: return AppColors.riskLevel3;
      case 4: return AppColors.riskLevel4;
      case 5: return AppColors.riskLevel5;
      default: return AppColors.textHint;
    }
  }
}

class _ProductCard extends ConsumerWidget {
  final ProductModel product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  Color get _regionColor {
    switch (product.region) {
      case 'mainland': return AppColors.mainlandColor;
      case 'hongkong': return AppColors.hongkongColor;
      case 'crypto': return AppColors.cryptoColor;
      default: return AppColors.primary;
    }
  }

  String get _regionLabel {
    switch (product.region) {
      case 'mainland': return '🇨🇳 大陆';
      case 'hongkong': return '🇭🇰 香港';
      case 'crypto': return '₿ 加密';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveRate = ref.watch(marketRatesProvider).valueOrNull?[product.id];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                // 地区标签
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _regionColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _regionLabel,
                    style: TextStyle(fontSize: 11, color: _regionColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 风险等级
            _RiskIndicator(level: product.riskLevel),
            const SizedBox(height: 10),
            // 实时行情 or 参考收益
            if (liveRate != null || product.returnRates.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    if (liveRate != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '实时',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          liveRate.displayRate,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: liveRate.isUp ? AppColors.success : AppColors.error,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else ...[
                      const Text(
                        '参考收益',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const Spacer(),
                      Text(
                        product.returnRates.first.rate,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                      if (product.returnRates.length > 1) ...[
                        const SizedBox(width: 6),
                        Text(
                          '+${product.returnRates.length - 1}种期限',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            // 底部信息
            Row(
              children: [
                if (product.minInvestment != null)
                  Text(
                    '起投 ${_formatAmount(product.minInvestment!)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                const Spacer(),
                Text(
                  product.category,
                  style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppColors.textHint, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 10000000) return '${(amount / 10000000).toStringAsFixed(0)}千万';
    if (amount >= 1000000) return '${(amount / 10000).toStringAsFixed(0)}万';
    if (amount >= 10000) return '${(amount / 10000).toStringAsFixed(0)}万';
    return '${amount.toStringAsFixed(0)}元';
  }
}

class _RiskIndicator extends StatelessWidget {
  final int level;

  const _RiskIndicator({required this.level});

  String get _label {
    switch (level) {
      case 1: return '极低风险';
      case 2: return '低风险';
      case 3: return '中等风险';
      case 4: return '高风险';
      case 5: return '极高风险';
      default: return '';
    }
  }

  Color get _color {
    switch (level) {
      case 1: return AppColors.riskLevel1;
      case 2: return AppColors.riskLevel2;
      case 3: return AppColors.riskLevel3;
      case 4: return AppColors.riskLevel4;
      case 5: return AppColors.riskLevel5;
      default: return AppColors.textHint;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(5, (i) => Container(
          width: 20,
          height: 4,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            color: i < level ? _color : _color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        )),
        const SizedBox(width: 8),
        Text(
          _label,
          style: TextStyle(fontSize: 11, color: _color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ─── 风险筛选 Chip ───
class _RiskChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _RiskChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
