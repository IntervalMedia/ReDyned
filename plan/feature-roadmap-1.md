---
goal: "Feature Roadmap Implementation Plan"
version: 1.0
date_created: 2025-11-27
last_updated: 2026-02-26
owner: "AI-Agent / Maintainers"
status: 'In progress'
tags: [roadmap,feature,planning]
---

# Introduction

![Status: In%20progress](https://img.shields.io/badge/status-In%20progress-yellow)

This plan maps the `Roadmap` section in `README.md` to actionable, deterministic implementation phases. Each phase lists concrete tasks, affected files, validation criteria, and tests so humans or automated agents can execute or review the work.

## 1. Requirements & Constraints

- **REQ-001**: Implement remaining roadmap features listed in `README.md` under "Roadmap".
- **REQ-002**: Changes to native code must preserve existing C API shapes unless explicitly versioned.
- **REQ-003**: Support importing a JSON file that maps function addresses to names, overwriting existing names at the same address.
- **CON-001**: Do not change public bridging types in `ReDyne-Bridging-Header.h` without updating Consumers in Swift.
- **GUD-001**: Keep heavy parsing in `ReDyne/Models/` (C) and expose functionality through `ReDyne/Services/` (Objective-C).

## 2. Implementation Steps

### Implementation Phase 1 — Finish partially-complete core features

- GOAL-001: Complete `Class Dump` and `Type Reconstruction` features (these are partially implemented per README).

| Task     | Description (files / functions)                                                                 | Completed | Date       |
| -------- | ---------------------------------------------------------------------------------------------- | --------- | ---------- |
| TASK-001 | Class Dump: finish parser in `ReDyne/Models/ClassDumpC.c` and headers in `ClassDumpC.h`. Ensure `class_dump_extract()` returns stable structures used by `ObjCAnalyzer.swift`. | Yes       | 2026-02-26 |
| TASK-002 | Type Reconstruction: complete `ReDyne/Models/TypeAnalyzerC.c` and helpers `TypeAnalyzerHelpers.h`. Implement missing reconstruction steps used by `TypeReconstructionModels.swift`. | Yes       | 2026-02-26 |
| TASK-003 | Add unit tests: `ReDyneTests/ClassDumpTests.swift`, `ReDyneTests/TypeReconstructionTests.swift` to validate outputs against sample binaries in `Tests/Fixtures/`. |           |            |

**Validation criteria (Phase 1)**
- Class Dump: `class_dump_extract()` returns class names, ivars, and method lists matching `ObjCParser.c` expectations for at least 3 sample binaries.
- Type Reconstruction: `reconstruct_type()` returns non-null type descriptors for 80% of function-local aggregates in sample binary set.

### Implementation Phase 2 — User-facing annotations and analysis

- GOAL-002: Implement `Comment annotations` and `Memory dump analysis`.

| Task     | Description (files / functions)                                                                 | Completed | Date |
| TASK-004 | Comment annotations: extend `ReDyne/Models/PseudocodeGenerator.c` and `ReDyne/Models/PseudocodeGenerator.h` to accept annotation metadata; update `DecompiledOutput.m` to serialize comment metadata to Swift. |           |      |
| TASK-005 | Memory dump analysis: add `ReDyne/Models/MemoryDump.c` (new) with symbol/address mapping helpers; expose via `ReDyne/Services/BinaryParserService.m` methods `- (NSData*)analyzeMemoryDump:...`. |           |      |
| TASK-006 | UI: Add `MemoryDumpViewController.swift` to `ReDyne/ViewControllers/` for visualizing dumps and annotations. |           |      |

**Validation criteria (Phase 2)**
- Comments: pseudocode view shows author-provided annotations, and annotations persist in exported JSON/TXT formats.
- Memory dump analysis: tool loads a memory dump file and maps at least 3 regions to known symbols/sections.

### Implementation Phase 3 — Format, Network & Runtime tooling

- GOAL-003: Add `Universal Format support`, `Network analysis`, and prototype `Runtime C Decompiler & Branch`.

| Task     | Description (files / functions)                                                                 | Completed | Date |
| TASK-007 | Universal Format support: extend `DecompiledOutput.m` and `ExportService.swift` to add a canonical `universal.json` schema; add serializer `exportAsUniversalFormat` in `DecompiledOutput.m`. |           |      |
| TASK-008 | Network analysis: add `ReDyne/Models/NetworkAnalyzer.c` (new) and `ReDyne/Services/NetworkAnalysisService.m`; provide `NetworkAnalysisViewController.swift`. |           |      |
| TASK-009 | Runtime C Decompiler & Branch: prototype changes in `ReDyne/Models/PseudocodeGenerator.c` with a `runtime_decompile()` entrypoint and a small harness `ReDyne/Services/RuntimeDecompilerService.m`. |           |      |

**Validation criteria (Phase 3)**
- Universal format: `exportAsUniversalFormat` produces a JSON that round-trips into a minimal import tool.
- Network analysis: identify at least 3 common network calls and their format from sample binaries.
- Runtime decompiler prototype: produces basic C-like pseudocode for simple functions (no full correctness requirement at prototype stage).

### Implementation Phase 4 — Function name import

- GOAL-004: Import custom JSON mapping function names to addresses and apply overrides in the functions list.

| Task     | Description (files / functions)                                                                 | Completed | Date |
| -------- | ---------------------------------------------------------------------------------------------- | --------- | ---- |
| TASK-010 | Parser: implement JSON import for a `Functions` array with decimal `Address` and `Name` fields; convert addresses to hex for display. | Yes       | 2026-02-26 |
| TASK-011 | Apply overrides: if a function already exists at the same address, overwrite its name with the imported value; otherwise insert a new function entry. | Yes       | 2026-02-26 |
| TASK-012 | UI: add an import entry point in the functions view (or results menu) to load a JSON file and refresh the function list. | Yes       | 2026-02-26 |

**Validation criteria (Phase 4)**
- Importing the provided JSON schema populates functions with hex addresses and names.
- Existing functions at the same address are renamed, not duplicated.
- Invalid JSON or missing fields surfaces a user-visible error.

## 3. Alternatives

- **ALT-001**: Implement runtime decompiler as a separate tool outside the app — rejected to keep integrated UX.
- **ALT-002**: Use third-party libraries for type reconstruction — rejected to preserve portability and repo's C-first approach.

## 4. Dependencies

- **DEP-001**: Existing models and parsers in `ReDyne/Models/` (ClassDumpC, TypeAnalyzerC, PseudocodeGenerator).
- **DEP-002**: Bridging header `ReDyne/ReDyne-Bridging-Header.h` — updates must be mirrored here.
- **DEP-003**: Test fixtures directory `Tests/Fixtures/` (create if missing) containing canonical sample binaries.

## 5. Files (affected / to create)

- **FILE-001**: `ReDyne/Models/ClassDumpC.c` (update)
- **FILE-002**: `ReDyne/Models/TypeAnalyzerC.c` (update)
- **FILE-003**: `ReDyne/Models/PseudocodeGenerator.c` (update)
- **FILE-004**: `ReDyne/Models/MemoryDump.c` (new)
- **FILE-005**: `ReDyne/Models/NetworkAnalyzer.c` (new)
- **FILE-006**: `ReDyne/Services/BinaryParserService.m` (update)
- **FILE-007**: `ReDyne/Services/RuntimeDecompilerService.m` (new, prototype)
- **FILE-008**: `ReDyne/ViewControllers/MemoryDumpViewController.swift` (new)
- **FILE-009**: `ReDyne/ViewControllers/NetworkAnalysisViewController.swift` (new)
- **FILE-010**: `ReDyne/Services/ClassDumpService.h` (new)
- **FILE-011**: `ReDyne/Services/ClassDumpService.m` (new)
- **FILE-012**: `ReDyne/Models/TypeAnalyzerC.h` (update)
- **FILE-013**: `ReDyne/Models/TypeReconstructionAnalyzer.swift` (new)
- **FILE-014**: `ReDyne/Models/TypeReconstructionModels.swift` (update)
- **FILE-015**: `ReDyne/Models/DecompiledOutput.h` (update)
- **FILE-016**: `ReDyne/ReDyne-Bridging-Header.h` (update)
- **FILE-017**: `ReDyne/ViewControllers/DecompileViewController.swift` (update)
- **FILE-018**: `ReDyne/ViewControllers/AnalysisMenuViewController.swift` (update)
- **FILE-019**: `ReDyne/ViewControllers/ResultsViewController.swift` (update)
- **FILE-020**: `ReDyne/ViewControllers/ClassDumpViewController.swift` (new)
- **FILE-021**: `ReDyne/ViewControllers/TypeReconstructionViewController.swift` (new)
- **FILE-022**: `ReDyne/Services/ExportService.swift` (update)
- **FILE-023**: `plan/feature-roadmap-1.md` (this file)
- **FILE-024**: `ReDyne/Services/FunctionNameImportService.swift` (new)
- **FILE-025**: `ReDyne/ViewControllers/ResultsViewController.swift` (update)
- **FILE-026**: `ReDyneTests/FunctionNameImportTests.swift` (new)

## 6. Testing

- **TEST-001**: `ReDyneTests/ClassDumpTests.swift` — verify class extraction matches expected JSON for 3 fixtures.
- **TEST-002**: `ReDyneTests/TypeReconstructionTests.swift` — assert reconstructed types match golden outputs for 5 functions.
- **TEST-003**: `ReDyneTests/ExportFormatTests.swift` — verify `exportAsUniversalFormat` schema compliance.
- **TEST-004**: `ReDyneTests/MemoryDumpTests.swift` — validate region mapping.
- **TEST-005**: `ReDyneTests/FunctionNameImportTests.swift` — verify JSON import, hex conversion, and override behavior.

## 7. Risks & Assumptions

- **RISK-001**: Touching bridging header may cause many Swift compile errors if types change; plan includes a migration checklist.
- **RISK-002**: Large binaries can create memory pressure; Phase 2 requires careful streaming/lazy parsing.
- **ASSUMPTION-001**: Test fixtures representative of target binaries exist or will be provided by maintainers.

## 8. Related Specifications / Further Reading

- `.github/implementation-plan.agent.md` — plan template and validation rules.
- `README.md` — Roadmap source of truth.
