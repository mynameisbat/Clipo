# Changelog

All notable changes to Clipo will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] - 2026-06-14

### Added
- **Interactive Screen Capture & Editor**: Premium screen-capture utility inspired by Snapzy and CleanShot X.
  - Flexible crop area selector with pixel-level magnification guide.
  - Auto-snapping window detection under mouse cursor.
  - Beautiful canvas backdrops with designer gradients (Sunrise, Sunset, Aurora, Ocean, Glass) and canvas settings (padding, corner radius, drop shadow).
  - Vector markup annotation overlay for drawing arrows, freehand lines, and rectangles, plus **Blur & Blackout redaction tools** to safely obscure passwords and sensitive text.
  - High-performance, offline Text Recognition (OCR) leveraging macOS Vision framework.
  - Global customizable shortcut (default: `⌘⌥S`), status bar menu entry, and popup header button integration.
- **Advanced Screen Recording**: High-fidelity video capture with system audio.
  - System audio recording using `ScreenCaptureKit` and background serial dispatch queue.
  - Interactive video trimming with looping boundary constraints in the recording preview sidebar.
  - Customized export configurations for framerate (24/30/60 fps), resolution scale (50%/75%/100%), and GIF frame rate settings.
- **Software Update Checker**: Built-in async update service using GitHub Releases API
  - Silent checking on application launch
  - Manual check trigger and update downloading in Settings -> About tab
  - Modern update notification banner inside clipboard popup view

## [2.0.0] - 2026-05-02

### 🎉 Major Release: Performance & UI Modernization

This release represents a complete overhaul of Clipo's performance and user experience. Three implementation phases delivered significant improvements across CPU usage, memory footprint, search speed, and visual design.

**Performance Highlights:**
- 50% CPU reduction (idle: 2% → 0.8%)
- 25% memory reduction (1000 items: 80MB → 58MB)
- 50% faster search (100ms → 40ms)
- 33% faster popup open (150ms → 90ms)
- 2x smoother animations (35fps → 60fps+)

---

### Phase 1: Performance Foundation

#### Added
- **Adaptive Polling System**: Dynamic clipboard monitoring adjusts frequency based on activity
  - Idle (no changes): 5s interval
  - Active (recent changes): 1s interval
  - Focused (popup open): 0.5s interval
  - Reduces CPU usage by 40% during idle state
- **Smart Caching System**: In-memory cache for search results with 5-minute TTL
  - Cache hit: <5ms query latency
  - Cache miss: 40-50ms with FTS5 search
  - Automatic invalidation on clipboard changes
- **Batch Purge System**: Efficient history cleanup with single transaction
  - 60% faster than individual deletions
  - Protects pinned items from expiration
  - Configurable retention policy (7/14/30/90 days, never)
- **Thumbnail Generation Pipeline**: Optimized image storage and display
  - 150x150px thumbnails reduce memory by 80%
  - Background generation prevents UI blocking
  - Lazy loading for visible items only
- **FTS5 Full-Text Search**: SQLite FTS5 virtual table for fast search
  - Prefix matching: "swif" matches "swift"
  - Phrase search: "hello world" matches exact phrase
  - 50-67% faster than LIKE queries
  - Background indexing on first launch

#### Changed
- Replaced fixed 0.75s polling with adaptive polling system
- Database queries now use smart caching layer
- Image storage moved to thumbnails (150x150px) instead of full resolution
- Search implementation migrated from LIKE to FTS5

#### Performance
- CPU (idle): 2.0% → 1.2% (40% reduction)
- Memory (1000 items): 80MB → 68MB (15% reduction)
- Search latency: 100ms → 45ms (55% faster)
- Popup open latency: 150ms → 120ms (20% faster)

---

### Phase 2: UI Modernization

#### Added
- **Liquid Glass Material System**: Modern glassmorphism design with blur and saturation
  - Dynamic background blur (20pt radius)
  - Saturation boost (1.8x) for vibrant colors
  - Gradient overlay for depth perception
  - GPU-accelerated rendering via CoreImage
- **100% Keyboard Navigation**: All features accessible without mouse
  - `↑`/`↓`: Navigate items
  - `Cmd+↑`/`Cmd+↓`: Jump to top/bottom
  - `Enter`: Paste selected item
  - `Cmd+P`: Toggle pin
  - `Cmd+Backspace`: Delete item
  - `Cmd+F`: Focus search
  - `Escape`: Clear search or close popup
- **Physics-Based Animations**: Spring animations for natural motion
  - 60fps+ target frame rate
  - Smooth transitions for selection, hover, expand
  - Reduced animation duration (300ms → 200ms)
  - GPU-accelerated rendering
- **Source App Icons**: Visual indicator of clipboard item origin
  - 16x16px app icons cached in memory
  - Displayed in top-right of each row
  - Helps identify content source at a glance
- **Toast Notification System**: Non-intrusive feedback for actions
  - Success/error/info toast types
  - Auto-dismiss after 3 seconds
  - Slide-in animation from top
  - Accessible via keyboard

#### Changed
- Redesigned popup UI with Liquid Glass material
- Replaced linear animations with spring physics
- Enhanced visual feedback for hover and selection states
- Improved color contrast ratios (WCAG AA compliant)

#### Performance
- Frame rate: 35fps → 58fps (66% faster scrolling)
- Animation latency: 300ms → 200ms (33% faster)
- Memory overhead: +3.5MB (Liquid Glass + icons + animations)

---

### Phase 3: Advanced Optimization

#### Added
- **View Virtualization System**: Constant memory usage for large lists
  - Scroll offset tracking with PreferenceKey
  - Visible range calculation with configurable buffer
  - Spacers for items outside viewport
  - Not integrated (ClipboardRowView has variable heights)
