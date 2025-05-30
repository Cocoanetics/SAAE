Okay, here is the refined SAAE Phase 2 Specification, incorporating the "Step 0: Diagnostic Exploration & Prototyping" as the explicit first action for implementation. This ensures the design of SAAE's diagnostic structures is data-driven.

---

**Project Name:** SAAE (Swift AST Abstractor & Editor) - Phase 2: Syntax Error Reporting

**Version:** 2.0

**Date:** October 26, 2023 (Spec Date)

**Prerequisite:** Successful completion and availability of SAAE Phase 1 (as per `001_spec_phase1.md` and subsequent enhancements documented in `002_developer_diary.md`, `003_refactoring_summary.md`, `004_phase1_enhancements.md`, `005_phase1_final_wrapup.md`, and `006_argumentparser_migration_2025.md`). The core architecture uses `SyntaxTree`, `CodeOverview`, and `ProjectOverview`.

**Goal:** To extend SAAE with the capability to identify, extract, and report detailed syntax errors present within a parsed Swift `SyntaxTree`. This phase focuses on providing comprehensive diagnostic information, including error descriptions, precise locations, severity, source code context, and any available fix-it suggestions. This feedback is crucial for enabling an LLM (or a human developer) to correct syntax issues before attempting compilation or further AST modifications.

**Implementation Approach:**

**Step 0: Diagnostic Exploration & Prototyping (First Implementation Step)**
*   **Objective:** To thoroughly understand the structure and content of `SwiftDiagnostics.Diagnostic` objects (including messages, severities, highlights, notes, and especially `FixIt`s with their `Change`s) for a diverse set of common Swift syntax errors. This will inform the final design and implementation of SAAE's diagnostic reporting structures.
*   **Tasks:**
    1.  **Create Test Fixtures:** Prepare Swift code snippets with various syntax errors.
    2.  **Develop Prototyping Utility / Unit Tests:** Write code to parse these fixtures using `SwiftParser` and `SwiftDiagnostics.ParseDiagnosticsGenerator` to obtain raw `[SwiftDiagnostics.Diagnostic]` objects.
    3.  **Inspect Raw Diagnostics:** Print or log the *complete structure* of these raw `Diagnostic` objects, paying close attention to `FixIt.Change` variants and the data they contain.
    4.  **Analyze & Refine:** Based on this exploration, finalize the detailed structure of SAAE's own diagnostic types (`SAAEDiagnostic`, `SAAEFixItChange`, etc.) to ensure they can effectively and practically represent the information from `SwiftDiagnostics` in an LLM-friendly and serializable way.

**1. Core Requirements & Functionality (To be implemented after Step 0 informs final struct design):**

1.1. **SAAE Diagnostic Data Structures (Wrappers/Adaptations of `SwiftDiagnostics`):**
    *   The SAAE API will expose its own set of diagnostic structures. These structures will be designed based on the findings of "Step 0" to effectively wrap and adapt information from `SwiftDiagnostics` types, ensuring they are `Codable`, `CustomStringConvertible`, and well-suited for LLM consumption.
    ```swift
    /// Represents a detailed syntax diagnostic from SAAE.
    public struct SAAEDiagnostic: Codable, CustomStringConvertible /* or Sendable */ {
        // --- Core Diagnostic Info ---
        public let message: String
        public let severity: SAAEDiagnosticSeverity

        // --- Precise Location of the Diagnostic Message (relative to entire source file) ---
        public let diagnosticStartLine: Int
        public let diagnosticStartColumn: Int
        public let diagnosticEndLine: Int?
        public let diagnosticEndColumn: Int?

        // --- Context: The AST Node Associated with the Diagnostic ---
        public let offendingNodeText: String? // Text of SwiftDiagnostics.Diagnostic.node
        public let offendingNodeStartLine: Int // Start line of Diagnostic.node in source
        public let offendingNodeStartColumn: Int // Start column of Diagnostic.node in source

        // --- Context: Broader Source Window ---
        public let sourceWindowContext: [SAAEContextLine] // e.g., 1 line before, error line, 1 line after diagnosticStartLine

        // --- Fix-Its ---
        public let fixIts: [SAAEFixItSuggestion]?

        // --- Optional: Additional Notes ---
        public let notes: [SAAENote]?

        public var description: String { /* ... formatted string ... */ }
    }

    public struct SAAEContextLine: Codable /* or Sendable */ {
        public let lineNumber: Int
        public let text: String
    }

    public struct SAAEFixItSuggestion: Codable /* or Sendable */ {
        public let message: String // Describes what the fix-it does
        public let changes: [SAAEFixItChange] // Describes the actual changes
    }

    /// Represents a specific change proposed by a fix-it.
    /// The exact structure will be finalized after Step 0's exploration of SwiftDiagnostics.FixIt.Change.
    /// It aims to represent changes like replacements, insertions, deletions in an LLM-friendly way.
    /// Example (conceptual, to be refined):
    public enum SAAEFixItChange: Codable /* or Sendable */ {
        case replaceText(startLine: Int, startColumn: Int, endLine: Int, endColumn: Int, newText: String)
        case insertText(atLine: Int, atColumn: Int, newText: String)
        case deleteText(startLine: Int, startColumn: Int, endLine: Int, endColumn: Int)
        case genericChange(description: String, details: [String: String]?) // For complex changes not easily categorized
    }

    public struct SAAENote: Codable /* or Sendable */ {
        public let message: String
        public let notePosition: SAAESourcePosition? // (SAAESourcePosition defined by line/col)
    }
    
    public struct SAAESourcePosition: Codable /* or Sendable */ {
        public let line: Int
        public let column: Int
    }

    public enum SAAEDiagnosticSeverity: String, Codable /* or Sendable */ {
        case error, warning, note, remark // Mapped from SwiftDiagnostics.DiagnosticSeverity
        // init(_ swiftSeverity: SwiftDiagnostics.DiagnosticSeverity) { ... }
    }
    ```

