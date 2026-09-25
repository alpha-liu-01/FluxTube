import 'package:flutter/widgets.dart';

/// A row of [columns] cells. [children] fill from the left. The remaining
/// cells stay empty so a short last row does not stretch one card.
class CardRow extends StatelessWidget {
  const CardRow({
    super.key,
    required this.columns,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final int columns;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var column = 0; column < columns; column++) ...[
            if (column > 0) const SizedBox(width: 12),
            Expanded(
              child: column < children.length
                  ? children[column]
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}
