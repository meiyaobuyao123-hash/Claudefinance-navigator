import 'package:flutter_test/flutter_test.dart';
import 'package:finance_navigator/core/utils/uuid_util.dart';

void main() {
  group('generateUuid', () {
    // UUID v4 格式: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
    // y = 8, 9, a, b
    final uuidV4Pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    test('生成的 UUID 符合 v4 格式', () {
      final uuid = generateUuid();
      expect(uuidV4Pattern.hasMatch(uuid), isTrue,
          reason: '生成的 UUID "$uuid" 不符合 v4 格式');
    });

    test('UUID 长度为 36 个字符', () {
      expect(generateUuid().length, 36);
    });

    test('UUID 版本位为 4', () {
      final uuid = generateUuid();
      expect(uuid[14], '4');
    });

    test('UUID variant 位为 8/9/a/b', () {
      final uuid = generateUuid();
      expect(['8', '9', 'a', 'b'], contains(uuid[19]));
    });

    test('连续生成 100 个 UUID 全部唯一', () {
      final uuids = List.generate(100, (_) => generateUuid());
      final unique = uuids.toSet();
      expect(unique.length, 100);
    });

    test('连续生成 100 个 UUID 全部符合 v4 格式', () {
      for (var i = 0; i < 100; i++) {
        final uuid = generateUuid();
        expect(uuidV4Pattern.hasMatch(uuid), isTrue,
            reason: '第 $i 个 UUID "$uuid" 不符合格式');
      }
    });

    test('UUID 包含 4 个连字符', () {
      final uuid = generateUuid();
      expect('-'.allMatches(uuid).length, 4);
    });
  });
}
