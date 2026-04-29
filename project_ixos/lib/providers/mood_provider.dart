import 'package:flutter/material.dart';
import '../models/mood.dart';

class MoodProvider with ChangeNotifier {
  Mood? _currentMood;
  
  Mood? get currentMood => _currentMood;

  void setMood(Mood mood) {
    _currentMood = mood;
    notifyListeners();
  }

  Color get backgroundColor => const Color(0xFF09090B);
  Color get navBackground => const Color(0xFF18181B);
  Color get cardBackground => const Color(0xFF27272A);
  Color get borderColor => const Color(0xFF3F3F46);

  List<Color> get currentGradient {
    if (_currentMood != null) {
      return _currentMood!.gradient;
    }
    return [const Color(0xFF27272A), const Color(0xFF09090B)];
  }
}
