import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

// AI NOTE: A reusable loading indicator widget using the SpinKit library.
class LoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;

  const LoadingIndicator({super.key, this.size = 40, this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SpinKitPulse(
        size: size,
        color: color ?? Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
