import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/datasources/products_data.dart';
import '../../../../data/datasources/platforms_data.dart';
import '../../../../data/models/product_model.dart';

class ProductDetailPage extends StatelessWidget {
  final String productId;

  const ProductDetailPage({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    final product = ProductsData.findById(productId);
    if (product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('产品详情')),
        body: const Center(child: Text('产品不存在')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(product.name),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 产品简介卡片
            _buildIntroCard(product),
            const SizedBox(height: 16),
            // 收益率明细
            _buildReturnRates(product),
            const SizedBox(height: 16),
            // 风险详解
            _buildRiskDetail(product),
            const SizedBox(height: 16),
            // 流动性
            _buildLiquidity(product),
            // 平台预览截图（如有）
            if (product.screenshots.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildPlatformScreenshots(product),
            ],
            // 适合人群
            const SizedBox(height: 16),
            _buildSuitableFor(product),
            // 注意事项
            const SizedBox(height: 16),
            _buildWatchOut(product),
            // 可购买平台
            const SizedBox(height: 16),
            _buildPlatforms(product),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroCard(ProductModel product) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.9), AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            product.category,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Text(
            product.description,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnRates(ProductModel product) {
    return _SectionCard(
      title: '📈 收益率详情',
      child: Column(
        children: product.returnRates.map((rate) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: rate.isGuaranteed ? AppColors.success : AppColors.warning,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  rate.period,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              ),
              Row(
                children: [
                  Text(
                    rate.rate,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: rate.isGuaranteed ? AppColors.success : AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (rate.isGuaranteed ? AppColors.success : AppColors.warning)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      rate.isGuaranteed ? '保证' : '参考',
                      style: TextStyle(
                        fontSize: 10,
                        color: rate.isGuaranteed ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildRiskDetail(ProductModel product) {
    return _SectionCard(
      title: '⚠️ 风险详解',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 风险等级条
          Row(
            children: [
              const Text('风险等级：', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              ...List.generate(5, (i) {
                final color = _riskColor(product.riskLevel);
                return Container(
                  width: 22,
                  height: 5,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    color: i < product.riskLevel ? color : color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
              const SizedBox(width: 8),
              Text(
                _riskLabel(product.riskLevel),
                style: TextStyle(
                  fontSize: 13,
                  color: _riskColor(product.riskLevel),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            product.riskDescription,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiquidity(ProductModel product) {
    return _SectionCard(
      title: '💧 流动性',
      child: Text(
        product.liquidity,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.6),
      ),
    );
  }

  Widget _buildPlatformScreenshots(ProductModel product) {
    return _SectionCard(
      title: '📱 平台操作预览',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '以下截图展示如何在对应平台操作',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: product.screenshots.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final shot = product.screenshots[index];
                return Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          shot.imageAsset,
                          fit: BoxFit.cover,
                          width: 120,
                          errorBuilder: (_, __, ___) => Container(
                            width: 120,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.image_outlined,
                                    color: AppColors.textHint, size: 32),
                                const SizedBox(height: 6),
                                Text(
                                  shot.step,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      shot.caption,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuitableFor(ProductModel product) {
    return _SectionCard(
      title: '👤 适合人群',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: product.suitableFor.map((tag) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            tag,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.primary,
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildWatchOut(ProductModel product) {
    return _SectionCard(
      title: '🚨 注意事项',
      child: Column(
        children: product.watchOut.asMap().entries.map((entry) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${entry.key + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildPlatforms(ProductModel product) {
    final platforms = PlatformsData.findByIds(product.platformIds);
    if (platforms.isEmpty) return const SizedBox();

    return _SectionCard(
      title: '🔗 去哪里买',
      child: Column(
        children: platforms.map((platform) => _PlatformTile(platform: platform)).toList(),
      ),
    );
  }

  String _riskLabel(int level) {
    switch (level) {
      case 1: return '极低风险';
      case 2: return '低风险';
      case 3: return '中等风险';
      case 4: return '高风险';
      case 5: return '极高风险';
      default: return '';
    }
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

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PlatformTile extends StatelessWidget {
  final PlatformModel platform;

  const _PlatformTile({required this.platform});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                platform.logoAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.open_in_new,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  platform.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  platform.description,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              final url = platform.deepLinkUrl ?? platform.webUrl;
              if (url != null) {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '去购买',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
