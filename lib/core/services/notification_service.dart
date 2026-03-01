import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 本地推送通知服务（单例）
/// 功能：
///  1. 每日收益播报 —— 刷新后显示今日盈亏/累计收益摘要
///  2. 预警通知  —— 止盈/止损触达时即时提示
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── 通知渠道 ID（Android 必填，iOS 忽略）──
  static const _channelPnl = 'pnl_daily';
  static const _channelAlert = 'alert_threshold';

  // ── 通知 ID（保持固定，覆盖写不堆积）──
  static const _idPnl = 1001;
  static const _idAlert = 1002;

  // ──────────────────────────────────────────────────
  // 初始化（在 main.dart 调用）
  // ──────────────────────────────────────────────────
  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  // ──────────────────────────────────────────────────
  // 申请 iOS 通知权限（首次打开基金组合时调用）
  // ──────────────────────────────────────────────────
  Future<bool> requestPermission() async {
    if (!_initialized) return false;
    final granted = await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
    return granted;
  }

  // ──────────────────────────────────────────────────
  // 功能一：每日收益播报
  // ──────────────────────────────────────────────────
  Future<void> showPnlSummary({
    required double todayGain,
    required double totalReturn,
    required double totalReturnRate,
    bool hasEstimate = false,
  }) async {
    if (!_initialized) return;

    final todaySign = todayGain >= 0 ? '+' : '';
    final totalSign = totalReturn >= 0 ? '+' : '';
    final rateSign = totalReturnRate >= 0 ? '+' : '';

    final title = hasEstimate
        ? '今日盈亏 $todaySign${_fmt(todayGain)}'
        : '基金组合已刷新';

    final body =
        '累计收益 $totalSign${_fmt(totalReturn)}（$rateSign${totalReturnRate.toStringAsFixed(2)}%）';

    await _show(_idPnl, title, body, _channelPnl, '收益播报');
  }

  // ──────────────────────────────────────────────────
  // 功能三：止盈/止损预警
  // ──────────────────────────────────────────────────
  Future<void> showAlert({
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;
    await _show(_idAlert, title, body, _channelAlert, '收益预警');
  }

  // ──────────────────────────────────────────────────
  // 功能四：自选价格提醒（每只股票用独立 ID，避免覆盖）
  // ──────────────────────────────────────────────────
  static const _channelPriceAlert = 'price_alert';

  Future<void> showPriceAlert({
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;
    // 用 title+body 组合哈希生成 2000-2999 范围内唯一通知 ID
    final id = 2000 + (title + body).hashCode.abs() % 1000;
    await _show(id, title, body, _channelPriceAlert, '自选提醒');
  }

  // ── 内部统一发送 ──
  Future<void> _show(
    int id,
    String title,
    String body,
    String channelId,
    String channelName,
  ) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: true,
      );
      const iosDetails = DarwinNotificationDetails();
      final details =
          NotificationDetails(android: androidDetails, iOS: iosDetails);
      await _plugin.show(id, title, body, details);
    } catch (_) {
      // 通知失败静默处理，不影响主流程
    }
  }

  // ── 数字格式化（NaN/Infinity 安全）──
  static String _fmt(double v) {
    if (v.isNaN || v.isInfinite) return '--';
    if (v.abs() >= 10000) return '${(v / 10000).toStringAsFixed(2)}万';
    return v.toStringAsFixed(2);
  }
}
