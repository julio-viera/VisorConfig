import 'package:flutter/material.dart';

import '../app_info.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 24});
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/app_icon.png',
    width: size,
    height: size,
    filterQuality: FilterQuality.high,
    semanticLabel: appName,
  );
}
