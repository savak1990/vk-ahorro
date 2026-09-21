import 'package:flutter/material.dart';

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    super.key,
    required this.children,
    this.margin,
    this.padding = const EdgeInsets.symmetric(horizontal: 0),
    this.backgroundColor,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      margin: margin ?? const EdgeInsets.only(bottom: 32),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: _intersperseDividers(context, children),
        ),
      ),
    );
  }

  List<Widget> _intersperseDividers(BuildContext context, List<Widget> items) {
    if (items.isEmpty) return const <Widget>[];
    final DividerThemeData dividerTheme = DividerTheme.of(context);
    final List<Widget> result = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i != items.length - 1) {
        result.add(
          Divider(
            height: dividerTheme.space ?? 1,
            thickness: dividerTheme.thickness ?? 1,
            indent: 16,
            endIndent: 16,
          ),
        );
      }
    }
    return result;
  }
}

