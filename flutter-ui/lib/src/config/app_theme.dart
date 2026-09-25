import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

CupertinoThemeData materialToCupertino(ThemeData theme) {
  return CupertinoThemeData(
    primaryColor: theme.colorScheme.primary,
    brightness: theme.brightness,
  );
}
