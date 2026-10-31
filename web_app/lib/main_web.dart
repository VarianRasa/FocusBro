import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:focusbro_web/src/core/app.dart';
import 'package:flutter/material.dart';

void main() {
  // Configure web-specific settings
  setUrlStrategy(PathUrlStrategy());

  runApp(const FocusBroWebApp());
}
