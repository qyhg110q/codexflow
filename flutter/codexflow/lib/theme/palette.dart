import 'package:flutter/material.dart';

class Palette {
  static const canvas = Color.fromRGBO(247, 247, 244, 1);
  static const shell = Color.fromRGBO(238, 238, 234, 1);
  static const surface = Color.fromRGBO(255, 255, 255, 0.88);
  static const surfaceStrong = Color.fromRGBO(255, 255, 255, 1);
  static const ink = Color.fromRGBO(32, 37, 42, 1);
  static const mutedInk = Color.fromRGBO(111, 120, 125, 1);
  static const faintInk = Color.fromRGBO(154, 162, 167, 1);
  static const accent = Color.fromRGBO(37, 144, 93, 1);
  static const accent2 = Color.fromRGBO(217, 121, 45, 1);
  static const softBlue = Color.fromRGBO(53, 116, 183, 1);
  static const success = Color.fromRGBO(37, 144, 93, 1);
  static const warning = Color.fromRGBO(217, 121, 45, 1);
  static const danger = Color.fromRGBO(185, 74, 72, 1);
  static const panelStrong = Color.fromRGBO(255, 255, 255, 0.92);
  static const line = Color.fromRGBO(29, 35, 40, 0.09);

  static const terminalBackground = Color.fromRGBO(26, 33, 38, 1);
  static const terminalText = Color.fromRGBO(219, 227, 230, 1);
  static const terminalMuted = Color.fromRGBO(158, 173, 179, 1);
  static const codeBackground = Color.fromRGBO(31, 36, 41, 1);
  static const codeText = Color.fromRGBO(230, 235, 237, 1);

  static const dashboardGradient = LinearGradient(
    colors: [canvas, Color.fromRGBO(250, 250, 248, 1), shell],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
