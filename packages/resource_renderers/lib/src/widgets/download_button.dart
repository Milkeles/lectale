import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:resource_renderers/src/copy.dart';
import 'package:resource_renderers/src/host.dart';

/// The Download button: opens the file's address in the browser, where the
/// server shows or saves it by its safe-type rules. Its name says which file.
class DownloadButton extends StatelessWidget {
  /// Creates a button that downloads [target], named after [fileName].
  const DownloadButton({
    required this.host,
    required this.target,
    required this.fileName,
    this.label = ViewerCopy.download,
    super.key,
  });

  /// Opens the address.
  final ResourceHost host;

  /// What to download.
  final ResourceTarget target;

  /// The button's text: Download, or Download PDF for a PDF. A kind without
  /// a viewer must offer Download (RENDERING_REQUIREMENTS).
  final String label;

  /// The file's name, for the accessible name "Download {fileName}".
  final String fileName;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    // The file's name rides as the hint, so the button keeps its own focus
    // semantics: a `semanticLabel` on the button would hide them, and the
    // name still starts with the visible text (WCAG 2.5.3).
    child: Semantics(
      hint: fileName,
      child: DcButton(
        variant: DcButtonVariant.outline,
        onPressed: () => host.open(host.addressOf(target)),
        child: Text(label),
      ),
    ),
  );
}
