import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  bool _running = false;

  bool get running => _running;

  void toggleRunning() {
    _running = !_running;
    notifyListeners();
  }
}
