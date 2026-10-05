import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// "iPaniX" wordmark in the squared display face.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      'iPaniX',
      style: TextStyle(
        fontFamily: wordmarkFont,
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: size * 0.04,
        color: AppColors.of(context).ink,
        height: 1,
      ),
    );
  }
}