- **GPU-Accelerated Glass Shader**: CoreImage-based rendering
  - Gaussian blur with 20pt radius
  - Saturation boost (1.8x)
  - Gradient overlay compositing
  - Hardware acceleration via CIContext
- **Lazy Image Loading System**: On-demand image loading
  - Actor-based thread-safe caching
  - Task deduplication (multiple requests share one load)
  - Parallel preloading with withTaskGroup
  - Memory usage estimation
- **Background I/O Queue**: Non-blocking disk operations
  - Actor-based async I/O queue
  - DispatchQueue with .utility QoS
  - Retry logic with configurable attempts
  - Timeout support with Task cancellation
- **Performance Telemetry**: Real-time monitoring
  - Metrics: CPU, memory, latency, FPS, item count
  - Automatic rotation (max 1000 samples)
  - Average and peak calculations
  - Time range filtering
  - Formatted report export

#### Changed
- Image loading now lazy (only visible items)
- Disk operations moved to background queue
- Glass effects use GPU acceleration instead of CPU

#### Performance
- CPU (idle): 1.2% → 0.8% (33% further reduction)
- Memory (1000 items): 68MB → 58MB (15% further reduction)
- Search latency: 45ms → 40ms (11% faster)
- Popup open latency: 120ms → 90ms (25% faster)
- Frame rate: 58fps → 60fps+ (stable 60fps)

---

### Breaking Changes

#### Database Schema
- Added `thumbnailPath` column to `clipboard_items` table
- Added `fts_indexed` column to `clipboard_items` table
- Created `clipboard_items_fts` virtual table for FTS5 search

**Migration:** Automatic on first launch. Backup recommended before upgrading.

#### Settings
- Removed `pollingInterval` setting (now adaptive)
- Added `adaptivePollingEnabled` setting (default: true)
- Added `lazyImageLoadingEnabled` setting (default: true)

**Migration:** Existing settings preserved. New settings use defaults.

---

### Fixed
- Fixed clipboard fingerprinting for browser content (HTML with URLs)
- Fixed Figma content parsing (special clipboard format)
- Fixed memory leak in image loading (now uses lazy loading)
- Fixed UI freezes during large history purge (now uses batch operations)
- Fixed search performance degradation with 10,000+ items (FTS5 scales better)
- Fixed animation frame drops during scroll (GPU acceleration)
- Fixed focus loss after deleting item (focus management improved)

---

### Documentation
- Added comprehensive migration guide (v1.0.1 → v2.0.0)
- Added performance report with before/after benchmarks
- Added accessibility audit (WCAG 2.1 AA compliance)
- Updated README with v2.0.0 features and performance metrics
- Added implementation reports for all 3 phases

---

### Technical Details

#### Dependencies
- GRDB.swift 7.0+ (SQLite with Swift Concurrency)
- KeyboardShortcuts 1.9+ (global hotkey registration)
- Swift 6 with strict concurrency checking

#### Architecture
- Actor-based concurrency for thread-safe state management
- Sendable conformance throughout for data race prevention
- CoreImage GPU-accelerated rendering
- Background I/O queue with retry logic
- FTS5 full-text search with smart caching

#### Test Coverage
- 196 unit tests (all passing)
- 49 new tests for Phase 3 components
- 36 new tests for Phase 2 components
- 0 test failures

---

### Known Issues
- First launch FTS5 index build takes 10-30 seconds (1000 items)
- View virtualization not integrated (variable row heights)
- Large image thumbnails (150x150px) still large for 10,000+ items
- Database write contention possible with rapid clipboard changes (<1s)

---

### Upgrade Notes

**From v1.0.1:**
1. Backup database: `~/Library/Application Support/com.bat.clipo/clipboard.db`
2. Quit v1.0.1
3. Install v2.0.0 DMG
4. Launch v2.0.0 (automatic migration runs)
5. First launch may take 10-30 seconds (FTS5 index build)

**Rollback:**
1. Quit v2.0.0
2. Restore backup database
3. Reinstall v1.0.1 DMG

See `docs/migration-guide.md` for detailed instructions.

---

## [1.0.1] - 2026-03-XX

### Fixed
- Improved popup workflow and window management
- Fixed edge cases in clipboard monitoring
- Enhanced error handling for corrupted clipboard data

### Changed
- Refined UI spacing and alignment
- Improved toast notification timing

---

## [1.0.0] - 2026-03-XX

### Added
- Initial public release
- Menu bar clipboard manager for macOS
- Global hotkey (Cmd+Shift+V) for quick access
- Searchable clipboard history
- Inline image previews
- Pin important items
- Auto-paste with Accessibility permission
- Automatic history cleanup
- SQLite database with GRDB
- SwiftUI + AppKit hybrid architecture

### Features
- Text, image, URL, and file path support
- Browser content parsing (HTML with URLs)
- Figma content parsing
- Keyboard shortcuts for all actions
- Settings panel (retention policy, launch at login, clipboard sound)
- Permission management (Accessibility)

---

## Links

- [Migration Guide](docs/migration-guide.md)
- [Performance Report](docs/performance-report.md)
- [Accessibility Audit](docs/accessibility-audit.md)
- [GitHub Releases](https://github.com/bloodstalk1/Clipo/releases)
- [Issue Tracker](https://github.com/bloodstalk1/Clipo/issues)

---

[3.0.0]: https://github.com/bloodstalk1/Clipo/compare/v2.0.0...v3.0.0
[2.0.0]: https://github.com/bloodstalk1/Clipo/compare/v1.0.1...v2.0.0
[1.0.1]: https://github.com/bloodstalk1/Clipo/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/bloodstalk1/Clipo/releases/tag/v1.0.0
