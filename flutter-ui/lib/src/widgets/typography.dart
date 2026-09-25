 import 'package:flutter/material.dart';

 /// Headline Emphasized Large
 ///
 class HeadlineEmphasizedLarge extends StatelessWidget {
   final String text;
   final EdgeInsetsGeometry? padding;
   final TextAlign? textAlign;

   const HeadlineEmphasizedLarge({
     super.key,
     required this.text,
     this.padding,
     this.textAlign,
   });

   @override
   Widget build(BuildContext context) {
     final theme = Theme.of(context);
     final colorScheme = theme.colorScheme;
     final textTheme = theme.textTheme;

     final style = textTheme.headlineMedium?.copyWith(
       fontWeight: FontWeight.w700,
       color: colorScheme.onSurface,
       letterSpacing: -0.5,
       fontSize: 32,
     );

     final child = Text(text, style: style, textAlign: textAlign);
     if (padding != null) {
       return Padding(padding: padding!, child: child);
     }
     return child;
   }
 }

 /// Title Emphasized Large
 ///
 class TitleEmphasizedLarge extends StatelessWidget {
   final String text;
   final EdgeInsetsGeometry? padding;
   final TextAlign? textAlign;

   const TitleEmphasizedLarge({
     super.key,
     required this.text,
     this.padding,
     this.textAlign,
   });

   @override
   Widget build(BuildContext context) {
     final theme = Theme.of(context);
     final colorScheme = theme.colorScheme;
     final textTheme = theme.textTheme;

     final style = textTheme.titleLarge?.copyWith(
       fontWeight: FontWeight.w600,
       color: colorScheme.onSurface,
       letterSpacing: 0.15,
     );

     final child = Text(text, style: style, textAlign: textAlign);
     if (padding != null) {
       return Padding(padding: padding!, child: child);
     }
     return child;
   }
 }

 /// Label Emphasized Medium
 ///
 class LabelEmphasizedMedium extends StatelessWidget {
   final String text;
   final EdgeInsetsGeometry? padding;
   final TextAlign? textAlign;

   const LabelEmphasizedMedium({
     super.key,
     required this.text,
     this.padding,
     this.textAlign,
   });

   @override
   Widget build(BuildContext context) {
     final theme = Theme.of(context);
     final colorScheme = theme.colorScheme;
     final textTheme = theme.textTheme;

     final style = textTheme.titleMedium?.copyWith(
       fontWeight: FontWeight.w500,
       color: colorScheme.onSurfaceVariant,
       letterSpacing: 0.15,
     );

     final child = Text(text, style: style, textAlign: textAlign);
     if (padding != null) {
       return Padding(padding: padding!, child: child);
     }
     return child;
   }
 }

/// Title Emphasized Medium
///
class TitleEmphasizedMedium extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry? padding;
  final TextAlign? textAlign;

  const TitleEmphasizedMedium({
    super.key,
    required this.text,
    this.padding,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final style = textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
      letterSpacing: 0.1,
    );

    final child = Text(text, style: style, textAlign: textAlign);
    if (padding != null) {
      return Padding(padding: padding!, child: child);
    }
    return child;
  }
}

