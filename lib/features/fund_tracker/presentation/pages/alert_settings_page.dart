import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/notification_service.dart';

// ── SharedPreferences keys ──
const _keyEnabled = 'alert_enabled';
const _keyTargetReturn = 'alert_target_return';
const _keyMaxDrawdown = 'alert_max_drawdown';

// ── 预警设置数据模型 ──
class AlertSettings {
  final bool enabled;
  final double targetReturnPct; // 止盈：达到此收益率(%)时提醒，0=未设置
  final double maxDrawdownPct; // 止损：亏损超过此比例(%)时提醒，0=未设置

  const AlertSettings({
    this.enabled = false,
    this.targetReturnPct = 0,
    this.maxDrawdownPct = 0,
  });

  AlertSettings copyWith({
    bool? enabled,
    double? targetReturnPct,
    double? maxDrawdownPct,
  }) =>
      AlertSettings(
        enabled: enabled ?? this.enabled,
        targetReturnPct: targetReturnPct ?? this.targetReturnPct,
        maxDrawdownPct: maxDrawdownPct ?? this.maxDrawdownPct,
      );
}

// ── Riverpod Provider ──
final alertSettingsProvider =
    StateNotifierProvider<AlertSettingsNotifier, AlertSettings>(
  (ref) => AlertSettingsNotifier(),
);

class AlertSettingsNotifier extends StateNotifier<AlertSettings> {
  AlertSettingsNotifier() : super(const AlertSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AlertSettings(
      enabled: prefs.getBool(_keyEnabled) ?? false,
      targetReturnPct: prefs.getDouble(_keyTargetReturn) ?? 0,
      maxDrawdownPct: prefs.getDouble(_keyMaxDrawdown) ?? 0,
    );
  }

  Future<void> save(AlertSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, settings.enabled);
    await prefs.setDouble(_keyTargetReturn, settings.targetReturnPct);
    await prefs.setDouble(_keyMaxDrawdown, settings.maxDrawdownPct);
    state = settings;
  }

  // ── 检查是否需要触发预警（在每次刷新后调用）──
  // lastAlertDate 防止同一天重复通知
  Future<void> checkAndAlert({
    required double totalReturnRate,
  }) async {
    if (!state.enabled) return;
    if (state.targetReturnPct <= 0 && state.maxDrawdownPct <= 0) return;

    final prefs = await SharedPreferences.getInstance();
    final today = _todayStr();
    final lastAlert = prefs.getString('alert_last_date') ?? '';

    // 同一天只提醒一次
    if (lastAlert == today) return;

    bool triggered = false;

    if (state.targetReturnPct > 0 &&
        totalReturnRate >= state.targetReturnPct) {
      await NotificationService.instance.showAlert(
        title: '🎉 止盈提醒',
        body:
            '组合累计收益率已达 +${totalReturnRate.toStringAsFixed(2)}%，超过你设定的 ${state.targetReturnPct.toStringAsFixed(1)}% 止盈线',
      );
      triggered = true;
    } else if (state.maxDrawdownPct > 0 &&
        totalReturnRate <= -state.maxDrawdownPct) {
      await NotificationService.instance.showAlert(
        title: '⚠️ 止损提醒',
        body:
            '组合累计亏损已达 ${totalReturnRate.toStringAsFixed(2)}%，超过你设定的 -${state.maxDrawdownPct.toStringAsFixed(1)}% 止损线',
      );
      triggered = true;
    }

    if (triggered) {
      await prefs.setString('alert_last_date', today);
    }
  }

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

// ════════════════════════════════════════════════════
// ─── 预警设置页面 ───
// ════════════════════════════════════════════════════
class AlertSettingsPage extends ConsumerStatefulWidget {
  const AlertSettingsPage({super.key});

  @override
  ConsumerState<AlertSettingsPage> createState() => _AlertSettingsPageState();
}

class _AlertSettingsPageState extends ConsumerState<AlertSettingsPage> {
  late bool _enabled;
  late TextEditingController _targetCtrl;
  late TextEditingController _drawdownCtrl;
  bool _permissionRequested = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(alertSettingsProvider);
    _enabled = settings.enabled;
    _targetCtrl = TextEditingController(
        text: settings.targetReturnPct > 0
            ? settings.targetReturnPct.toStringAsFixed(1)
            : '');
    _drawdownCtrl = TextEditingController(
        text: settings.maxDrawdownPct > 0
            ? settings.maxDrawdownPct.toStringAsFixed(1)
            : '');
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    _drawdownCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleEnable(bool value) async {
    if (value && !_permissionRequested) {
      final granted =
          await NotificationService.instance.requestPermission();
      _permissionRequested = true;
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请在系统设置中允许通知权限')),
        );
        return;
      }
    }
    setState(() => _enabled = value);
  }

  void _save() {
    final target = double.tryParse(_targetCtrl.text) ?? 0;
    final drawdown = double.tryParse(_drawdownCtrl.text) ?? 0;

    if (_enabled && target <= 0 && drawdown <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少设置一个止盈或止损线')),
      );
      return;
    }

    ref.read(alertSettingsProvider.notifier).save(AlertSettings(
          enabled: _enabled,
          targetReturnPct: target,
          maxDrawdownPct: drawdown,
        ));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('预警设置已保存')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('收益预警'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── 开启开关 ──
          _Card(
            child: Row(
              children: [
                const Icon(Icons.notifications_outlined,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('开启预警通知',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      SizedBox(height: 2),
                      Text('达到阈值时通过系统通知提醒你',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Switch(
                  value: _enabled,
                  onChanged: _toggleEnable,
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 止盈线 ──
          _SectionHeader(label: '止盈线（可选）', icon: Icons.trending_up),
          const SizedBox(height: 8),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '累计收益率达到以下数值时提醒',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _targetCtrl,
                  enabled: _enabled,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: '例如 20（代表 +20%）',
                    prefixText: '+',
                    suffixText: '%',
                    filled: true,
                    fillColor: _enabled
                        ? AppColors.surfaceVariant
                        : AppColors.background,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          size: 14, color: AppColors.success),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '适合：已经盈利，想锁定利润时设置',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.success.withOpacity(0.8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 止损线 ──
          _SectionHeader(label: '止损线（可选）', icon: Icons.trending_down),
          const SizedBox(height: 8),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '累计亏损超过以下数值时提醒',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _drawdownCtrl,
                  enabled: _enabled,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: '例如 10（代表亏损 -10%）',
                    prefixText: '-',
                    suffixText: '%',
                    filled: true,
                    fillColor: _enabled
                        ? AppColors.surfaceVariant
                        : AppColors.background,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.error, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          size: 14, color: AppColors.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '适合：控制风险，亏损达到心理红线时提醒',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.error.withOpacity(0.8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── 保存按钮 ──
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('保存设置',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          const Text(
            '⚡ 同一天内每个预警最多提醒一次',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

// ─── 辅助 widget ───
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
      ],
    );
  }
}
