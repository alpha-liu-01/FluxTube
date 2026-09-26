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

  test('shorts columns stay 3 below 720, then 4, 5, and 6', () {
    expect(WindowLayout.shortsColumns(719), 3);
    expect(WindowLayout.shortsColumns(720), 4);
    expect(WindowLayout.shortsColumns(899), 4);
    expect(WindowLayout.shortsColumns(900), 5);
    expect(WindowLayout.shortsColumns(1099), 5);
    expect(WindowLayout.shortsColumns(1100), 6);
  });
}
