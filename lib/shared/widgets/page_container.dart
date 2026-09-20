import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

class PageContainer extends StatelessWidget {
  const PageContainer({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppConstants.pageMaxWidth,
          ),
          child: child,
        ),
      ),
    );
  }
}
