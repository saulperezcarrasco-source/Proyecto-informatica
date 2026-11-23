import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// The original user-supplied PNG stays untouched. Clip only its outer white
/// margins at layout time so the full mark and lettering are readable.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.width = 320});
  final double width;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Ruta RD Offline',
    image: true,
    child: SizedBox(
      width: width,
      height: width / 1.2,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: width / .72,
          maxHeight: width / .72,
          child: Image.asset(
            'assets/brand/ruta_rd.png',
            width: width / .72,
            height: width / .72,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
      ),
    ),
  );
}

class BrandLoading extends StatelessWidget {
  const BrandLoading({super.key});
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLogo(
              width: math.min(360, MediaQuery.sizeOf(context).width - 48),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: Color(0xff009688)),
            const SizedBox(height: 20),
            const Text(
              'Preparando tu mapa sin conexión…',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xff064e46)),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Keep the branded launch legible while HomeScreen prepares in parallel.
/// This runs once per process and never blocks the UI thread.
class BrandLaunch extends StatefulWidget {
  const BrandLaunch({super.key, required this.child});
  final Widget child;
  @override
  State<BrandLaunch> createState() => _BrandLaunchState();
}

class _BrandLaunchState extends State<BrandLaunch> {
  bool show = true;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      timer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => show = false);
      });
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      IgnorePointer(
        ignoring: !show,
        child: AnimatedOpacity(
          opacity: show ? 1 : 0,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 250),
          child: TickerMode(enabled: show, child: const BrandLoading()),
        ),
      ),
    ],
  );
}
