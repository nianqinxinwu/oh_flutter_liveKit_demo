import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_live_ohos/main.dart';

void main() {
  testWidgets('首页可打开参数配置并显示测试环境入口', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('LiveKit OHOS Demo'), findsOneWidget);
    expect(find.text('参数配置'), findsOneWidget);

    await tester.tap(find.text('参数配置'));
    await tester.pumpAndSettle();

    expect(find.text('测试环境测试'), findsWidgets);
    expect(find.text('点击后可选择 Token1 或 Token2，并直接使用对应预置参数连接 LiveKit。'), findsOneWidget);
    expect(find.text('获取 Token 并连接'), findsOneWidget);
  });
}
