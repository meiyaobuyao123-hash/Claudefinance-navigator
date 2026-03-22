import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:finance_navigator/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('删除账户按钮存在且弹窗流程正确', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 切到"我的"Tab（第4个）
    final myTab = find.text('我的');
    if (myTab.evaluate().isNotEmpty) {
      await tester.tap(myTab.last);
      await tester.pumpAndSettle();
    }

    // 滚动找到"删除账户"按钮
    final deleteBtn = find.text('删除账户');
    if (deleteBtn.evaluate().isEmpty) {
      // 可能需要滚动
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
    }

    // 验证按钮存在
    expect(find.text('删除账户'), findsOneWidget);
    expect(find.text('永久删除账户及所有数据'), findsOneWidget);
    print('✅ 删除账户按钮存在');

    // 点击删除账户
    await tester.tap(find.text('删除账户'));
    await tester.pumpAndSettle();

    // 验证第一步确认弹窗
    expect(find.text('此操作将永久删除你的账户及所有关联数据，包括：\n\n'
        '  - 基金持仓记录\n'
        '  - 股票持仓记录\n'
        '  - 自选股列表\n'
        '  - 持仓走势快照\n'
        '  - 本地缓存数据\n\n'
        '删除后数据无法恢复，确定要继续吗？'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('继续删除'), findsOneWidget);
    print('✅ 第一步确认弹窗正确');

    // 点击取消，验证弹窗关闭
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('继续删除'), findsNothing);
    print('✅ 取消后弹窗正确关闭');

    // 再次点击删除账户，这次走完整流程
    await tester.tap(find.text('删除账户'));
    await tester.pumpAndSettle();

    // 点击继续删除
    await tester.tap(find.text('继续删除'));
    await tester.pumpAndSettle();

    // 验证第二步确认弹窗
    expect(find.text('最终确认'), findsOneWidget);
    expect(find.text('请再次确认：删除后所有数据将无法找回。'), findsOneWidget);
    expect(find.text('我再想想'), findsOneWidget);
    expect(find.text('确认删除'), findsOneWidget);
    print('✅ 第二步确认弹窗正确');

    // 点击"我再想想"取消
    await tester.tap(find.text('我再想想'));
    await tester.pumpAndSettle();
    expect(find.text('最终确认'), findsNothing);
    print('✅ "我再想想"后弹窗正确关闭');

    print('🎉 删除账户 UI 流程测试全部通过！');
  });
}
