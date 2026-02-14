# Multimedia Clipboard Support: Research & Design

## 1. macOS NSPasteboard API for Multimedia

### How the pasteboard works

`NSPasteboard.general` stores clipboard content as a collection of **pasteboard items** (`NSPasteboardItem`), where each item can have **multiple representations** (types). When you copy an image from Preview, the pasteboard may contain the same content as PNG data, TIFF data, and possibly a file URL -- all at once. Apps reading the pasteboard pick whichever representation they prefer.

### Key pasteboard types (NSPasteboard.PasteboardType / UTType)

| Category | PasteboardType / UTType string | Description |
|----------|-------------------------------|-------------|
| **Plain text** | `.string` / `public.utf8-plain-text` | Plain UTF-8 text |
| **Rich text** | `.rtf` / `public.rtf` | RTF formatted text |
| **Rich text + attachments** | `.rtfd` / `com.apple.flat-rtfd` | RTFD (RTF with images embedded) |
| **HTML** | `.html` / `public.html` | HTML markup |
| **PNG image** | `public.png` | PNG image data |
| **TIFF image** | `.tiff` / `public.tiff` | TIFF image data (macOS native image format) |
| **JPEG image** | `public.jpeg` | JPEG image data |
| **HEIC image** | `public.heic` | HEIC image data (Apple's modern format) |
| **File URL** | `.fileURL` / `public.file-url` | URL reference to a file on disk |
| **File names (deprecated)** | `NSFilenamesPboardType` | Legacy array of file paths |
| **PDF** | `com.adobe.pdf` | PDF data |
| **Color** | `.color` / `com.apple.cocoa.pasteboard.color` | NSColor data |

### Reading different content types from the pasteboard

```swift
let pb = NSPasteboard.general

// Plain text
let text = pb.string(forType: .string)

// Image data (check multiple types in priority order)
// TIFF is the native macOS image pasteboard format
if let tiffData = pb.data(forType: .tiff) {
    let image = NSImage(data: tiffData)
}
// Or PNG
if let pngData = pb.data(forType: NSPasteboard.PasteboardType("public.png")) {
    let image = NSImage(data: pngData)
}

// File URLs
if let urls = pb.readObjects(forClasses: [NSURL.self], options: [
    .urlReadingFileURLsOnly: true
]) as? [URL] {
    // urls contains file:// URLs
}

// Rich text
if let rtfData = pb.data(forType: .rtf) {
    let attrStr = NSAttributedString(rtf: rtfData, documentAttributes: nil)
}

// HTML
if let htmlData = pb.data(forType: .html) {
    let html = String(data: htmlData, encoding: .utf8)
}
```

### Writing content back to the pasteboard

```swift
let pb = NSPasteboard.general
pb.clearContents()

// For images: set data for each type that was stored
pb.setData(tiffData, forType: .tiff)
pb.setData(pngData, forType: NSPasteboard.PasteboardType("public.png"))

// For file URLs: use writeObjects for correct multi-file handling
let urls = fileURLs.map { $0 as NSURL }
pb.writeObjects(urls)

// For text with all original representations:
pb.setData(rtfData, forType: .rtf)
pb.setData(htmlData, forType: .html)
pb.setString(plainText, forType: .string)
```

### Important API behaviors

1. **Change count**: `pb.changeCount` increments on every clipboard change. Poll this to detect new copies.
2. **Multiple items**: A single copy can produce multiple `NSPasteboardItem`s (e.g., copying multiple files in Finder).
3. **Lazy data**: Some apps provide data lazily via `NSPasteboardItemDataProvider`. The data is only generated when requested. This means reading pasteboard data can be slow for large items.
4. **Transient types**: Some pasteboard types are transient/concealed (e.g., password managers). Maccy filters these via `dyn.` prefix and known concealment types.

---

## 2. Competitive Research

### Maccy (open source, github.com/p0deje/Maccy)

**What it supports**: Plain text, rich text (RTF, HTML), images (PNG, TIFF, JPEG, HEIC), file URLs. No audio support.

**Storage**: Uses SwiftData (Core Data / SQLite) for persistence. Stores **full image data** as `Data` blobs in the database. Default history size: 200 items. Stores all pasteboard representations for each item (so an image entry may have TIFF + PNG + string data).

**Image previews**: Two-tier system:
- **Thumbnail** (340px wide, configurable height): Generated on demand when item appears in the list. Displayed inline in the history popup.
- **Preview** (screen-sized, up to 2048x1536): Generated when item is selected, shown in a popover.
- Both are generated asynchronously in `Task` blocks. Cancelled and released via `cleanupImages()` when no longer visible.

**OCR**: Uses `VNRecognizeTextRequest` from the Vision framework. Performed **at capture time** (when the history item is created). Recognition level: `.fast`. Result stored as the item's `title`, which is then searchable. This means images are searchable by their text content without additional latency at search time.

**Paste-back**: Restores all stored pasteboard types when pasting. File URLs use `writeObjects()` for correct multi-file handling. Has a "remove formatting" option that strips everything except `.string` and `.fileURL`.

**Strengths**: Full multimedia support, OCR search, persistent storage, configurable.
**Weaknesses**: Large memory/storage footprint from storing full image data. Can become slow with many large images.

### Paste (pasteapp.io) -- commercial, closed source

**What it supports**: Text, images, files, links, colors, code snippets. No audio.

**Image previews**: Shows a visual grid/carousel of clipboard items. Images get full visual thumbnails. Files show their icon and name. Rich text shows formatted preview. Uses iCloud sync across devices.

**Storage**: Persistent, with iCloud sync. Uses Core Data. Stores full data but with smart trimming for very old entries.

**Key design decisions**:
- Grid layout rather than list -- better for visual content.
- Categorizes content by type (text, images, links, files, code).
- "Pinboards" for organizing saved clips.
- Smart preview sizing: small thumbnails in grid, larger on hover/selection.

**Strengths**: Polished UI, great visual previews, iCloud sync, categorization.
**Weaknesses**: Subscription pricing, closed source, heavier resource usage.

### CopyClip / CopyClip 2 (commercial)

**What it supports**: Primarily text. CopyClip 2 adds image support. Basic file path display.

**Previews**: Menu-bar dropdown with text snippets. Images show as small thumbnails in the menu. Minimal rich text handling.

**Storage**: In-memory with optional persistence. Configurable history size (typically 25-100).

**Strengths**: Lightweight, simple.
**Weaknesses**: Limited multimedia support, basic UI.

### Flycut (open source, github.com/TermiT/Flycut)

**What it supports**: **Text only**. Monitors RTF, HTML, URL, and file name pasteboard types but extracts only the string representation. Does not store or display images.

**Storage**: In-memory, text-only clips.

**Strengths**: Extremely lightweight, fast, simple. Good keyboard-driven workflow.
**Weaknesses**: No image/file/multimedia support at all.

### Summary comparison

| Feature | Maccy | Paste | CopyClip 2 | Flycut | Freeboard (current) |
|---------|-------|-------|------------|--------|-------------------|
| Text | Yes | Yes | Yes | Yes | Yes |
| Images | Yes | Yes | Yes | No | No |
| Files | Yes | Yes | Partial | No | No |
| Rich text | Yes | Yes | Partial | No | No |
| Audio | No | No | No | No | No |
| OCR search | Yes | No | No | No | No |
| Image preview | Thumbnail + popover | Grid thumbnails | Small thumbnails | N/A | N/A |
| Storage | SQLite (SwiftData) | Core Data + iCloud | Memory/disk | Memory | Memory |
| Max items | 200 (configurable) | Unlimited (paid) | 25-100 | Configurable | 50 |

---

## 3. Trade-offs

### 3.1 Image storage: Full data vs. thumbnails vs. both

**Option A: Store full image Data only, generate thumbnails on demand**
- Pro: Simplest code. Perfect paste-back fidelity.
- Con: High memory usage. 50 screenshots at 5MB each = 250MB RAM.

**Option B: Store thumbnail only**
- Pro: Very low memory (~50KB per thumbnail). Fast.
- Con: Cannot paste back at full resolution. Lossy. Defeats the purpose of a clipboard manager.

**Option C: Store full Data + cached thumbnail (Maccy's approach)**
- Pro: Full fidelity paste-back. Fast display via cached thumbnail. Can evict thumbnail cache under memory pressure.
- Con: Still uses lots of memory for full data. More complex code.

**Option D: Store full Data on disk, thumbnail in memory**
- Pro: Low memory footprint. Full fidelity paste-back from disk. Fast display from in-memory thumbnail.
- Con: Disk I/O on paste-back (usually fast). Requires file management / cleanup. More complexity.

**Recommendation: Option C for now, with a path to Option D later.** For a menu bar utility with max 50 items, storing full Data in memory is acceptable. Most clipboard items are small (text < 1KB, typical screenshots 100KB-2MB). We should set a per-item size cap (e.g., 10MB) and skip storing images larger than that. Thumbnails are generated lazily and cached.

### 3.2 UI: How to display different media types in a consistent row

**Challenge**: Current rows are 50px tall with a text label. Images need a visual preview. Files need an icon + filename. All must feel consistent.

**Option A: Adaptive row height with inline thumbnail**
- Image entries: Show a small thumbnail (e.g., 40x40) on the left, with "[Image]" or OCR text beside it. Same 50px row height.
- File entries: Show the file icon + filename.
- Text entries: Same as now.
- Pro: Minimal UI change. Consistent row heights. Fast rendering.
- Con: Small thumbnail may not convey the image well.

**Option B: Variable row heights, larger image previews**
- Image entries get taller rows (e.g., 80-120px) with a bigger preview.
- Pro: Better visual communication of image content.
- Con: Inconsistent list feel. Harder keyboard navigation. More complex layout.

**Option C: Uniform rows with expand-to-preview (like current text expand)**
- Default: 50px row with icon + type label + OCR text. Tab to expand shows a larger preview.
- Pro: Consistent base experience. Leverages existing expand pattern. User is already familiar with Tab to expand.
- Con: Requires Tab to see what the image is.

**Recommendation: Option A (small inline thumbnail) with Option C as the expand behavior.** The 50px row shows a thumbnail icon, a type indicator ("[Image]", "[File: document.pdf]"), and OCR text if available. Tab expands to show a larger preview. This is consistent with existing UX patterns and keeps the keyboard-driven workflow.

### 3.3 File references vs. embedded data

**Challenge**: When a user copies a file in Finder, the pasteboard contains a `file://` URL. Should we store the URL reference or the file data?

**Option A: Store file URL reference only**
- Pro: Near-zero storage cost. Paste-back is trivial (write URL back).
- Con: If the file is moved/deleted, the reference is stale. But this is acceptable -- the user copied a reference, not the file contents.

**Option B: Store file data**
- Pro: Survives file moves/deletes.
- Con: Massive storage for large files. Copying a 1GB video would be catastrophic. Unnecessary for the use case.

**Recommendation: Option A. Store the file URL only.** Display the file icon + name. On paste-back, write the URL to the pasteboard. If the file no longer exists, show a dimmed entry or indicator. This matches user mental model (they copied a file reference, not the file itself) and is what Maccy does.

### 3.4 Rich text (HTML, RTF): preserve formatting or show as plain text?

**Challenge**: Copying from a web browser often produces HTML + RTF + plain text. How should Freeboard handle this?

**Option A: Store all representations, display as plain text, paste back with full formatting**
- Pro: Preserves paste fidelity. Simple display (just show the `.string` representation). User gets the formatting when they paste, even though Freeboard shows it as plain text.
- Con: User cannot visually distinguish "this text has formatting" from "this is plain text."

**Option B: Store all representations, display with basic formatting indicator**
- Pro: User knows this entry has rich formatting. Same paste fidelity.
- Con: Slightly more UI complexity.

**Option C: Store only plain text, discard formatting**
- Pro: Simplest. Lowest storage.
- Con: Loses formatting on paste-back. Defeats the purpose.

**Recommendation: Option A with a subtle indicator.** Store all pasteboard representations. Display the plain text string (which is always present alongside HTML/RTF). Add a small indicator (e.g., "[Rich]" badge or subtle icon) to show the entry has formatting. On paste-back, restore all representations. Optionally offer "paste as plain text" (Cmd+Shift+V convention).

### 3.5 Audio: support or skip?

**Analysis**: None of the major clipboard managers (Maccy, Paste, CopyClip, Flycut) support audio clipboard content. Audio on the pasteboard is extremely rare -- it almost never happens in normal workflows. Users don't Cmd+C audio. Audio editing apps use their own internal clipboards.

**Recommendation: Skip audio support entirely.** It adds complexity with near-zero user benefit. If someone copies audio data, treat it as an unsupported type and either ignore it or show a generic "[Audio clip]" label without preview.

### 3.6 OCR: capture-time vs. search-time

**Option A: OCR at capture time (Maccy's approach)**
- Pro: Search is instant. No latency when the user types a query. OCR runs in background right after capture.
- Con: OCR runs for every image, even ones never searched. ~100-300ms per image with `.fast` recognition level. Could cause brief CPU spike on capture.

**Option B: OCR at search time**
- Pro: No wasted OCR for unsearched images. Lower capture overhead.
- Con: Search latency increases with number of image entries. Could be 1-3 seconds if many images. Poor UX for real-time fuzzy search.

**Option C: OCR at capture time, but deferred and debounced**
- Pro: Best of both worlds. OCR runs shortly after capture in a background queue with low priority. Search gets instant results. CPU impact is minimal because it's low-priority background work.
- Con: Brief window after capture where OCR text is not yet available for search.

**Recommendation: Option C.** Perform OCR in a background `Task` with `.background` priority after each image capture. Use `VNRecognizeTextRequest` with `.fast` recognition level. Store the recognized text alongside the entry. This makes search instant while keeping capture lightweight. The brief delay (< 1 second) before OCR text is searchable is imperceptible in practice.

---

## 4. Recommended Approach

### Phase 1: Core multimedia capture and paste-back

**Goal**: Capture images, files, and rich text from the pasteboard. Paste them back with full fidelity.

1. **Extend `ClipboardEntry`** with a content type enum:
   ```swift
   enum ClipboardContentType: Equatable {
       case text                              // plain text (existing behavior)
       case richText(html: Data?, rtf: Data?) // text with formatting data
       case image(data: Data, uti: String)    // image with raw data and UTI
       case file(url: URL, name: String)      // file reference
   }
   ```
   Keep the existing `content: String` for the plain text representation (used for display and search). Add `contentType: ClipboardContentType` and `thumbnailImage: NSImage?` (lazily generated, cached).

2. **Extend `ClipboardManager.checkForChanges()`** to detect content type:
   - Check for image types first (`.tiff`, `public.png`, `public.jpeg`, `public.heic`).
   - Check for file URLs (`.fileURL`).
   - Check for rich text (`.rtf`, `.html`) alongside `.string`.
   - Fall back to plain `.string`.
   - Store the raw `Data` for the primary type.

3. **Extend `PasteboardProviding` protocol** with methods for reading/writing `Data` and objects.

4. **Update `selectEntry()`** to restore all pasteboard representations based on content type.

### Phase 2: UI for multimedia entries

**Goal**: Show appropriate previews for each content type in the existing table view.

1. **Image rows**: 50px height. Show 40x40 thumbnail on the left. Label shows OCR text (if available) or "[Image - W x H]" with dimensions. Tab to expand shows the image at a larger size (up to full row width).

2. **File rows**: 50px height. Show the file type icon (from `NSWorkspace.shared.icon(forFile:)`). Label shows filename. Tab to expand shows the full path.

3. **Rich text rows**: 50px height. Same as current text rows but with a subtle "[R]" or formatting indicator. Tab to expand shows the formatted preview (or just the full plain text, since rendering formatted text in a retro terminal theme would look odd).

4. **"Edit" is disabled for non-text entries.** The ^E shortcut is ignored for images and files. This is already noted in the plan: "edit won't work for non-text things."

### Phase 3: OCR search

**Goal**: Make images searchable by their text content.

1. After capturing an image, dispatch a background `Task` that runs `VNRecognizeTextRequest` with `.fast` level.
2. Store the recognized text in `ClipboardEntry.ocrText: String?`.
3. Update `FuzzySearch.filter()` to also search `ocrText` for image entries.
4. Display OCR text as the label for image entries (truncated to one line in the 50px row).

### Implementation priority

1. **P0**: Capture and paste-back for images and file URLs. This is the core value.
2. **P1**: Inline thumbnail previews for images, file icons for files.
3. **P1**: Rich text indicator + full-fidelity paste-back for RTF/HTML.
4. **P2**: OCR search for images via Vision framework.
5. **P3**: Expand-to-preview for images (leveraging existing Tab expand pattern).

### Size and memory constraints for Freeboard

- **Max 50 items** (existing cap). With images, this could mean up to ~100MB in memory in a worst case (50 large screenshots). In practice, most items will be text (< 1KB each).
- **Per-item size cap**: Skip storing image data larger than 10MB. Show "[Image too large]" for oversized items.
- **Thumbnail size**: 80x80px (retina), stored as `NSImage`. ~25KB each. Total thumbnail memory: ~1.25MB for 50 items.
- **Full image data**: Stored as `Data` in memory. Consider moving to disk-backed storage (Phase 2+) if memory pressure becomes an issue.
- **Deduplication**: For text, current code deduplicates by content string. For images, deduplication is harder (comparing Data blobs is expensive). Consider skipping deduplication for images, or using a hash.

### What NOT to do

- **Do not render rich text with formatting in the retro terminal UI.** It would look incongruous. Show plain text representation; preserve formatting data only for paste-back fidelity.
- **Do not support audio.** No clipboard manager does this. Near-zero user demand.
- **Do not store file contents.** Store file URL references only.
- **Do not use Core Data or SwiftData** for this phase. In-memory storage matches the current architecture. Persistence is a separate future decision.
- **Do not build a grid/carousel UI** like Paste. Freeboard's identity is the terminal-style list. Keep it.

---

## 5. macOS Vision Framework OCR Reference

For Phase 3 (OCR), here is the key API usage:

```swift
import Vision

func recognizeText(in image: NSImage, completion: @escaping (String?) -> Void) {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        completion(nil)
        return
    }

    let request = VNRecognizeTextRequest { request, error in
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            completion(nil)
            return
        }
        let text = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
        completion(text.isEmpty ? nil : text)
    }
    request.recognitionLevel = .fast   // .fast for speed, .accurate for quality
    request.usesLanguageCorrection = false  // faster without language correction

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    DispatchQueue.global(qos: .background).async {
        try? handler.perform([request])
    }
}
```

**Performance characteristics** (`.fast` recognition level):
- Small image (screenshot of text): ~50-150ms
- Large image (high-res photo): ~200-500ms
- Background queue: does not block main thread or UI

**Supported since**: macOS 10.15 (Catalina). Freeboard's deployment target should be checked.
