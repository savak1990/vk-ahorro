import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../utils/platform_utils.dart';

class PlatformAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final bool? centerTitle;

  const PlatformAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.centerTitle,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return _buildCupertinoNavigationBar(context);
    } else {
      return _buildMaterialAppBar(context);
    }
  }

  Widget _buildCupertinoNavigationBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return CupertinoNavigationBar(
      middle: title != null ? Text(
        title!,
        style: TextStyle(
          color: foregroundColor ?? colorScheme.onSurface,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ) : null,
      trailing: actions != null && actions!.isNotEmpty 
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: actions!,
          )
        : null,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: backgroundColor ?? colorScheme.surface,
      border: null, // Убираем границу для современного вида
    );
  }

  Widget _buildMaterialAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return AppBar(
      title: title != null ? Text(
        title!,
        style: TextStyle(
          color: foregroundColor ?? colorScheme.onSurface,
        ),
      ) : null,
      actions: actions,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: backgroundColor ?? colorScheme.surface,
      foregroundColor: foregroundColor ?? colorScheme.onSurface,
      elevation: elevation ?? 0,
      centerTitle: centerTitle ?? false,
    );
  }

  @override
  Size get preferredSize {
    if (PlatformUtils.isIOS) {
      return const Size.fromHeight(44.0); // iOS стандартная высота
    } else {
      return const Size.fromHeight(kToolbarHeight); // Material Design высота
    }
  }
} 