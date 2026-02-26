import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
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

  final List<Map<String, dynamic>> _tabs = [
    {'key': 'all', 'label': '全部'},
    {'key': 'mainland', 'label': '🇨🇳 大陆'},
    {'key': 'hongkong', 'label': '🇭🇰 香港'},
    {'key': 'crypto', 'label': '₿ 加密'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedRegion = _tabs[_tabController.index]['key'];
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<ProductModel> get _filteredProducts {
    if (_selectedRegion == 'all') return ProductsData.all;
    return ProductsData.byRegion(_selectedRegion);
  }

  @override
  Widget build(BuildContext context) {
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
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredProducts.length,
        itemBuilder: (context, index) {
          return _ProductCard(
            product: _filteredProducts[index],
            onTap: () => context.go('/products/${_filteredProducts[index].id}'),
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
            // 收益率预览（展示第一条）
            if (product.returnRates.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
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
