# Changelog

All notable changes to ReDyne will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### ✨ Added
- Decompilation result caching system to avoid re-analyzing binaries on subsequent opens
- Cache management UI in settings menu showing cache size and item count

### 📚 Documentation
- Refreshed Documentation/ notes with v1.1 (build 2) last-updated stamps
- Added VSCode development and GitHub Actions CI/CD workflow information to README installation section

### 🛠️ Changed
- Updated the About ReDyne dialog text and version string to read from Info.plist
- Reused the app version label in settings, diagnostics, and export outputs
- UserDefaults keys now derive from the bundle identifier instead of a hardcoded value
- Decompilation results are now cached for 30 days to improve performance on re-opening binaries

### 🐛 Bug Fixes
- Fixed ClassDumpService method name mismatch in DecompileViewController (generateHeaderForBinary vs generateHeader)
- Removed iOS-unavailable .withSecurityScope bookmark options from FilePickerViewController
- Fixed JSON file selection for function name import, patch import, and database import to use EnhancedFilePicker in Legacy mode
- Fixed binary metadata not persisting across app reloads by implementing comprehensive decompilation cache

## [1.1.0] - 2026-02-26

### ✨ Added
- Function name JSON import with address-based overrides in the functions list
- Class dump header generation and type reconstruction views
- Export coverage tests for class dump/type reconstruction and JSON import tests
- Manual GitHub Actions workflow to build and publish an unsigned IPA release with release notes and artifact retention

### 🛠️ Changed
- Text and JSON exports now include class dump headers and reconstructed types
- App version bumped to 1.1 (build 2)

### 🐛 Bug Fixes
- Recent files now reopen correctly by refreshing security-scoped bookmarks and paths

## [1.1.0] - 2025-11-02

### 🎉 IntervalMedia Fork Release

