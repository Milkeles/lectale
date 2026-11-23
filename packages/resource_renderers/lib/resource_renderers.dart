/// Viewers for the files of a Lectale course, chosen by resource kind.
///
/// The app builds a `ResourceEnvironment` with a `ResourceHost` and asks the
/// `ResourceRendererRegistry` to draw each `OutlineResource`. Viewers never
/// make a request of their own, never render HTML, and load images only
/// through the host's files route.
library;

export 'src/copy.dart' show ViewerCopy, formatBytes;
export 'src/environment.dart' show ContentStyles, ResourceEnvironment;
export 'src/host.dart'
    show
        ApiHref,
        RepositoryFile,
        ResourceErrorBuilder,
        ResourceHost,
        ResourceTarget,
        ResourceTooLarge;
export 'src/markdown/markdown_view.dart' show MarkdownView;
export 'src/punycode.dart' show asciiHost;
export 'src/registry.dart'
    show
        ResourceRenderer,
        ResourceRendererRegistry,
        ResourceViewBuilder,
        resolveKind;
export 'src/repository_path.dart';
export 'src/viewers/file_card.dart'
    show FileCard, LinkCard, kindAndSize, kindLabel, resourceFileName;
export 'src/viewers/text_loading.dart' show inlineTextLimit;
export 'src/widgets/content_image.dart' show ContentImage;
export 'src/widgets/download_button.dart' show DownloadButton;
export 'src/widgets/image_header.dart'
    show
        ImageNotRaster,
        ImageTooLarge,
        imageSizeFromHeader,
        maxImageBytes,
        maxImagePixels,
        maxImageSide;
export 'src/widgets/inline_link.dart' show InlineLink;
export 'src/widgets/load_once.dart' show LoadOnce, SkeletonLines;
export 'src/widgets/meta_style.dart' show metaTextStyle;
export 'src/widgets/sized_image.dart' show SizedImage, naturalImageSize;
