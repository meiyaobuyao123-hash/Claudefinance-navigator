import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../fund_tracker/data/services/voice_input_service.dart';

/// AI 对话语音输入覆盖层
///
/// 设计要点：
/// - 全屏覆盖，不用底部弹窗（对话感更强）
/// - 智能静默检测：停顿 2.5 秒自动完成，而不是截断
/// - 识别完成后展示可编辑结果，用户确认再发
/// - 本地金融词典纠错（ETF/QDII/净值等高频误识别）
/// - 支持"打断 AI 回答"场景
class ChatVoiceOverlay extends StatefulWidget {
  /// 用户确认发送时的回调
  final void Function(String text) onSend;

  /// 关闭覆盖层
  final VoidCallback onDismiss;

  /// AI 是否正在流式输出（影响顶部提示文字）
  final bool isAiStreaming;

  /// 打断 AI 流式输出的回调
  final VoidCallback? onInterruptAi;

  const ChatVoiceOverlay({
    super.key,
    required this.onSend,
    required this.onDismiss,
    this.isAiStreaming = false,
    this.onInterruptAi,
  });

  @override
  State<ChatVoiceOverlay> createState() => _ChatVoiceOverlayState();
}

class _ChatVoiceOverlayState extends State<ChatVoiceOverlay>
    with TickerProviderStateMixin {
  final _voiceService = VoiceInputService();
  final _editCtrl = TextEditingController();

  _OverlayPhase _phase = _OverlayPhase.recording;
  String _liveText = '';       // STT 实时文字
  String _finalText = '';      // 确认阶段可编辑文字
  bool _hasCorrections = false; // 是否做了金融词典纠错
  String _statusText = '正在聆听，请说话...';

  // 静默检测
  Timer? _silenceTimer;
  int _silenceCountdown = 0;   // 0 = 不显示倒计时
  static const _silenceSeconds = 3;

  // 波形动画
  late AnimationController _waveCtrl;
  late Animation<double> _waveAnim;

  // 错误处理
  bool _hasError = false;
  String _errorMsg = '';

  // ── 金融词典：STT 高频误识别纠错 ──
  static const _financialCorrections = <String, String>{
    'E T F': 'ETF',
    'e t f': 'ETF',
    '一体肥': 'ETF',
    'Q D I I': 'QDII',
    'q d i i': 'QDII',
    '基金经历': '基金经理',
    '净zhi': '净值',
    '市赢率': '市盈率',
    '市值率': '市盈率',
    '配自': '配置',
    '理肉': '理财',
    '申请购买': '申购',
    '偿还': '赎回',
    '收购基金': '赎回基金',
    '沪深三百': '沪深300',
    '创业板指': '创业板指数',
    '黄金ETF': 'ETF',   // 避免重复，保留原词
  };

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _waveAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _waveCtrl, curve: Curves.easeInOut),
    );
    // 进入即开始录音
    WidgetsBinding.instance.addPostFrameCallback((_) => _startListening());
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _waveCtrl.dispose();
    _editCtrl.dispose();
    if (_voiceService.isListening) _voiceService.cancelListening();
    super.dispose();
  }

  // ─── 开始录音 ───────────────────────────────────────────────────
  Future<void> _startListening() async {
    setState(() {
      _phase = _OverlayPhase.recording;
      _liveText = '';
      _statusText = '正在聆听，请说话...';
      _hasError = false;
      _silenceCountdown = 0;
    });
    _waveCtrl.repeat(reverse: true);

    try {
      await _voiceService.startListening(
        onResult: (text, isFinal) {
          if (!mounted) return;
          _resetSilenceTimer(); // 有新语音，重置静默计时
          setState(() {
            _liveText = text;
            _silenceCountdown = 0;
            _statusText = '正在聆听...';
          });
          if (isFinal && text.isNotEmpty) {
            _onRecordingDone(text);
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMsg = '语音识别不可用，请检查麦克风权限';
        _phase = _OverlayPhase.error;
      });
      _waveCtrl.stop();
    }
  }

  // ─── 静默检测计时器 ──────────────────────────────────────────────
  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final remaining = _silenceSeconds - t.tick;
      if (remaining <= 0) {
        t.cancel();
        setState(() => _silenceCountdown = 0);
        _stopListening();
      } else {
        setState(() {
          _silenceCountdown = remaining;
          _statusText = '停顿检测中，${remaining}秒后自动完成';
        });
      }
    });
  }

  // ─── 手动停止录音 ────────────────────────────────────────────────
  Future<void> _stopListening() async {
    _silenceTimer?.cancel();
    _waveCtrl.stop();
    await _voiceService.stopListening();
    if (!mounted) return;

    final text = _liveText.trim();
    if (text.isEmpty) {
      setState(() {
        _statusText = '没有识别到语音，请重试';
        _phase = _OverlayPhase.recording;
      });
      // 1秒后重新开始
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) _startListening();
    } else {
      _onRecordingDone(text);
    }
  }

  // ─── 录音完成 → 进入确认阶段 ────────────────────────────────────
  void _onRecordingDone(String rawText) {
    _silenceTimer?.cancel();
    _waveCtrl.stop();
    if (_voiceService.isListening) _voiceService.cancelListening();

    final corrected = _applyCorrections(rawText);
    _hasCorrections = corrected != rawText;

    setState(() {
      _phase = _OverlayPhase.confirm;
      _finalText = corrected;
      _editCtrl.text = corrected;
      _editCtrl.selection = TextSelection.collapsed(offset: corrected.length);
    });
  }

  // ─── 金融词典纠错 ────────────────────────────────────────────────
  String _applyCorrections(String text) {
    var result = text;
    for (final entry in _financialCorrections.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  // ─── 发送 ────────────────────────────────────────────────────────
  void _send() {
    final text = _editCtrl.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    widget.onDismiss();
  }

  // ─── 重新录音 ────────────────────────────────────────────────────
  void _reRecord() {
    _editCtrl.clear();
    _startListening();
  }

  // ─── 取消 ────────────────────────────────────────────────────────
  void _cancel() {
    _voiceService.cancelListening();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.75),
      child: SafeArea(
        child: Stack(
          children: [
            // 点击背景取消
            GestureDetector(
              onTap: _phase == _OverlayPhase.recording ? _cancel : null,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),

            // 主内容区域
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _phase == _OverlayPhase.confirm
                    ? _buildConfirmCard()
                    : _phase == _OverlayPhase.error
                        ? _buildErrorCard()
                        : _buildRecordingCard(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 录音阶段 UI ─────────────────────────────────────────────────
  Widget _buildRecordingCard() {
    return Container(
      key: const ValueKey('recording'),
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部标题 + 打断提示
          if (widget.isAiStreaming)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.orange),
                  const SizedBox(width: 6),
                  const Text(
                    '已打断明理的回答',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ],
              ),
            ),

          const Text(
            '正在聆听',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '试试说："我有100万想稳健增值"',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          // 波形动画
          _buildWaveform(),
          const SizedBox(height: 20),

          // 实时识别文字
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 60, maxHeight: 120),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: SingleChildScrollView(
              child: Text(
                _liveText.isEmpty ? '请开始说话...' : _liveText,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: _liveText.isEmpty
                      ? AppColors.textHint
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 状态文字 + 静默倒计时
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _silenceCountdown > 0
                ? _buildSilenceCountdown()
                : Text(
                    _statusText,
                    key: const ValueKey('status'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
          const SizedBox(height: 24),

          // 底部按钮
          Row(
            children: [
              // 取消
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: const Text(
                    '取消',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 完成
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _liveText.isNotEmpty ? _stopListening : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.border,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '完成',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 确认阶段 UI ─────────────────────────────────────────────────
  Widget _buildConfirmCard() {
    return Container(
      key: const ValueKey('confirm'),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 20),
              SizedBox(width: 8),
              Text(
                '识别完成，确认后发送',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '可直接编辑修改识别内容',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),

          // 纠错提示
          if (_hasCorrections) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_fix_high, size: 13, color: Colors.blue),
                  SizedBox(width: 6),
                  Text(
                    '已自动纠正金融术语',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // 可编辑文字区域
          TextField(
            controller: _editCtrl,
            maxLines: null,
            minLines: 3,
            autofocus: false,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
              height: 1.6,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '提示：可直接点"发送"，或修改后再发',
            style: TextStyle(fontSize: 11, color: AppColors.textHint),
          ),
          const SizedBox(height: 16),

          // 操作按钮
          Row(
            children: [
              // 重新录音
              OutlinedButton.icon(
                onPressed: _reRecord,
                icon: const Icon(Icons.mic, size: 16),
                label: const Text('重录'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
              const SizedBox(width: 12),
              // 发送
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _send,
                  icon: const Icon(Icons.send, size: 16, color: Colors.white),
                  label: const Text(
                    '发送给明理',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 错误阶段 UI ─────────────────────────────────────────────────
  Widget _buildErrorCard() {
    return Container(
      key: const ValueKey('error'),
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mic_off, size: 48, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            _errorMsg,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('关闭'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _startListening,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '重试',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 静默倒计时指示器 ────────────────────────────────────────────
  Widget _buildSilenceCountdown() {
    return Row(
      key: const ValueKey('countdown'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.timer_outlined, size: 14, color: Colors.orange),
        const SizedBox(width: 4),
        Text(
          '停顿检测：$_silenceCountdown 秒后自动完成',
          style: const TextStyle(fontSize: 13, color: Colors.orange),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            _silenceTimer?.cancel();
            setState(() => _silenceCountdown = 0);
            _onRecordingDone(_liveText);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '立即完成',
              style: TextStyle(fontSize: 11, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // ─── 波形动画 ────────────────────────────────────────────────────
  Widget _buildWaveform() {
    return SizedBox(
      height: 48,
      child: AnimatedBuilder(
        animation: _waveAnim,
        builder: (_, __) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(9, (i) {
              // 中间高，两边低，波浪错位
              final baseHeight = [0.3, 0.5, 0.7, 0.9, 1.0, 0.9, 0.7, 0.5, 0.3][i];
              final phase = (i % 3) * 0.3;
              final animVal = (_waveCtrl.value - phase).clamp(0.0, 1.0);
              final height = 8 + 32 * baseHeight * (_liveText.isEmpty ? 0.3 : animVal);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 5,
                height: height,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(
                    alpha: _liveText.isEmpty ? 0.3 : 0.7,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          );
        },
      ),
    );
  }

}

enum _OverlayPhase { recording, confirm, error }
