# Hex Viewer Implementation Summary

**Last updated**: 2026-02-26 (v1.1, build 2)

## Overview
This document describes the implementation of the hex viewer feature for the ReDyne iOS decompiler application.

## Problem Statement
Implement a hex viewer feature that:
1. Displays binary data in hexadecimal format with ASCII representation
2. Provides navigation by address, function name, and section
3. Includes visual filtering options
4. Integrates with existing analysis results

## Implementation Details

### Core Components

#### 1. HexViewerViewController
**File**: `ReDyne/ViewControllers/HexViewerViewController.swift`

**Features**:
- Hexadecimal and ASCII display in table view
- 16 bytes per row display format
- Address column showing memory addresses
- Section annotations (toggleable)

**Navigation Methods**:
- `scrollToAddress(_:)`: Jump to specific memory address
- `showGoToAddress()`: Dialog for manual address input
- `showGoToFunction()`: Function picker with search
- `showGoToSection()`: Section picker

**Visual Features**:
- Annotation toggle to show/hide section information
- Row highlighting for current selection
- Color-coded section names
- Search bar for address lookup

**Export Capabilities**:
- Text format hex dump
- Binary format export
- Standard iOS share sheet integration

#### 2. HexViewerCell
**Features**:
- Monospaced font for proper alignment
- Three-column layout (Address, Hex, ASCII)
- Section name display (when annotations enabled)
- Highlight support for selection

#### 3. FunctionPickerViewController
**Features**:
- Searchable function list
- Function name and start address display
- Quick navigation to selected function

### Integration Points

#### AnalysisMenuViewController
**Modified**: Added `hexViewer` case to `AnalysisType` enum
- Icon: "number.square"
- Description: "View binary data in hexadecimal format"

#### ResultsViewController
**Changes**:
1. Added `hexViewerViewController` lazy property
2. Added `showHexViewer(at:)` method for programmatic navigation
3. Updated `AnalysisMenuDelegate` to handle hex viewer selection
4. The "Hex" segment in `ResultsViewController` is now added conditionally at runtime (only when `DecompiledOutput.fileSize > 0` or `DecompiledOutput.fileData` is present). The Hex viewer will prefer the cached `fileData` when available.

#### DisassemblyViewController
**Enhanced**: Added context menu support
- "Go to Address in Hex Viewer" action
- "Copy Address" action
- Sets `parentResultsVC` reference for navigation

#### FunctionsViewController
**Enhanced**: Added context menu support
- "Go to Function in Hex Viewer" action
- "Copy Address" action
- Sets `parentResultsVC` reference for navigation

#### StringsViewController
**Enhanced**: Added context menu support
- "Go to Address in Hex Viewer" action
- "Copy Address" action
- Sets `parentResultsVC` reference for navigation

### User Interface Flow

#### Primary Access Path
```
ResultsViewController 
  → More Options (⋯ button)
  → Advanced Analysis Menu
  → Hex Viewer
```

#### Secondary Access Paths
1. From Disassembly:
   - Long-press on instruction row
   - Select "Go to Address in Hex Viewer"

2. From Functions:
   - Long-press on function row
   - Select "Go to Function in Hex Viewer"

### Features Implemented

#### Navigation Features
- ✅ Go to Address (with hex input validation)
- ✅ Go to Function (with searchable picker)
- ✅ Go to Section (section list)
- ✅ Search bar for address lookup
- ✅ Visual feedback with toast notifications

#### Display Features
- ✅ 16-byte row display
- ✅ Hexadecimal byte representation
- ✅ ASCII character representation
- ✅ Address column with full 64-bit addresses
- ✅ Section annotations (toggleable)
- ✅ Row highlighting

#### Filter Features
- ✅ Filter by code sections
- ✅ Filter by data sections
- ✅ Show all data option
- ✅ Annotation toggle

#### Export Features
- ✅ Text format export
- ✅ Binary format export
- ✅ iOS share sheet integration

#### Help & Information
- ✅ Legend/help dialog
- ✅ Address details on selection
- ✅ Section, function, and symbol information
- ✅ Info label showing data statistics

## Technical Details

### Data Loading
- Loads entire binary file into memory using `Data(contentsOf:)`
- Supports filtering (filtered data maintained separately)
- Base address tracking with configurable offset
### Data Loading (updated)
- Prefers an in-memory cache on the `DecompiledOutput` model (`fileData`) when available.
- During the initial decompilation step the binary is read and stored in `DecompiledOutput.fileData` so viewers can use the cached copy instead of re-reading the file from disk.
- If no cached data is present, the viewer falls back to reading the file from disk with `Data(contentsOf:)` and will still warn on very large files.

### Address Calculation
- Calculates row from address: `row = (address - baseOffset) / bytesPerRow`
- Calculates address from row: `address = baseOffset + (row * bytesPerRow)`

### Memory Considerations
- Lazy loading of view controllers
- Table view cell reuse
- Efficient data slicing for row display

### Section Detection
- Uses segment and section models from analysis
- Checks if address falls within section range
- Displays section name as annotation

### Function Detection
- Uses function models from analysis
- Checks if address is within function range
- Shows function name in detail view

## Code Quality

### Design Patterns Used
- **Delegation**: For navigation callbacks
- **Lazy Initialization**: For view controllers
- **MVC**: Separation of data, view, and control logic

### Best Practices
- Monospaced fonts for hex display
- Consistent color scheme using Constants.Colors
- Error handling for invalid addresses
- User feedback for navigation actions

## Testing Considerations

While automated tests were not added (following minimal modification principle), the following manual testing should be performed:

1. **Navigation Testing**:
   - Test "Go to Address" with valid/invalid addresses
   - Test "Go to Function" picker
   - Test "Go to Section" picker

2. **Display Testing**:
   - Verify correct hex/ASCII representation
   - Check address alignment
   - Verify section annotations

3. **Integration Testing**:
   - Navigate from disassembly to hex viewer
   - Navigate from functions to hex viewer
   - Verify address highlighting works

4. **Export Testing**:
   - Export as text format
   - Export as binary format
   - Verify file contents

## Future Enhancements

Possible future improvements:
- [ ] Byte editing capability
- [ ] Data type overlays (int32, float, etc.)
- [ ] Search for byte patterns
- [ ] Bookmarks for important addresses
- [ ] Diff view comparing two binaries
- [ ] String detection highlighting
- [ ] Instruction highlighting in hex view

## Files Modified/Created

### Created
- `ReDyne/ViewControllers/HexViewerViewController.swift` (new file, ~650 lines)

### Modified
- `ReDyne/ViewControllers/AnalysisMenuViewController.swift`
- `ReDyne/ViewControllers/ResultsViewController.swift`
- `README.md`

## Documentation Updates

Updated README.md to include:
1. Hex viewer in features list
2. Hex viewer usage in Advanced Features section
3. Marked hex viewer as complete in roadmap

## Conclusion

The hex viewer feature has been successfully implemented with all requested functionality:
- ✅ Hex and ASCII visualization
- ✅ Go to address functionality
- ✅ Go to function functionality  
- ✅ Visual filter options
- ✅ Integration with analysis results
- ✅ Context menu navigation from disassembly/functions

The implementation follows the existing code patterns in the ReDyne project and provides a clean, intuitive interface for viewing binary data in hexadecimal format.
