import Foundation

/// Provides a library of predefined patch templates for common patching scenarios
final class PatchTemplateLibrary {
    static let shared = PatchTemplateLibrary()
    
    private init() {
        loadTemplates()
    }
    
    private(set) var templates: [PatchTemplate] = []
    
    private func loadTemplates() {
        templates = [
            createNOPTemplate(),
            createReturnValueTemplate(),
            createJumpTemplate(),
            createFunctionBypassTemplate(),
            createLoggingTemplate(),
            createSecurityCheckTemplate()
        ]
    }
    
    /// Returns templates for a specific category
    func templates(for category: PatchTemplate.Category) -> [PatchTemplate] {
        return templates.filter { $0.category == category }
    }
    
    /// Search templates by name, description, or tags
    func search(query: String) -> [PatchTemplate] {
        let lowercasedQuery = query.lowercased()
        return templates.filter { template in
            template.name.lowercased().contains(lowercasedQuery) ||
            template.description.lowercased().contains(lowercasedQuery) ||
            template.tags.contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }
    
    // MARK: - Template Definitions
    
    private func createNOPTemplate() -> PatchTemplate {
        return PatchTemplate(
            name: "NOP Out Instructions",
            description: "Replace existing instructions with NOP (No Operation) to disable specific code paths without breaking control flow.",
            category: .debugging,
            difficulty: .beginner,
            icon: "minus.circle",
            instructions: [
                TemplateInstruction(
                    step: 1,
                    title: "Locate Target Instructions",
                    detail: "Use the disassembler to find the instructions you want to disable. Note the file offset.",
                    arm64Pattern: "NOP = 0x1F2003D5",
                    example: "File offset: 0x1234 (4 bytes)"
                ),
                TemplateInstruction(
                    step: 2,
                    title: "Create Patch",
                    detail: "Create a new patch with the original instruction bytes and replace them with NOP instructions.",
                    example: "Original: 0xF81F0FFE → Patched: 0x1F2003D5"
                ),
                TemplateInstruction(
                    step: 3,
                    title: "Verify and Apply",
                    detail: "Verify the patch matches the binary and apply it to create a modified version.",
                    example: nil
                )
            ],
            tags: ["nop", "disable", "bypass", "beginner"]
        )
    }
    
    private func createReturnValueTemplate() -> PatchTemplate {
        return PatchTemplate(
            name: "Modify Return Values",
            description: "Change function return values to force specific behaviors, useful for bypassing checks or testing edge cases.",
            category: .debugging,
            difficulty: .intermediate,
            icon: "arrow.uturn.backward",
            instructions: [
                TemplateInstruction(
                    step: 1,
                    title: "Find Return Statement",
                    detail: "Locate the RET instruction and preceding return value setup (typically MOV W0/X0).",
                    arm64Pattern: "MOV W0, #value\nRET",
                    example: "MOV W0, #0 → Returns 0\nMOV W0, #1 → Returns 1"
                ),
                TemplateInstruction(
                    step: 2,
                    title: "Modify Return Value",
                    detail: "Patch the MOV instruction to set your desired return value.",
                    example: "Change MOV W0, #0 to MOV W0, #1"
                ),
                TemplateInstruction(
                    step: 3,
                    title: "Test Behavior",
                    detail: "Apply the patch and test the modified binary to ensure it behaves as expected.",
                    example: nil
                )
            ],
            tags: ["return", "value", "function", "bypass"]
        )
    }
    
    private func createJumpTemplate() -> PatchTemplate {
        return PatchTemplate(
            name: "Unconditional Jump",
            description: "Convert conditional branches to unconditional jumps to force specific code paths.",
            category: .reverseEngineering,
            difficulty: .intermediate,
            icon: "arrow.right",
            instructions: [
                TemplateInstruction(
                    step: 1,
                    title: "Identify Conditional Branch",
                    detail: "Find conditional branches (B.EQ, B.NE, CBZ, CBNZ) that control program flow.",
                    arm64Pattern: "B.EQ label → B label\nCBZ X0, label → B label",
                    example: nil
                ),
                TemplateInstruction(
                    step: 2,
                    title: "Replace with Unconditional",
                    detail: "Replace the conditional branch with an unconditional branch (B) to force the path.",
                    example: "B.NE +0x10 → B +0x10"
                ),
                TemplateInstruction(
                    step: 3,
                    title: "Verify Control Flow",
                    detail: "Use the CFG analyzer to verify the control flow is as expected after the patch.",
                    example: nil
                )
            ],
            tags: ["jump", "branch", "control flow", "conditional"]
        )
    }
    
    private func createFunctionBypassTemplate() -> PatchTemplate {
        return PatchTemplate(
            name: "Function Bypass",
            description: "Completely bypass a function by immediately returning, useful for disabling unwanted functionality.",
            category: .customization,
            difficulty: .beginner,
            icon: "arrow.right.to.line",
            instructions: [
                TemplateInstruction(
                    step: 1,
                    title: "Find Function Entry",
                    detail: "Locate the function prologue (typically starting with STP or SUB SP).",
                    arm64Pattern: "STP X29, X30, [SP,#-16]!",
                    example: "Function at 0x1000"
                ),
                TemplateInstruction(
                    step: 2,
                    title: "Insert Early Return",
                    detail: "Replace the prologue with a simple return (RET) to exit immediately.",
                    example: "STP X29, X30... → RET (0xD65F03C0)"
                ),
                TemplateInstruction(
                    step: 3,
                    title: "Consider Return Value",
                    detail: "If the function returns a value, add MOV W0/X0 before RET.",
                    arm64Pattern: "MOV W0, #0\nRET",
                    example: nil
                )
            ],
            tags: ["bypass", "disable", "function", "return"]
        )
    }
    
    private func createLoggingTemplate() -> PatchTemplate {
        return PatchTemplate(
            name: "Inject Logging Calls",
            description: "Add logging or tracing calls to monitor program execution at specific points.",
            category: .debugging,
            difficulty: .advanced,
            icon: "doc.text",
            instructions: [
                TemplateInstruction(
                    step: 1,
                    title: "Locate Injection Point",
                    detail: "Find the location where you want to add logging. Note register usage.",
                    example: "Before function call at 0x2000"
                ),
                TemplateInstruction(
                    step: 2,
                    title: "Save Register Context",
                    detail: "Save registers that will be used by the logging call.",
                    arm64Pattern: "STP X0, X1, [SP,#-16]!",
                    example: nil
                ),
                TemplateInstruction(
                    step: 3,
                    title: "Add Logging Call",
                    detail: "Insert BL instruction to call your logging function.",
                    arm64Pattern: "BL log_function",
                    example: "Requires code cave or trampolines"
                ),
                TemplateInstruction(
                    step: 4,
                    title: "Restore Context",
                    detail: "Restore saved registers and continue normal execution.",
                    arm64Pattern: "LDP X0, X1, [SP], #16",
                    example: nil
                )
            ],
            tags: ["logging", "tracing", "debugging", "injection", "advanced"]
        )
    }
    
    private func createSecurityCheckTemplate() -> PatchTemplate {
        return PatchTemplate(
            name: "Bypass Security Checks",
            description: "Disable common security mechanisms for research and testing purposes.",
            category: .security,
            difficulty: .advanced,
            icon: "lock.open",
            instructions: [
                TemplateInstruction(
                    step: 1,
                    title: "Identify Security Function",
                    detail: "Locate functions like signature verification, license checks, or authentication.",
                    example: "Find 'verify_signature' or similar"
                ),
                TemplateInstruction(
                    step: 2,
                    title: "Analyze Check Logic",
                    detail: "Understand what values indicate success vs failure.",
                    example: "Returns 0 for success, 1 for failure"
                ),
                TemplateInstruction(
                    step: 3,
                    title: "Force Success Path",
                    detail: "Modify the function to always return the success value.",
                    arm64Pattern: "MOV W0, #0\nRET",
                    example: nil
                ),
                TemplateInstruction(
                    step: 4,
                    title: "Test Thoroughly",
                    detail: "Verify the bypass works correctly and doesn't break other functionality.",
                    example: "⚠️ Use only for authorized research"
                )
            ],
            tags: ["security", "bypass", "authentication", "verification", "advanced"]
        )
    }
}
