import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class AdaptiveSegmentedSingleChoiceButton<T extends Object>
    extends StatelessWidget {
  final List<T> items;
  final T selectedItem;
  final ValueChanged<T> onChanged;
  final Widget Function(T) itemWidgetBuilder;

  const AdaptiveSegmentedSingleChoiceButton({
    super.key,
    required this.items,
    required this.selectedItem,
    required this.onChanged,
    required this.itemWidgetBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoSlidingSegmentedControl<T>(
        children: {for (var item in items) item: itemWidgetBuilder(item)},
        groupValue: selectedItem,
        onValueChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
      );
    } else {
      return SegmentedButton<T>(
        multiSelectionEnabled: false,
        emptySelectionAllowed: false,
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(0, 24), // Reduce height from default ~48
          maximumSize: const Size(double.infinity, 24),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          textStyle: const TextStyle(fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        segments: items.map((item) {
          return ButtonSegment(value: item, label: itemWidgetBuilder(item));
        }).toList(),
        selected: {selectedItem},
        onSelectionChanged: (value) {
          onChanged(value.first);
        },
      );
    }
  }
}
