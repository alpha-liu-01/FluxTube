import 'package:flutter_test/flutter_test.dart';
import 'package:fluxtube/core/window_layout.dart';

void main() {
  test('side rail starts at 720', () {
    expect(WindowLayout.useSideRail(719), isFalse);
    expect(WindowLayout.useSideRail(720), isTrue);
  });

  test('watch split starts at 1000', () {
    expect(WindowLayout.useWatchSplit(999), isFalse);
    expect(WindowLayout.useWatchSplit(1000), isTrue);
  });

  test('card columns follow 720 and 1100', () {
    expect(WindowLayout.cardColumns(719), 1);
    expect(WindowLayout.cardColumns(720), 2);
    expect(WindowLayout.cardColumns(1099), 2);
    expect(WindowLayout.cardColumns(1100), 3);
  });
}
