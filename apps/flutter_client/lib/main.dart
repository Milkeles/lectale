import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lectale/src/app/api_config.dart';
import 'package:lectale/src/app/app.dart';
import 'package:lectale/src/app/web_semantics.dart';

void main() {
  // Fail at start-up, with the fix in the message, rather than on the first
  // request of a native build that has no API address.
  resolveApiBaseUrl();
  registerDcLicenses();
  WidgetsFlutterBinding.ensureInitialized();
  // Before any text field can take focus; see the function for why.
  ensureWebSemantics();
  runApp(const ProviderScope(child: LectaleApp()));
}
