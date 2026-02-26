import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: 接入真实用户状态
    const bool isLoggedIn = false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppBar(title: Text('我的')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 用户信息卡片
          if (!isLoggedIn)
            _buildLoginPrompt(context)
          else
            _buildUserCard(),
          const SizedBox(height: 16),
          // 风险画像
          _buildRiskProfile(),
          const SizedBox(height: 16),
          // 功能列表
          _buildMenuSection('我的数据', [
            _MenuItem(icon: Icons.history, label: '诊断记录', onTap: () {}),
            _MenuItem(icon: Icons.bookmark_outline, label: '收藏产品', onTap: () {}),
          ]),
          const SizedBox(height: 12),
          _buildMenuSection('设置', [
            _MenuItem(icon: Icons.notifications_outlined, label: '消息通知', onTap: () {}),
            _MenuItem(icon: Icons.security, label: '隐私政策', onTap: () {}),
            _MenuItem(icon: Icons.info_outline, label: '关于我们', onTap: () {}),
          ]),
          const SizedBox(height: 24),
          // 免责声明
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '⚠️ 重要声明\n\n本APP为理财产品类型导航工具，仅提供教育性信息，不构成投资建议。理财有风险，投资需谨慎。所有投资决策由您自行负责。',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(Icons.person_outline, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          const Text(
            '登录后可保存你的风险画像\n和历史诊断记录',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.push('/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                  ),
                  child: const Text('登录'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/register'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                  ),
                  child: const Text('注册'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.person, color: Colors.white, size: 28),
          ),
          SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '用户昵称',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              Text(
                '风险等级：稳健型',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiskProfile() {
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
          const Text(
            '我的风险画像',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              '完成AI诊断后，你的风险画像将显示在这里',
              style: TextStyle(fontSize: 13, color: AppColors.textHint),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          // 5种风险档位展示
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _RiskTag(label: '保守', color: AppColors.riskLevel1),
              _RiskTag(label: '稳健', color: AppColors.riskLevel2),
              _RiskTag(label: '平衡', color: AppColors.riskLevel3),
              _RiskTag(label: '积极', color: AppColors.riskLevel4),
              _RiskTag(label: '激进', color: AppColors.riskLevel5),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(String title, List<_MenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ...items.asMap().entries.map((entry) {
            final isLast = entry.key == items.length - 1;
            return Column(
              children: [
                ListTile(
                  leading: Icon(entry.value.icon, color: AppColors.textSecondary, size: 22),
                  title: Text(entry.value.label, style: const TextStyle(fontSize: 14)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textHint, size: 18),
                  onTap: entry.value.onTap,
                  dense: true,
                ),
                if (!isLast)
                  const Divider(indent: 54, endIndent: 16, height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({required this.icon, required this.label, required this.onTap});
}

class _RiskTag extends StatelessWidget {
  final String label;
  final Color color;

  const _RiskTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}
