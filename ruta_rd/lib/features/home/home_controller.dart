import 'package:flutter/foundation.dart';

enum RegionState { loading, ready, error }

/// Estado provisional de interfaz. La carga real se integrará en la fase 2.
class HomeController extends ChangeNotifier {
  HomeController({this.state = RegionState.ready, this.onRetry});

  RegionState state;
  final VoidCallback? onRetry;

  void retry() {
    if (onRetry != null) {
      onRetry!();
    } else {
      state = RegionState.ready;
      notifyListeners();
    }
  }
}
