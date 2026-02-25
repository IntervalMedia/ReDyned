<!-- Copied/created by AI assistant: concise, actionable guidance for coding agents -->
**Purpose**: Help an AI coding agent be productive in the ReDyne codebase (iOS app combining C/ObjC parsing engines and a Swift UI).

**Big Picture**
- **Architecture**: native iOS app with three primary layers: C-based parsing/decoding models (`ReDyne/Models/*.c`), Objective-C service wrappers (`ReDyne/Services/*.h/.m`), and Swift UI/presentation (`ReDyne/ViewControllers/`, `ReDyne/Utilities/`). Traces and outputs pass from C -> ObjC wrapper -> Swift via the bridging header `ReDyne/ReDyne-Bridging-Header.h`.
- **Core responsibilities**:
  - Binary parsing & Mach-O handling: `ReDyne/Models/MachOHeader.c`, `MachOHeader.h`
  - Disassembly & decoding: `ReDyne/Models/DisassemblyEngine.c`, `ARM64InstructionDecoder.c`
  - Pseudocode generation: `ReDyne/Models/PseudocodeGenerator.c`
  - Symbol and table management: `ReDyne/Models/SymbolTable.c`, `SymbolTable.h`
  - High-level services exposing parsing to Swift: `ReDyne/Services/BinaryParserService.{h,m}`, `BinaryParserService.m`

**Actionable developer workflows**
- Open project in Xcode GUI: `open ReDyne.xcodeproj` → select `ReDyne` target → Build (Cmd+B).
- Run tests in Xcode: select `ReDyneTests` scheme → Test (Cmd+U).
- CLI build & test examples (use simulator destination):
  - Build: `xcodebuild -project ReDyne.xcodeproj -scheme ReDyne -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 14' build`
  - Run tests: `xcodebuild test -project ReDyne.xcodeproj -scheme ReDyneTests -destination 'platform=iOS Simulator,name=iPhone 14'`
- Common fixes during development:
  - If Swift complains about missing types from C/ObjC, confirm bridging header path in Build Settings: `ReDyne/ReDyne-Bridging-Header.h`.
  - If you get linker errors (`Undefined symbols for architecture arm64`), make sure `.c` / `.m` files are listed under **Compile Sources** in the `ReDyne` target.
  - C code uses GNU11; Objective-C uses ARC; Swift 5 is the language target.

**Patterns & conventions specific to this repo**
- Heavy computation and parsing belong in C (`ReDyne/Models/`) to maximize portability and performance — prefer modifying or extending C decoders for instruction-level behavior.
- Objective-C services in `ReDyne/Services/` are thin adapters: they marshal between raw C structures and Swift-friendly objects. Inspect `BinaryParserService.m` and `DecompiledOutput.m` to understand data shapes crossing the boundary.
- UI code lives in Swift under `ReDyne/ViewControllers/` and expects service APIs to be synchronous-ish but called from background queues; keep long-running work off the main thread.
- Info.plist contains scene configuration; project uses UIKit (not SwiftUI). If you change scene keys, update `ReDyne/Main/SceneDelegate.m` accordingly.

**Integration points to inspect first (quick-start checklist)**
- `ReDyne/Models/DisassemblyEngine.c` — where disassembly starts
- `ReDyne/Models/PseudocodeGenerator.c` — pseudocode and output formatting
- `ReDyne/Services/BinaryParserService.m` — how parsed results are exposed to Swift
- `ReDyne/Models/DecompiledOutput.m` — exporting/serializing results
- `ReDyne/Services/FunctionNameImportService.swift` — JSON function name import and override behavior
- `ReDyne/ReDyne-Bridging-Header.h` — which ObjC headers are exposed to Swift
- `ReDyne/Main/AppDelegate.m` & `ReDyne/Main/SceneDelegate.m` — app lifecycle
- `ReDyneTests/DisassemblyTests.swift` — exemplar unit tests for parsing logic

