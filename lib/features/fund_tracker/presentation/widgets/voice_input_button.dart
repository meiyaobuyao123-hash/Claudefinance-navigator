import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/services/voice_input_service.dart';
import '../../data/services/fund_api_service.dart';

/// 语音输入录音按钮 + 底部弹窗
/// 闭环流程：录音 → AI解析 → 结果预览(含缺失提示) → 继续补充/确认使用
class VoiceInputButton extends StatelessWidget {
  /// "fund" 或 "stock"，用于 AI 上下文提示
  final String inputContext;

  /// 解析完成回调（用户确认后才触发）
  final void Function(VoiceParseResult result) onResult;

  const VoiceInputButton({
    super.key,
    required this.inputContext,
    required this.onResult,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showVoiceSheet(context),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic_outlined, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              '语音输入',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVoiceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _VoiceInputSheet(
        inputContext: inputContext,
        onConfirm: (result) {
          Navigator.of(ctx).pop();
          onResult(result);
        },
      ),
    );
  }
}

// ─────────────────────────── 语音录入底部弹窗 ───────────────────────────

class _VoiceInputSheet extends StatefulWidget {
  final String inputContext;
  final void Function(VoiceParseResult result) onConfirm;

  const _VoiceInputSheet({
    required this.inputContext,
    required this.onConfirm,
  });

  @override
  State<_VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends State<_VoiceInputSheet>
    with SingleTickerProviderStateMixin {
  final _voiceService = VoiceInputService();
  final _fundApi = FundApiService();

  // 状态
  _VoiceState _state = _VoiceState.idle;
  String _recognizedText = '';
  String _statusText = '点击麦克风开始说话';

  // 累积结果：多轮语音合并
  VoiceParseResult? _currentResult;

  // 基金搜索候选列表
  List<Map<String, String>> _fundCandidates = [];

  // 动画
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    if (_voiceService.isListening) {
      _voiceService.cancelListening();
    }
    super.dispose();
  }

