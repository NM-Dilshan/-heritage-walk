import 'package:flutter/material.dart';

class HeritageLoading extends StatelessWidget {
  const HeritageLoading({super.key, this.size = 24, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    child: SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
    ),
  );
}
