import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../utils/platform_utils.dart';

class PlatformLoadingIndicator extends StatelessWidget {
  final Color? color;
  final double? size;
  final EdgeInsetsGeometry? padding;

  const PlatformLoadingIndicator({
    super.key,
    this.color,
    this.size,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultColor = color ?? theme.colorScheme.primary;
    final defaultSize = size ?? _getPlatformSpecificSize();
    final defaultPadding = padding ?? _getPlatformSpecificPadding();

    return Padding(
      padding: defaultPadding,
      child: _buildPlatformSpecificIndicator(defaultColor, defaultSize),
    );
  }

  Widget _buildPlatformSpecificIndicator(Color color, double size) {
    if (PlatformUtils.isIOS) {
      // iOS - CupertinoActivityIndicator
      return CupertinoActivityIndicator(
        color: color,
        radius: size / 2,
      );
    } else if (PlatformUtils.isAndroid) {
      // Android - CircularProgressIndicator
      return SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          color: color,
          strokeWidth: 3.0,
        ),
      );
    } else {
      return SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          color: color,
          strokeWidth: 3.0,
        ),
      );
    }
  }

  double _getPlatformSpecificSize() {
    if (PlatformUtils.isIOS) {
      return 20.0;
    } else if (PlatformUtils.isAndroid) {
      return 24.0;
    } else {
      return 24.0;
    }
  }

  EdgeInsetsGeometry _getPlatformSpecificPadding() {
    if (PlatformUtils.isIOS) {
      return const EdgeInsets.all(20.0);
    } else if (PlatformUtils.isAndroid) {
      return const EdgeInsets.all(16.0);
    } else {
      return const EdgeInsets.all(16.0);
    }
  }
} 