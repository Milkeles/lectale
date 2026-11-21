import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lectale/src/app/api_config.dart';
import 'package:lectale/src/app/app.dart';

void main() {
  // Fail at start-up, with the fix in the message, rather than on the first
  // request of a native build that has no API address.
  resolveApiBaseUrl();
  registerDcLicenses();
  runApp(const ProviderScope(child: LectaleApp()));
}
