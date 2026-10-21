
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  static final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final isDarkMode = prefs.getBool('isDarkMode') ?? false;

    mode.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> toggle() async {
    final isDarkMode = mode.value != ThemeMode.dark;

    mode.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }
}
