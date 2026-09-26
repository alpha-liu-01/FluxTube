/// Width cutoffs for the tablet layout.
///
/// Callers pass the width they are laying out. The shell passes the window
/// width for the rail. Card grids and the watch page pass the content width
/// once a rail sits beside that content.
class WindowLayout {
  static const double sideRailMinWidth = 720;
  static const double watchSplitMinWidth = 1000;
  static const double threeColumnMinWidth = 1100;
  static const double shortsFiveColumnMinWidth = 900;

  static bool useSideRail(double width) => width >= sideRailMinWidth;

  /// 1 under [sideRailMinWidth], 2 through 1099, 3 at [threeColumnMinWidth].
  static int cardColumns(double width) {
    if (width >= threeColumnMinWidth) return 3;
    if (width >= sideRailMinWidth) return 2;
    return 1;
  }

  static bool useWatchSplit(double width) => width >= watchSplitMinWidth;

  /// 3 below [sideRailMinWidth], 4 from there, 5 from
  /// [shortsFiveColumnMinWidth], 6 at [threeColumnMinWidth].
  static int shortsColumns(double width) {
    if (width >= threeColumnMinWidth) return 6;
    if (width >= shortsFiveColumnMinWidth) return 5;
    if (width >= sideRailMinWidth) return 4;
    return 3;
  }
}
