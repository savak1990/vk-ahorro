import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class AdaptiveDropdown<T> extends StatelessWidget {
  final List<T> items;
  final T selectedItem;
  final ValueChanged<T?> onChanged;
  final String Function(T) itemLabelBuilder;

  const AdaptiveDropdown({
    super.key,
    required this.items,
    required this.selectedItem,
    required this.onChanged,
    required this.itemLabelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return GestureDetector(
        onTap: () => _showCupertinoActionSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            border: Border.all(color: CupertinoColors.systemGrey),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Text(
            itemLabelBuilder(selectedItem),
            style: const TextStyle(fontSize: 16.0),
          ),
        ),
      );
    } else {
      return DropdownButton<T>(
        value: selectedItem,
        items: items.map((item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(itemLabelBuilder(item)),
          );
        }).toList(),
        onChanged: onChanged,
      );
    }
  }

  void _showCupertinoActionSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        actions: items.map((item) {
          return CupertinoActionSheetAction(
            onPressed: () {
              onChanged(item);
              Navigator.of(context).pop(); // Dismiss the modal
            },
            child: Text(itemLabelBuilder(item)),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
