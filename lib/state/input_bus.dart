import 'package:flutter/foundation.dart';

/// Global local-input state shared between the touch overlay widgets
/// (joystick, buttons) and the running mini-game.
///
/// Exists exactly one at a time (one session, one game), so a top-level
/// singleton keeps plumbing simple.
class InputBus extends ChangeNotifier {
  double x = 0;
  double y = 0;
  bool action = false;
  bool dash = false;
  int mash = 0;

  void setJoystick(double dx, double dy) {
    x = dx;
    y = dy;
    notifyListeners();
  }

  void setAction(bool value) {
    action = value;
    notifyListeners();
  }

  void setDash(bool value) {
    dash = value;
    notifyListeners();
  }

  void tapMash() {
    mash++;
    notifyListeners();
  }

  void reset() {
    x = 0;
    y = 0;
    action = false;
    dash = false;
    mash = 0;
    notifyListeners();
  }
}

final InputBus inputBus = InputBus();
