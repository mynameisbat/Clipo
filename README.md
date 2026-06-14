<div align="center">

<img src="Clipo/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-128.png" width="96" alt="Clipo icon" />

# Clipo

**The clipboard manager macOS deserves.**

[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Swift 6](https://img.shields.io/badge/Swift-6.0-orange?style=flat-square&logo=swift)](https://swift.org)
[![Version](https://img.shields.io/badge/version-3.0.0-blueviolet?style=flat-square)](https://github.com/mynameisbat/Clipo/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

[**Download v3.0.0**](https://github.com/mynameisbat/Clipo/releases/latest) · [English](#english) · [Tiếng Việt](#tiếng-việt)

</div>

---

## English

Clipo lives quietly in your menu bar and keeps every text, image, link, and file you've ever copied — searchable, filterable, and ready to paste in one keystroke.

### What's new in v3.0.0

| | Feature | Description |
|---|---|---|
| 📸 | **Screen Capture & Editor** | Capture any area or window, annotate, redact, and export — no third-party app needed |
| 🎬 | **Screen Recording** | Record screen regions with system audio + mic, trim, and export to MP4 or GIF |
| 🔔 | **Auto Update Checker** | Silent background update detection with one-click download via GitHub Releases |

---

### Features

#### 📋 Clipboard History

| Feature | Description |
|---|---|
| **Menu bar app** | No Dock icon — always at your fingertips. Open with `⌘⇧V` |
| **Visual timeline** | Every item shows preview, source app icon, timestamp, and kind |
| **Filter chips** | Filter by Text / Image / Link / File, Pinned, or custom Pinboards |
| **Full-text search** | SQLite FTS5 — prefix match, phrase match, sub-50ms results |
| **Pin items** | Protect from auto-delete and surface important items instantly |
| **Pinboards** | Create named collections (e.g. *Emails*, *Code*, *Templates*) |
| **Quick Paste `⌘1–9`** | Grab the Nth most recent item without opening the popup |
| **Auto-paste** | One Accessibility grant lets Clipo paste directly into your last active app |
| **Pause toggle** | Stop recording history with one tap when handling sensitive data |
| **History retention** | Auto-delete after 7 / 14 / 30 / 90 days, or keep forever |
| **Backup & Restore** | Export/import full history archive (`.clipobackup`) |

#### 📸 Screen Capture & Editor

| Feature | Description |
|---|---|
| **Area & window capture** | Drag to select or hover a window to auto-snap |
| **Pixel-level magnifier** | Zoom loupe near cursor for pixel-perfect selection |
| **Canvas backdrops** | Sunrise, Sunset, Aurora, Ocean, Glass gradient presets |
| **Canvas controls** | Adjustable padding, corner radius, and drop shadow |
| **Annotation tools** | Draw arrows, rectangles, freehand lines in any color |
| **Blur & Blackout** | Redact passwords and sensitive content before sharing |
| **OCR** | Extract text from any screenshot using macOS Vision |
| **Copy or Save** | Copy to clipboard or save as PNG in one click |

#### 🎬 Screen Recording

| Feature | Description |
|---|---|
| **Region recording** | Record any selected screen area |
| **System audio** | Capture system audio via ScreenCaptureKit |
| **Microphone** | Optional mic recording alongside system audio |
| **Video trimming** | Trim start/end directly in the preview window |
| **MP4 export** | Save as high-quality MP4 |
| **GIF export** | Convert to animated GIF with configurable FPS and scale |
| **FPS settings** | 24 / 30 / 60 fps video capture (Settings → General) |

---

### Install

**Download the DMG (recommended)**

1. Go to [**Releases**](https://github.com/mynameisbat/Clipo/releases/latest)
2. Download `Clipo-v3.0.0.dmg`
3. Open the DMG and drag `Clipo.app` into **Applications**
4. Launch Clipo — it will appear in your menu bar

**Build from source**

```bash
git clone https://github.com/mynameisbat/Clipo.git
cd Clipo
xcodegen generate
open Clipo.xcodeproj
# Press ⌘R in Xcode
```

**Package a DMG yourself**

```bash
xcodegen generate
./scripts/package_dmg.sh
```

---

### Permissions

| Permission | Required for | Without it |
|---|---|---|
| **Accessibility** | Auto-paste into previous app | Copies to clipboard — paste manually with `⌘V` |
| **Screen Recording** | Screen capture & recording | Feature unavailable |
| **Microphone** | Recording with mic audio | Records without mic (system audio still works) |

To grant Screen Recording: **System Settings → Privacy & Security → Screen & System Audio Recording → Clipo ✓**

---

### Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `⌘⇧V` | Toggle clipboard popup |
| `⌃⌥V` | Open paste picker |
| `⌘⌥S` | Capture screen (default) |
| `⌘⌥R` | Start screen recording (default) |
| `↑` / `↓` | Navigate items |
| `⌘↑` / `⌘↓` | Jump to top / bottom |
| `Enter` | Paste selected item |
| `⌘1`–`⌘9` | Quick paste (Nth most recent) |
| `⌘P` | Pin / unpin selected item |
| `⌘T` | Pause / resume history |
| `⌘F` | Focus search field |
| `Esc` | Clear search, then close |

All shortcuts are customisable in **Settings → Shortcuts**.

---

### Requirements

- macOS 13 Ventura or later
- Apple Silicon or Intel Mac
- ~15 MB disk space

### Tech stack

| Layer | Technology |
|---|---|
| Language | Swift 6 — strict concurrency, actors, `Sendable` |
| UI | SwiftUI + AppKit hybrid, `NSVisualEffectView` glass |
| Persistence | GRDB.swift + SQLite FTS5 full-text search |
| Screen Capture | AVFoundation + ScreenCaptureKit |
| OCR | Vision framework |
| Hotkeys | KeyboardShortcuts |
| Project | XcodeGen |

---

## Tiếng Việt

Clipo chạy âm thầm trong menu bar và lưu lại mọi thứ bạn đã copy — văn bản, ảnh, link, file — có thể tìm kiếm, lọc, và dán lại chỉ với một phím tắt.

### Tính năng mới trong v3.0.0

| | Tính năng | Mô tả |
|---|---|---|
| 📸 | **Chụp màn hình & Trình chỉnh sửa** | Chụp bất kỳ vùng hay cửa sổ nào, thêm chú thích, che phủ nội dung nhạy cảm, và xuất ảnh |
| 🎬 | **Quay màn hình** | Quay video vùng màn hình với âm thanh hệ thống + mic, cắt video, xuất MP4 hoặc GIF |
| 🔔 | **Tự động kiểm tra cập nhật** | Kiểm tra bản mới tự động khi khởi động, tải về chỉ một click qua GitHub Releases |

---

### Tính năng đầy đủ

#### 📋 Lịch sử Clipboard

| Tính năng | Mô tả |
|---|---|
| **Menu bar app** | Không có icon Dock — luôn sẵn trong tầm tay. Mở bằng `⌘⇧V` |
| **Dòng thời gian trực quan** | Mỗi mục hiện preview, icon app nguồn, thời gian, và loại nội dung |
| **Chip bộ lọc** | Lọc theo Văn bản / Ảnh / Link / File, Đã ghim, hoặc Pinboard tùy chỉnh |
| **Tìm kiếm toàn văn** | SQLite FTS5 — tìm theo tiền tố, cụm từ, kết quả dưới 50ms |
| **Ghim mục** | Bảo vệ khỏi xóa tự động, hiển thị ưu tiên |
| **Pinboards** | Tạo bộ sưu tập tên tuỳ ý (vd: *Email*, *Code*, *Mẫu*) |
| **Quick Paste `⌘1–9`** | Lấy mục gần nhất thứ N mà không cần mở popup |
| **Auto-paste** | Cấp quyền Accessibility một lần — Clipo tự dán vào app trước đó |
| **Tạm dừng** | Ngừng ghi lịch sử khi xử lý dữ liệu nhạy cảm |
| **Tự động xóa** | Sau 7 / 14 / 30 / 90 ngày, hoặc giữ mãi mãi |
| **Sao lưu & Khôi phục** | Xuất/nhập toàn bộ lịch sử dưới dạng `.clipobackup` |

#### 📸 Chụp màn hình & Trình chỉnh sửa

| Tính năng | Mô tả |
|---|---|
| **Chụp vùng & cửa sổ** | Kéo để chọn vùng hoặc di chuột qua cửa sổ để tự động snap |
| **Kính lúp pixel** | Phóng to tại con trỏ để chọn vùng chính xác đến pixel |
| **Nền Canvas** | Preset gradient: Sunrise, Sunset, Aurora, Ocean, Glass |
| **Điều chỉnh canvas** | Padding, bo góc, và bóng đổ tuỳ chỉnh |
| **Công cụ chú thích** | Vẽ mũi tên, hình chữ nhật, nét tự do với nhiều màu |
| **Blur & Blackout** | Che mờ mật khẩu và nội dung nhạy cảm trước khi chia sẻ |
| **OCR** | Trích xuất văn bản từ ảnh chụp màn hình bằng macOS Vision |
| **Sao chép hoặc Lưu** | Copy vào clipboard hoặc lưu PNG chỉ một click |

#### 🎬 Quay màn hình

| Tính năng | Mô tả |
|---|---|
| **Quay vùng** | Chọn và quay bất kỳ vùng màn hình nào |
| **Âm thanh hệ thống** | Thu âm hệ thống qua ScreenCaptureKit |
| **Microphone** | Ghi âm mic tùy chọn cùng với âm thanh hệ thống |
| **Cắt video** | Cắt điểm đầu/cuối ngay trong cửa sổ xem trước |
| **Xuất MP4** | Lưu video chất lượng cao |
| **Xuất GIF** | Chuyển đổi thành GIF động với FPS và tỉ lệ tuỳ chỉnh |
| **Cài đặt FPS** | 24 / 30 / 60 fps (Settings → General) |

---

### Cài đặt

**Tải DMG (khuyên dùng)**

1. Vào trang [**Releases**](https://github.com/mynameisbat/Clipo/releases/latest)
2. Tải `Clipo-v3.0.0.dmg`
3. Mở DMG và kéo `Clipo.app` vào thư mục **Applications**
4. Khởi động Clipo — sẽ xuất hiện trên menu bar

**Build từ source**

```bash
git clone https://github.com/mynameisbat/Clipo.git
cd Clipo
xcodegen generate
open Clipo.xcodeproj
# Nhấn ⌘R trong Xcode
```

**Đóng gói DMG**

```bash
xcodegen generate
./scripts/package_dmg.sh
```

---

### Quyền (Permissions)

| Quyền | Dùng cho | Nếu không cấp |
|---|---|---|
| **Accessibility** | Tự động dán vào app trước đó | Sao chép vào clipboard — tự dán bằng `⌘V` |
| **Screen Recording** | Chụp & quay màn hình | Tính năng không khả dụng |
| **Microphone** | Ghi âm mic khi quay màn hình | Quay không có mic (âm thanh hệ thống vẫn hoạt động) |

Cấp quyền Screen Recording: **System Settings → Privacy & Security → Screen & System Audio Recording → Clipo ✓**

---

### Phím tắt

| Phím tắt | Hành động |
|---|---|
| `⌘⇧V` | Bật/tắt popup clipboard |
| `⌃⌥V` | Mở paste picker |
| `⌘⌥S` | Chụp màn hình (mặc định) |
| `⌘⌥R` | Bắt đầu quay màn hình (mặc định) |
| `↑` / `↓` | Di chuyển giữa các mục |
| `⌘↑` / `⌘↓` | Nhảy lên đầu / xuống cuối |
| `Enter` | Dán mục đang chọn |
| `⌘1`–`⌘9` | Quick paste (mục gần nhất thứ N) |
| `⌘P` | Ghim / bỏ ghim mục đang chọn |
| `⌘T` | Tạm dừng / tiếp tục thu thập lịch sử |
| `⌘F` | Focus vào ô tìm kiếm |
| `Esc` | Xóa tìm kiếm, rồi đóng popup |

Mọi phím tắt có thể gán lại trong **Settings → Shortcuts**.

---

### Yêu cầu hệ thống

- macOS 13 Ventura trở lên
- Apple Silicon hoặc Intel Mac
- ~15 MB dung lượng

### Tech stack

| Lớp | Công nghệ |
|---|---|
| Ngôn ngữ | Swift 6 — strict concurrency, actors, `Sendable` |
| UI | SwiftUI + AppKit hybrid, `NSVisualEffectView` glass |
| Lưu trữ | GRDB.swift + SQLite FTS5 tìm kiếm toàn văn |
| Quay màn hình | AVFoundation + ScreenCaptureKit |
| OCR | Vision framework |
| Phím tắt | KeyboardShortcuts |
| Dự án | XcodeGen |

---

<div align="center">

MIT License · Made with ❤️ for macOS

</div>