1.2. **Diagnostic Extraction from `SyntaxTree`:**
    *   **New Method on `SyntaxTree`:**
        *   `public func getDiagnostics() -> [SAAEDiagnostic]`
            *   **Input:** (Implicitly `self`, the `SyntaxTree` instance).
            *   **Action:**
                1.  Utilize `SwiftDiagnostics.ParseDiagnosticsGenerator.diagnostics(for: self.sourceFile)` to get an array of `[SwiftDiagnostics.Diagnostic]`.
                2.  Create a `SourceLocationConverter` initialized with `self.sourceFileNameForDiagnostics` and `self.sourceFile`.
                3.  For each `SwiftDiagnostics.Diagnostic` object:
                    *   Map its properties (message, severity, location, node, highlights, notes, fix-its) to the corresponding fields in an `SAAEDiagnostic` instance. This mapping will be guided by the findings from "Step 0", especially for `SAAEFixItChange`.
                    *   Use the `SourceLocationConverter` to convert byte offsets from `SwiftDiagnostics` locations/ranges into 1-based line/column numbers for all relevant SAAE diagnostic fields.
                    *   Extract `offendingNodeText` from `diagnostic.node.description`.
                    *   Assemble `sourceWindowContext` (e.g., 1 line before, line of `diagnosticStartLine`, 1 line after) from `self.fullSourceText`.
                    *   Handle potential issues like invalid characters or out-of-bounds line numbers gracefully when fetching source text for context.
            *   **Output:** An array of `SAAEDiagnostic` objects. Returns an empty array if no syntax errors or relevant diagnostics are found.

1.3. **Enhancement to `SyntaxTree` Initialization:**
    *   `SyntaxTree` initializers (`init(url:)` and `init(string:)`) *must* store:
        *   `internal let fullSourceText: String` (the original source code).
        *   `internal let sourceFileNameForDiagnostics: String` (for use in `SourceLocationConverter` and potentially in diagnostic messages).
    *   **Parsing Mode for `init(string:)`:** Will use `SwiftParser.Parser.parse(source: String)` (which parses as a full source file). Diagnostics for snippets will reflect errors related to not forming a complete, valid source file in that context.

**2. Scope:**

2.1. **Single File Focus:** The `getDiagnostics()` method on `SyntaxTree` operates strictly on the single source file/string that the `SyntaxTree` instance represents. Aggregating diagnostics across multiple files (e.g., via `ProjectOverview`) is out of scope for this phase.

**3. Technical Stack & Constraints:**

3.1. **Primary Libraries:** `swift-syntax`, `SwiftDiagnostics` (from `swift-parser` or equivalent), `SwiftSyntaxBuilder` (if needed for advanced `SourceLocationConverter` scenarios or fix-it interpretations).

**4. Deliverables:**

4.1. **Step 0 Report/Findings (Internal):** A summary of the exploration of `SwiftDiagnostics.Diagnostic` structures for various error types, and the finalized SAAE diagnostic struct definitions based on these findings.
4.2. Updated `SyntaxTree` struct with:
    *   Storage for original source code string and source file name/identifier.
    *   The new `getDiagnostics() -> [SAAEDiagnostic]` method implementing the refined extraction logic.
4.3. The public SAAE diagnostic data structures (`SAAEDiagnostic`, `SAAEDiagnosticSeverity`, `SAAEContextLine`, `SAAEFixItSuggestion`, `SAAEFixItChange`, `SAAENote`, `SAAESourcePosition`).
4.4. Unit tests covering:
    *   The "Step 0" exploratory tests/utility.
    *   Correct extraction of all fields in `SAAEDiagnostic` from `SyntaxTree` instances with known syntax errors.
    *   Accurate mapping of byte offsets to line/column numbers.
    *   Correct generation of `offendingNodeText` and `sourceWindowContext`.
    *   Effective mapping of `SwiftDiagnostics.FixIt` information to `SAAEFixItSuggestion` and `SAAEFixItChange`.
    *   Handling of files with no errors (returns empty array).
    *   Graceful handling of edge cases (e.g., invalid UTF-8 if `swift-syntax` doesn't handle it, out-of-bounds line numbers for context).
4.5. Updated SAAE documentation for `SyntaxTree` and the new diagnostic capabilities.

**5. Non-Goals for Phase 2:**

*   Automatic fixing of syntax errors by SAAE itself.
*   Any AST modification (this moves to Phase 3).
*   Semantic error reporting (type checking errors, etc.) – this phase is strictly for *syntax* errors detectable by the parser.
*   Providing a UI for displaying errors (SAAE provides the data structures).

---

This revised Phase 2 spec now explicitly includes the crucial exploratory "Step 0." The structure of `SAAEFixItChange` is marked as needing refinement based on Step 0's findings, giving the developer clear direction to investigate the best way to represent `SwiftDiagnostics.FixIt.Change` for SAAE's purposes. This iterative approach within the phase should lead to a more robust and useful implementation.
