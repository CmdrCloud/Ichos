import 'package:flutter/material.dart';

class Mood {
  final String id;
  final String name;
  final String displayName;
  final String iconName;
  final String gradientStart;
  final String gradientEnd;
  final int sortOrder;

  Mood({
    required this.id,
    required this.name,
    required this.displayName,
    required this.iconName,
    required this.gradientStart,
    required this.gradientEnd,
    required this.sortOrder,
  });

  factory Mood.fromJson(Map<String, dynamic> json) {
    return Mood(
      id: json['id'],
      name: json['name'],
      displayName: json['display_name'],
      iconName: json['icon_name'],
      gradientStart: json['gradient_start'],
      gradientEnd: json['gradient_end'],
      sortOrder: json['sort_order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
      'icon_name': iconName,
      'gradient_start': gradientStart,
      'gradient_end': gradientEnd,
      'sort_order': sortOrder,
    };
  }

  List<Color> get gradient {
    return [
      _parseColor(gradientStart),
      _parseColor(gradientEnd),
    ];
  }

  Color _parseColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