  // ── 开始录音 ──
  Future<void> _startListening() async {
    setState(() {
      _state = _VoiceState.listening;
      _recognizedText = '';
      _statusText = '正在听...';
    });
    _pulseController.repeat(reverse: true);

    try {
      await _voiceService.startListening(
        onResult: (text, isFinal) {
          if (!mounted) return;
          setState(() {
            _recognizedText = text;
          });
          if (isFinal && text.isNotEmpty) {
            _onSpeechDone(text);
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _VoiceState.error;
        _statusText = '语音识别不可用：$e';
      });
      _pulseController.stop();
    }
  }

  // ── 停止录音 ──
  Future<void> _stopListening() async {
    await _voiceService.stopListening();
    _pulseController.stop();
    _pulseController.reset();

    if (_recognizedText.isNotEmpty) {
      _onSpeechDone(_recognizedText);
    } else {
      setState(() {
        _state = _currentResult != null ? _VoiceState.result : _VoiceState.idle;
        _statusText = '未识别到语音，请再试一次';
      });
    }
  }

  // ── 语音结束 → AI 解析 ──
  Future<void> _onSpeechDone(String text) async {
    setState(() {
      _state = _VoiceState.parsing;
      _statusText = '正在理解...';
    });

    final result = await _voiceService.parseVoiceText(
      text,
      context: widget.inputContext,
    );

    if (!mounted) return;

    if (result.hasAmbiguity) {
      setState(() {
        _state = _VoiceState.ambiguity;
        _currentResult = result;
        _statusText = result.ambiguity!.message;
      });
    } else {
      _mergeResult(result);
      // 如果是基金且缺代码但有名称 → 自动搜索
      final r = _currentResult!;
      if ((r.isFund || widget.inputContext == 'fund') &&
          r.fundCode == null &&
          (r.fundName != null && r.fundName!.isNotEmpty)) {
        await _autoSearchFund(r.fundName!);
      } else {
        setState(() => _state = _VoiceState.result);
      }
    }
  }

  // ── 自动搜索基金代码 ──
  Future<void> _autoSearchFund(String name) async {
    setState(() {
      _state = _VoiceState.parsing;
      _statusText = '正在查找「$name」相关基金...';
    });

    try {
      final results = await _fundApi.searchFund(name);
      if (!mounted) return;
      // 无论是否有结果，都进入 fundSearch 状态（空结果时显示提示）
      setState(() {
        _fundCandidates = results.take(6).toList();
        _state = _VoiceState.fundSearch;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fundCandidates = [];
        _state = _VoiceState.fundSearch;
      });
    }
  }

  // ── 用户选择基金候选 ──
  void _selectFundCandidate(Map<String, String> fund) {
    final r = _currentResult!;
    _currentResult = VoiceParseResult(
      type: 'fund',
      correctedText: r.correctedText,
      fundCode: fund['code'],
      fundName: fund['name'],
      shares: r.shares,
      costNav: r.costNav,
      totalAmount: r.totalAmount,
      symbol: r.symbol,
      stockName: r.stockName,
      market: r.market,
      costPrice: r.costPrice,
      missingFields: r.missingFields.where((f) => f != 'fundCode').toList(),
      confidence: r.confidence,
      rawText: r.rawText,
    );
    _fundCandidates = [];
    setState(() => _state = _VoiceState.result);
  }

  // ── 合并新结果到累积结果 ──
  void _mergeResult(VoiceParseResult newResult) {
    final prev = _currentResult;
    if (prev == null) {
      _currentResult = newResult;
      return;
    }

    // 新结果覆盖旧结果中为null的字段
    _currentResult = VoiceParseResult(
      type: newResult.type != 'ambiguous' ? newResult.type : prev.type,
      correctedText: '${prev.correctedText}；${newResult.correctedText}',
      fundCode: newResult.fundCode ?? prev.fundCode,
      fundName: newResult.fundName ?? prev.fundName,
      shares: newResult.shares ?? prev.shares,
      costNav: newResult.costNav ?? prev.costNav,
      totalAmount: newResult.totalAmount ?? prev.totalAmount,
      symbol: newResult.symbol ?? prev.symbol,
      stockName: newResult.stockName ?? prev.stockName,
      market: newResult.market ?? prev.market,
      costPrice: newResult.costPrice ?? prev.costPrice,
      // 重新计算缺失字段
      missingFields: _calcMissingFields(newResult, prev),
      confidence: (newResult.confidence + prev.confidence) / 2,
      rawText: '${prev.rawText}；${newResult.rawText}',
    );
  }

  List<String> _calcMissingFields(VoiceParseResult newR, VoiceParseResult prev) {
    final missing = <String>[];
    final isFund = (newR.type == 'fund') ||
        (newR.type == 'ambiguous' && prev.type == 'fund') ||
        widget.inputContext == 'fund';

    if (isFund) {
      if ((newR.fundCode ?? prev.fundCode) == null) missing.add('fundCode');
      if ((newR.shares ?? prev.shares) == null &&
          (newR.totalAmount ?? prev.totalAmount) == null) {
        missing.add('shares');
      }
      if ((newR.costNav ?? prev.costNav) == null) missing.add('costNav');
    } else {
      if ((newR.symbol ?? prev.symbol) == null) missing.add('symbol');
      if ((newR.market ?? prev.market) == null) missing.add('market');
      if ((newR.shares ?? prev.shares) == null) missing.add('shares');
      if ((newR.costPrice ?? prev.costPrice) == null) missing.add('costPrice');
    }
    return missing;
  }

  // ── 用户选择歧义选项 ──
  void _selectAmbiguityOption(Map<String, String> option) {
    final result = _currentResult!;
    final resolved = VoiceParseResult(
      type: option['type'] ?? result.type,
      correctedText: result.correctedText,
      fundCode: option['fundCode'] ?? result.fundCode,
      fundName: option['fundName'] ?? result.fundName,
      shares: result.shares,
      costNav: result.costNav,
      totalAmount: result.totalAmount,
      symbol: option['symbol'] ?? result.symbol,
      stockName: option['stockName'] ?? result.stockName,
      market: option['market'] ?? result.market,
      costPrice: result.costPrice,
      missingFields: result.missingFields,
      confidence: result.confidence,
      rawText: result.rawText,
    );
    _currentResult = resolved;

    // 歧义解决后显示结果预览
    setState(() {
      _state = _VoiceState.result;
    });
  }

  // ── 用户确认使用 ──
  void _confirmResult() {
    if (_currentResult != null) {
      widget.onConfirm(_currentResult!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      constraints: BoxConstraints(minHeight: screenHeight * 0.45),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: screenHeight * 0.4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽手柄
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // 标题
            Text(
              widget.inputContext == 'fund' ? '语音添加基金' : '语音添加股票',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // 提示文字（始终显示，除了结果预览状态）
            if (_state != _VoiceState.result)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _getHintText(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),

            // ── 结果预览卡片（核心闭环）──
            if (_state == _VoiceState.result && _currentResult != null) ...[
              const SizedBox(height: 4),
              _buildResultPreview(),
            ],

            // 识别文字显示（录音中/解析中）
            if ((_state == _VoiceState.listening || _state == _VoiceState.parsing) &&
                _recognizedText.isNotEmpty)
              _buildRecognizedTextBox(),

            const SizedBox(height: 20),

            // 状态文字（非 result 状态）
            if (_state != _VoiceState.result)
              Text(
                _statusText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _state == _VoiceState.error
                      ? AppColors.error
                      : _state == _VoiceState.listening
                          ? AppColors.primary
                          : AppColors.textSecondary,
                ),
              ),

            const SizedBox(height: 16),

            // 歧义选项
            if (_state == _VoiceState.ambiguity &&
                _currentResult?.ambiguity != null)
              _buildAmbiguityOptions(),

            // 基金候选列表（自动搜索结果）
            if (_state == _VoiceState.fundSearch)
              _buildFundCandidates(),

            // 麦克风按钮 / Loading / 操作按钮
            if (_state == _VoiceState.result)
              _buildResultActions()
            else if (_state != _VoiceState.ambiguity &&
                _state != _VoiceState.fundSearch)
              _buildCenterWidget(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _getHintText() {
    if (widget.inputContext == 'fund') {
      return '试试说："添加基金000001，买了5000份，净值1.2345"';
    }
    return '试试说："买了200股茅台，成本1800"';
  }

  // ── 识别文字显示框 ──
  Widget _buildRecognizedTextBox() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      padding: const EdgeInsets.all(14),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '识别文字',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textHint,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _recognizedText.isEmpty ? '...' : _recognizedText,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── 结果预览卡片 ──
  Widget _buildResultPreview() {
    final r = _currentResult!;
    final isFund = r.isFund || widget.inputContext == 'fund';
    final hasMissing =
        r.missingFields.isNotEmpty && !r.missingFields.contains('all');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasMissing
              ? Colors.orange.withOpacity(0.4)
              : AppColors.success.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Icon(
                hasMissing ? Icons.info_outline : Icons.check_circle_outline,
                size: 18,
                color: hasMissing ? Colors.orange : AppColors.success,
              ),
              const SizedBox(width: 8),
              Text(
                hasMissing ? '部分识别，可继续补充' : '识别完成',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: hasMissing ? Colors.orange[800] : AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 已识别的字段
          if (isFund) ...[
            _buildFieldRow('基金代码', r.fundCode, r.missingFields.contains('fundCode')),
            _buildFieldRow('基金名称', r.fundName, false),
            _buildFieldRow('持仓份额', r.shares?.toStringAsFixed(2), r.missingFields.contains('shares')),
            _buildFieldRow('成本净值', r.costNav?.toStringAsFixed(4), r.missingFields.contains('costNav')),
            if (r.totalAmount != null)
              _buildFieldRow('投入金额', '${r.totalAmount!.toStringAsFixed(2)}元', false),
          ] else ...[
            _buildFieldRow('市场', _marketLabel(r.market), r.missingFields.contains('market')),
            _buildFieldRow('股票代码', r.symbol, r.missingFields.contains('symbol')),
            _buildFieldRow('股票名称', r.stockName, false),
            _buildFieldRow('持仓股数', r.shares?.toStringAsFixed(0), r.missingFields.contains('shares')),
            _buildFieldRow('成本价', r.costPrice?.toStringAsFixed(2), r.missingFields.contains('costPrice')),
          ],

          // 缺失字段提示
          if (hasMissing) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mic, size: 14, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '还缺：${r.missingFields.map(_fieldLabel).join("、")}，点下方麦克风继续说',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFieldRow(String label, String? value, bool isMissing) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isMissing || value == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Text(
                '待补充',
                style: TextStyle(fontSize: 12, color: Colors.orange[700]),
              ),
            )
          else
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
        ],
      ),
    );
  }

  // ── 结果页操作按钮 ──
  Widget _buildResultActions() {
    final hasMissing = _currentResult != null &&
        _currentResult!.missingFields.isNotEmpty &&
        !_currentResult!.missingFields.contains('all');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // 继续语音补充（麦克风按钮）
          if (hasMissing) ...[
            GestureDetector(
              onTap: _startListening,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 26),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '继续说，补充信息',
              style: TextStyle(fontSize: 12, color: Colors.orange[700]),
            ),
            const SizedBox(height: 16),
          ],

          // 确认使用 / 先用已有信息
          Row(
            children: [
              // 取消
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: AppColors.border),
                  ),
                  child: const Text(
                    '取消',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 确认
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _confirmResult,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    hasMissing ? '填入已识别信息，返回表单补全' : '确认填入',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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

  String _fieldLabel(String field) {
    switch (field) {
      case 'fundCode':
        return '基金代码';
      case 'shares':
        return '份额/股数';
      case 'costNav':
        return '成本净值';
      case 'symbol':
        return '股票代码';
      case 'market':
        return '市场';
      case 'costPrice':
        return '成本价';
      default:
        return field;
    }
  }

  String? _marketLabel(String? market) {
    switch (market) {
      case 'A':
        return 'A股';
      case 'HK':
        return '港股';
      case 'US':
        return '美股';
      default:
        return null;
    }
  }

  Widget _buildCenterWidget() {
    switch (_state) {
      case _VoiceState.parsing:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        );

      case _VoiceState.error:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ElevatedButton.icon(
            onPressed: _startListening,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重试'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        );

      case _VoiceState.listening:
        return GestureDetector(
          onTap: _stopListening,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (_, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: child,
              );
            },
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.error.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.stop, color: Colors.white, size: 32),
            ),
          ),
        );

      default: // idle
        return GestureDetector(
          onTap: _startListening,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.mic, color: Colors.white, size: 32),
          ),
        );
    }
  }

  Widget _buildAmbiguityOptions() {
    final options = _currentResult!.ambiguity!.options;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: options
            .map((opt) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _selectAmbiguityOption(opt),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                            color: AppColors.primary.withOpacity(0.4)),
                      ),
                      child: Text(
                        opt['label'] ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ── 基金候选列表 ──
  final _manualCodeCtrl = TextEditingController();

  Widget _buildFundCandidates() {
    final name = _currentResult?.fundName ?? '';
    final hasResults = _fundCandidates.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasResults ? Icons.search : Icons.search_off,
                size: 16,
                color: hasResults ? AppColors.primary : Colors.orange,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hasResults
                      ? '找到以下「$name」相关基金，请确认选择：'
                      : '未找到「$name」相关基金，请手动输入代码：',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: hasResults ? AppColors.textPrimary : Colors.orange[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 有候选结果时显示列表
          if (hasResults)
            ..._fundCandidates.map((fund) => InkWell(
                  onTap: () => _selectFundCandidate(fund),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            fund['code'] ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            fund['name'] ?? '',
                            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.check_circle_outline, size: 18, color: AppColors.primary),
                      ],
                    ),
                  ),
                )),

          // 手动输入代码（无结果时直接显示，有结果时作为备用）
          if (!hasResults) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualCodeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      hintText: '输入6位基金代码，如 000001',
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _confirmManualCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('确认', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],

          if (hasResults)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton(
                onPressed: () => setState(() => _state = _VoiceState.result),
                child: Text(
                  '没有合适的，跳过手动输入',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmManualCode() {
    final code = _manualCodeCtrl.text.trim();
    if (code.isEmpty) return;
    _selectFundCandidate({'code': code, 'name': _currentResult?.fundName ?? ''});
  }
}

enum _VoiceState {
  idle,
  listening,
  parsing,
  result,
  fundSearch,
  ambiguity,
  error,
}