This release marks the first major update since forking from [speedyfriend433/ReDyne](https://github.com/speedyfriend433/ReDyne). We are grateful to speedyfriend433 for the excellent foundation and continue to build upon their work.

### ✨ Added

#### Hex Viewer (PR #2)
- **Comprehensive Hex Viewer Implementation**
  - 16-byte row display with address column, hex bytes, and ASCII representation
  - Navigate to specific addresses with hex input validation (`0x1000` format)
  - Navigate to functions via searchable picker
  - Navigate to sections with quick-select from segment.section list
  - Context menus on disassembly/function rows for direct hex viewer navigation
  - Toggleable section annotations showing which section contains each address
  - Large file warning (>100MB) to prevent memory issues
- **Section Filtering**
  - Filter by code sections (`__TEXT`, `__text`, `__stubs`)
  - Filter by data sections (`__DATA`, `__bss`, `__data`)
  - Filter by string sections (`__cstring`)
  - Dynamic base address offset adjustment when filtering
- **Export Formats**
  - Text export: traditional hex dump format with address | hex | ASCII columns
  - Binary export: raw data extraction for further analysis
  - iOS share sheet integration for AirDrop/Files
- **HEX_VIEWER_IMPLEMENTATION.md**: Complete documentation of hex viewer architecture and usage

#### Services Layer Enhancements (PR #1)
- **Export Service Improvements**
  - PDF export implementation with multi-page generation using `UIGraphicsPDFRenderer`
  - PDF pages include: title, header/stats, segments, symbols, strings
  - Enhanced validation in `canExport()` checking critical fields
- **Binary Storage Metadata System**
  - Import date tracking
  - File size recording
  - SHA-256 hash computation (streaming for large files)
  - Access count tracking
  - Persistent JSON storage with `BinaryMetadata` model
  - Analytics: `totalStorageSize()`, `savedBinaryCount()`, `getMetadata()`
- **Patch Services**
  - `BinaryPatchService`: Statistics aggregation, binary-specific patch discovery
  - `BinaryPatchEngine`: LocalizedError conformance with recovery suggestions
- **Analysis Utilities**
  - `CFGAnalyzer`: `validateCFG()` for graph correctness, `calculateComplexity()` for metrics
  - `XrefAnalyzer`: `findCallers()`, `findCallees()`, filtering/grouping utilities
- **Comprehensive Documentation**
  - Added docstrings to all public APIs across 10 service classes
  - Parameter/return descriptions following Swift conventions

#### Binary Patching System (PR #4)
- **New Swift Type Definitions**
  - `BinaryPatchModels.swift` with complete type structures
  - `PatchTemplateLibrary.swift` with 6 common patch templates
  - `MachOUtilities.swift` for binary file inspection
  - `EnhancedFilePicker.swift` for improved file selection
  - Updated `Constants.swift` with required constants
- **Missing Properties Added**
  - All missing properties to `BinaryPatchSet` and `BinaryPatch`
  - Missing enums and cases
  - Missing utility methods

#### CI/CD Infrastructure (PR #3)
- **GitHub Actions Workflow**
  - `.github/workflows/ios16-build.yml` for iOS 16.0 builds
  - Triggers on push/PR to main, plus manual dispatch
  - Uses latest stable Xcode on macOS runner
  - Builds with `IPHONEOS_DEPLOYMENT_TARGET=16.0`
  - Disables code signing for CI consistency
  - Explicit `permissions: contents: read` for minimal GITHUB_TOKEN scope

### 🐛 Bug Fixes

#### Switch Statement Exhaustiveness (PR #5)
- Fixed non-exhaustive switch in `BinaryPatchDashboardViewController.swift`
  - Added `.verified` case: displays "Verified" with teal color
  - Added `.failed` case: displays "Failed" with red color
- Fixed non-exhaustive switch in `BinaryPatchDetailViewController.swift`
  - Added `.pending` case: displays "Pending" with default styling
  - Added `.verified` case: displays "Verified" with teal color
  - Added `.failed` case: displays "Failed" with red color

#### ResultsViewController Fixes (PR #4)
- Fixed `filePath` handling: changed from Optional to non-optional String
- Fixed `BinaryPatchEditorViewController`: Added parentheses to fix nil coalescing precedence

### 🛠️ Technical Improvements

- Replaced weak custom hash with SHA-256 for integrity and collision prevention
- Streaming file I/O to prevent memory issues with large binaries
- Defensive cell dequeuing with `guard let` instead of force cast
- Monospaced fonts for proper hex/ASCII alignment
- Memory-safe export trie traversal

### ♻️ Refactoring

- Removed unused imports across service classes
- Enhanced input validation throughout the codebase
- Improved error handling with LocalizedError conformance

### 🗑️ Removal

#### Workflow Cleanup (PR #6)
- Removed obsolete `.github/workflows/hexviewer-tests.yml` workflow file

### 📚 Documentation

- Added `HEX_VIEWER_IMPLEMENTATION.md` with comprehensive hex viewer documentation
- Enhanced all service class documentation with docstrings
- Updated contributing guidelines

### 🙏 Acknowledgments

This fork builds upon the excellent work by [speedyfriend433](https://github.com/speedyfriend433) and the original [ReDyne project](https://github.com/speedyfriend433/ReDyne). We are grateful for the solid foundation and continue to contribute improvements back to the iOS reverse engineering community.

---

## [1.0.0] - 2025-10-06

### 🎉 Initial Release

The first production-ready release of ReDyne, a comprehensive iOS decompiler and reverse engineering suite.

### ✨ Added

#### Core Features
- **Mach-O Binary Parsing**
  - Universal (fat) and thin binary support
  - ARM64, ARM64e, x86_64 architecture support
  - Magic number validation and format detection
  - Complete load command parsing
  - Segment and section analysis with flags

#### Disassembly Engine
- **ARM64 Disassembler**
  - 100+ instruction types supported
  - Data processing, load/store, branches, logical ops
  - Multiply/divide, compare, shifts
  - SIMD/FP operations
  - System instructions and barriers
  - Register usage tracking
  - Branch detection
- **x86_64 Disassembler**
  - ModR/M, SIB, REX prefix handling
  - Dynamic length calculation
  - Common instruction support

#### Analysis Features
- **Symbol Table Analysis**
  - Complete nlist/nlist_64 support
  - Symbol type detection (functions, objects, sections)
  - Dynamic symbol detection
  - Name demangling for Swift/C++
  - Address resolution
- **Cross-Reference Analysis**
  - Call graph generation (586+ calls per binary)
  - Jump/branch tracking (277+ per binary)
  - Data reference detection
  - Symbolic execution engine with ADRP+ADD recognition
  - Page-aligned address computation
- **Control Flow Graphs**
  - Hierarchical BFS-based layout
  - Basic block detection and analysis
  - Edge classification (true/false, loops, calls, returns)
  - Dominance-based loop detection
  - Interactive visualization with zoom (0.05x-3.0x) and pan
  - Dynamic sizing for 1-158+ node graphs
  - Color-coded nodes (entry: blue, exit: red, conditional: orange)
- **Objective-C Runtime Analysis**
  - Class extraction from `__objc_classlist`
  - Method discovery (instance and class)
  - Property parsing
  - Instance variable layouts
  - Category parsing with methods/properties
  - Protocol conformance detection
- **Import/Export Tables**
  - Dyld bind info (all 12 opcodes)
  - Dyld rebase info (all 9 opcodes)
  - Export trie traversal with ULEB128 decoding
  - Weak import detection
  - Lazy binding tracking
  - Library dependency tree
- **Code Signature Inspector**
  - SuperBlob structure parsing
  - CodeDirectory extraction (CDHash, Team ID, Signing ID)
  - Entitlement parsing and XML formatting
  - Requirements validation
  - Signature type detection (ad-hoc vs full)
- **String Analysis**
  - C-string extraction from multiple sections
  - Minimum length filtering
  - Encoding detection
  - Section-aware extraction

#### Export Capabilities
- TXT export (clean, readable)
- JSON export (structured with full metadata)
- HTML export (styled with syntax highlighting)
- PDF export (multi-page with professional typography)
- Native iOS share sheet integration

#### User Interface
- **File Management**
  - UIDocumentPicker integration
  - Recent files with security-scoped bookmarks
  - Swipe-to-delete
  - Persistent file access across app restarts
- **Results Display**
  - 11-tab interface for comprehensive analysis
  - Searchable tables
  - Copy/share functionality
  - Dark mode support
  - Adaptive layout for iPhone and iPad
- **CFG Viewer**
  - Interactive graph visualization
  - Core Graphics rendering
  - Pinch-to-zoom and pan gestures
  - Node tap for basic block inspection
  - Auto-fit for optimal viewing

#### Architecture
- C-based binary parsers for maximum performance
- Objective-C service layer for Swift bridging
- Swift UI layer with UIKit
- MVVM architecture with clear separation
- Background processing for large files
- Memory-efficient parsing

### 🛠️ Technical Improvements
- Strict prologue detection for accurate function boundaries
- Priority-based ARM64 instruction decoding (B/BL → RET/BR/BLR → STP/LDP → others)
- Memory-safe export trie traversal
- Comprehensive bounds checking in C parsers
- Efficient register state tracking
- Dynamic CFG layout with loop-back edge support

### 🐛 Bug Fixes
- Fixed EXC_BAD_ACCESS crash in dyld export parser
- Fixed arithmetic overflow in function size calculation
- Fixed instruction decoding for STP/LDP (moved to top-level check)
- Fixed RET/BR/BLR decoding (moved to top-level check)
- Fixed B/BL decoding (moved to very top of decoder)
- Fixed function truncation due to overly broad prologue detection
- Fixed CFG graph clipping for complex layouts
- Fixed zero cross-references due to incorrect branch detection
- Fixed zero CFG nodes/edges due to incorrect instruction parsing
- Fixed branch flag propagation from C to Swift

### 📚 Documentation
- Comprehensive README with feature list
- Detailed BUILD_GUIDE for developers
- Contributing guidelines with code style and architecture
- GitHub issue templates (bug reports, feature requests)
- Pull request template
- MIT License
- Architecture documentation

### 🎯 Known Limitations
- Very large binaries (>100MB) may cause memory pressure
- Some complex ObjC runtime structures not yet parsed
- x86_64 coverage prioritized but not 100%

---

## [0.1.0] - Development Versions

### Initial Development
- Basic Mach-O parsing
- Simple disassembly
- Initial UI implementation
- Core architecture established

---

## Legend

- 🎉 Major release
- ✨ New features
- 🛠️ Improvements
- 🐛 Bug fixes
- 📚 Documentation
- 🔐 Security
- ⚡ Performance
- 🎨 UI/UX
- ♻️ Refactoring
- 🗑️ Removal
- ⚠️ Deprecation

---

[Unreleased]: https://github.com/IntervalMedia/ReDyne/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/IntervalMedia/ReDyne/releases/tag/v1.1.0
[1.0.0]: https://github.com/speedyfriend433/ReDyne/releases/tag/v1.0.0
[0.1.0]: https://github.com/speedyfriend433/ReDyne/releases/tag/v0.1.0

