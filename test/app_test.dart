import 'package:flutter_test/flutter_test.dart';
import 'package:text_shower/app.dart';
import 'package:text_shower/data/doc_repository.dart';

void main() {
  testWidgets('启动后显示文档库首页', (tester) async {
    await tester.pumpWidget(
      TextShowerApp(repository: MemoryDocRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text('文字展示'), findsOneWidget);
    expect(find.text('还没有文稿'), findsOneWidget);
    expect(find.text('新建文稿'), findsOneWidget);
  });
}
