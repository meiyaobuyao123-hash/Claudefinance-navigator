import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 顶部Banner
            SliverToBoxAdapter(child: _buildHeader(context)),
            // 快捷入口
            SliverToBoxAdapter(child: _buildQuickActions(context)),
            // 财富分层导航
            SliverToBoxAdapter(child: _buildWealthTiers(context)),
            // 产品分区
            SliverToBoxAdapter(child: _buildProductRegions(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '理财导航',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '聪明配置，让财富增值',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => context.go('/profile'),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.person, color: AppColors.primary, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // AI诊断入口卡片
          GestureDetector(
            onTap: () => context.go('/chat'),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI理财诊断',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '告诉我你的资产和目标\n我帮你找到最适合的投资方向',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '开始诊断 →',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: const Icon(Icons.psychology, color: Colors.white, size: 44),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '快捷工具',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _QuickActionItem(
                icon: Icons.calculate,
                label: '复利计算',
                color: const Color(0xFF6366F1),
                onTap: () => context.go('/tools'),
              ),
              const SizedBox(width: 12),
              _QuickActionItem(
                icon: Icons.trending_up,
                label: '目标规划',
                color: const Color(0xFF10B981),
                onTap: () => context.go('/tools'),
              ),
              const SizedBox(width: 12),
              _QuickActionItem(
                icon: Icons.pie_chart,
                label: '配置方案',
                color: const Color(0xFFF59E0B),
                onTap: () => context.go('/products'),
              ),
              const SizedBox(width: 12),
              _QuickActionItem(
                icon: Icons.school,
                label: '产品知识',
                color: const Color(0xFFEF4444),
                onTap: () => context.go('/products'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWealthTiers(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '按资产量级找方案',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _WealthTierCard(
            title: '50万–100万',
            subtitle: '入门财富管理',
            products: '定存 · 银行理财 · ETF · 增额寿',
            color: const Color(0xFF10B981),
            icon: Icons.account_balance_wallet,
            onTap: () => context.go('/products'),
          ),
          const SizedBox(height: 10),
          _WealthTierCard(
            title: '100万–500万',
            subtitle: '标准财富管理',
            products: '私募基金 · 港险 · REITs · 可转债',
            color: AppColors.primary,
            icon: Icons.trending_up,
            onTap: () => context.go('/products'),
          ),
          const SizedBox(height: 10),
          _WealthTierCard(
            title: '500万–1000万',
            subtitle: '高净值理财',
            products: '信托 · 家族信托 · 海外ETF · 美元债',
            color: AppColors.gold,
            icon: Icons.diamond,
            onTap: () => context.go('/products'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductRegions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '按地区浏览产品',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RegionCard(
                  flag: '🇨🇳',
                  title: '大陆产品',
                  subtitle: '存款·基金·股票·保险',
                  color: AppColors.mainlandColor,
                  onTap: () => context.go('/products'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RegionCard(
                  flag: '🇭🇰',
                  title: '香港产品',
                  subtitle: '港股·保险·外汇·ETF',
                  color: AppColors.hongkongColor,
                  onTap: () => context.go('/products'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RegionCard(
                  flag: '₿',
                  title: '加密资产',
                  subtitle: 'BTC ETF·合规渠道',
                  color: AppColors.cryptoColor,
                  onTap: () => context.go('/products'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WealthTierCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String products;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _WealthTierCard({
    required this.title,
    required this.subtitle,
    required this.products,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          subtitle,
                          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    products,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }
}

class _RegionCard extends StatelessWidget {
  final String flag;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RegionCard({
    required this.flag,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
