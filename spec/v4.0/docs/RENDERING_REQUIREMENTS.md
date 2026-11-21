# Mandatory in-app resource rendering, v3

**Product rule:** A student's primary course reading/viewing flow must stay inside the Flutter app. The UI must present every manifest item and every discovered folder item; a resource that cannot safely be previewed must show an in-app metadata card with a Download action and clear reason. Never silently hide files. `download: false` is a UI preference, not access control or DRM.

| Resource | Required in-app behavior | Safety / fallback |
|---|---|---|
| PDF (`pdf`, MIME `application/pdf`) | Multi-page in-app PDF viewer, zoom, page navigation, download | Use byte ranges where possible; do not require external reader |
| Video (`video`) | Embedded YouTube/Vimeo player for allowed provider; HTML5 player for playable media files | No arbitrary user iframe HTML; show link/download if provider prohibits embedding |
| Notebook (`notebook`, `.ipynb`) | Static in-app rendering of Markdown, code, plain text, images and sanitized math outputs | Do **not** execute code or trust embedded HTML/JavaScript; download notebook |
| Markdown (`markdown`) | In-app rendered Markdown with tables, code and math | Sanitize HTML; disallow scripts, event handlers, data exfil links |
| Images (`image`) | In-app image viewer, zoom, accessible alternative text/title | Sanitize SVG or force download; cap pixel dimensions |
| Audio (`audio`) | In-app player with seek/pause/speed where available | Show playback errors/download |
| Code/text (`code`, `text`) | In-app monospaced viewer, line numbers for code, syntax highlight where recognized | Treat content as plain text, never execute |
| Generic (`auto`, `file`) | MIME/extension sniff from trusted provider metadata and safe signature, use best supported renderer | Unknown/proprietary binary: in-app details + download; this is the explicit supported fallback |
| Folder (`folder`) | In-app navigable file index, opt-in recursion, bounded listing, resource preview on click | No unlimited traversal; hide prohibited secret files |
| External (`external`) | Link card with description | Never proxy/fetch arbitrary arbitrary URLs from Worker, no unrestricted embed |

**Not a promise of arbitrary native format support:** `.docx`, `.pptx`, unknown binaries, password-protected PDFs and executable apps cannot universally render without conversion. A clear in-app preview/fallback interface is required. Media should be viewed in the same app if technically supported, never require opening GitHub merely to see a PDF, video, or notebook.

**Rendering priority:** explicit resource `type` -> verified MIME/provider -> safe file signature -> generic card. A manifest `mediaType` is a hint only. Render URLs from an allowlist and safely constructed HTTPS links. Private resources use a Worker-authorized stream with Range support and `Cache-Control: private, no-store`; public content may be fetched directly from provider/CDN when CORS/browser policies permit. If direct remote embedding is blocked, use the permitted Worker relay or show the link/fallback. Do not leak App installation tokens into viewer URLs.

**QA fixtures:** PDF with embedded raster diagrams, 50-page PDF, YouTube + local MP4, notebook with code+matplotlib+untrusted HTML+script, SVG payload, code file, audio file, unknown `.dat`, denied private download, XSS in Markdown, 100-file folder. Acceptance: no unsafe script executes, no private content reaches other students, no supported PDF/video/notebook requires a separate app.
