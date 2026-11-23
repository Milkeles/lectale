// The constants are the strings themselves; a comment on each would repeat it.
// ignore_for_file: public_member_api_docs

/// Fixed texts of the viewers (`docs/ux/screens/reader.md` §9 and
/// `docs/ux/screens/course.md` §9).
abstract final class ViewerCopy {
  static const String download = 'Download';
  static const String copy = 'Copy';
  static const String copied = 'Copied';
  static const String zoomIn = 'Zoom in';
  static const String zoomOut = 'Zoom out';
  static const String resetZoom = 'Reset zoom';
  static const String folder = 'Folder';
  static const String emptyFolder = 'This folder is empty.';
  static const String noFile = 'This item has no file to open.';
  static const String imageFailed = "This image can't be shown.";
  static const String formulaAsWritten = 'Formula, as written';
  static const String openLink = 'Open link';
  static const String watchOnYouTube = 'Watch on YouTube';
  static const String watchOnVimeo = 'Watch on Vimeo';
  static const String downloadPdf = 'Download PDF';
  static const String unknownType = "Lectale can't show this type of file.";
  static const String tooLarge = 'This file is too large to show here.';

  /// The label of a file card whose kind has no viewer yet.
  static String noViewer(String kindPlural) =>
      "Lectale can't show $kindPlural in this version.";

  static String folderCap(int count) =>
      'Lectale shows up to $count items from this folder.';

  static String opensIn(String host) => 'Opens $host in your browser.';

  static String imageWithoutDescription(String name) =>
      'Image without description: $name';

  static String externalLinkName(String text) => '$text, opens in your browser';

  static String fileLinkName(String text) =>
      '$text, opens the file in your browser';
}

/// "12 KB", "4 KB", "1.2 MB": the size as a learner reads it.
String formatBytes(int bytes) {
  if (bytes < 1000) {
    return '$bytes B';
  }
  if (bytes < 1000 * 1000) {
    return '${(bytes / 1000).round()} KB';
  }
  final megabytes = bytes / (1000 * 1000);
  return '${megabytes.toStringAsFixed(megabytes < 10 ? 1 : 0)} MB';
}