**ViewControllers to inspect**
- `ReDyne/ViewControllers/FilePickerViewController.swift` — entry UI for selecting binaries (initial launch)
- `ReDyne/ViewControllers/ResultsViewController.swift` — shows parsed results and navigation to details
- `ReDyne/ViewControllers/DecompileViewController.swift` — main decompile/pseudocode display
- `ReDyne/ViewControllers/PseudocodeViewController.swift` — pseudocode rendering and formatting
- `ReDyne/ViewControllers/CFGViewController.swift` — control-flow graph visualization
- `ReDyne/ViewControllers/HexViewerViewController.swift` — raw section hex display
- `ReDyne/ViewControllers/CodeSignatureViewController.swift` — code signature and signing info
- `ReDyne/ViewControllers/ObjCClassesViewController.swift` — Objective-C class browser
- `ReDyne/ViewControllers/ResultsViewController.swift` — Functions list and JSON import entry point
- `ReDyne/ViewControllers/XrefsViewController.swift` — cross-references and call sites
- `ReDyne/ViewControllers/ImportsExportsViewController.swift` — export/import symbol listing
- `ReDyne/ViewControllers/MemoryMapViewController.swift` — segment/section map
- `ReDyne/ViewControllers/DiffViewController.swift` — binary diff UI
- `ReDyne/ViewControllers/DependencyViewController.swift` — binary dependency listing
- `ReDyne/ViewControllers/BinaryPatchDashboardViewController.swift` — patching overview
- `ReDyne/ViewControllers/BinaryPatchDetailViewController.swift` — patch detail editor
- `ReDyne/ViewControllers/BinaryPatchEditorViewController.swift` — in-place patch editing UI
- `ReDyne/ViewControllers/PatchTemplateBrowserViewController.swift` — patch template browsing
- `ReDyne/ViewControllers/PatchTemplateDetailViewController.swift` — template detail view

**Debugging & testing tips**
- Enable an Exception Breakpoint in Xcode when debugging crashes.
- Add logs near boundaries (C -> ObjC -> Swift) to verify memory layout and ownership; prefer small, local repro with a known sample binary.
- Function name JSON import schema uses `Functions` with `Address` (decimal) and `Name`; imported names overwrite existing functions at the same address.
- For performance regressions, profile with Instruments (Time Profiler, Allocation) focusing on functions in `Models/`.

**When changing native code**
- If you add `.c` or `.m` files, open `ReDyne.xcodeproj` and add them to the `ReDyne` target **Compile Sources**; otherwise tests and app builds will fail with missing symbols.
- Keep public C APIs stable. The Swift layer depends on specific struct layouts and function names (search for `mach-o` handling in `MachOHeader.c`).

**What not to assume**
- The UI layer expects pre-processed, Swift-friendly objects from Services — do not directly import or call C internals from Swift (use ObjC wrappers declared in the bridging header).
- App may be tested with simulator binaries; many samples used for development are unencrypted dylibs (App Store binaries are encrypted and will fail parsing).

**Changelog rule**
- After editing any code or docs, update CHANGELOG.md with a concise entry in the appropriate section (or Unreleased if no release exists yet).

Please review and tell me if you want additions (examples of ViewController filenames to reference, or explicit code snippets showing the C->ObjC->Swift call pattern).

**Sub-agent Implementation Plan**
- Location: `.github/implementation-plan.agent.md`
- Purpose: machine-oriented planning template used by "planning-mode" agents to produce deterministic, parseable implementation plans. This file defines the required front-matter, strict task naming (e.g. `REQ-`, `TASK-`), and output location conventions (plans saved to `/plan/`).
- How agents should use it:
  - Read-only reference: treat this as a template and example for generating structured plans — do **not** auto-execute the plan file itself.
  - When asked to generate an implementation plan, produce a plan that conforms to the template fields and validation rules in `.github/implementation-plan.agent.md`.
  - Ensure plans include precise file paths, completion criteria, and testing steps so humans or other agents can act deterministically.
  - Save generated plans under the `/plan/` directory using the naming convention specified in the template.
- Notes for humans: this template is intentionally strict and machine-readable; agents may produce extra artifacts (checklists, diffs) but human reviewers should verify assumptions before applying automated edits.

**Example Plan**
- A minimal example plan is provided at `/plan/feature-example-plan-1.md`. Use it as a starting point when generating new plans that must conform to the strict template in `.github/implementation-plan.agent.md`.

**Roadmap Plans**
- The repository provides a roadmap feature plan at `/plan/feature-roadmap-1.md` which maps the `Roadmap` items in `README.md` to deterministic phases and tasks. Agents should consult this file when asked to produce implementation plans or to propose feature work that aligns with project priorities.
