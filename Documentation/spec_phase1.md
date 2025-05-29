Okay, here is a specification document for **Phase 1 of SAAE (Swift AST Abstractor & Editor)**, tailored for an AI Agent (or a developer acting on its behalf) to implement.

---

**Project Name:** SAAE (Swift AST Abstractor & Editor) - Phase 1

**Version:** 1.0

**Date:** October 26, 2023

**Goal:** To create a foundational Swift library (SAAE) capable of parsing Swift source code and generating a structured, read-only "overview" of its declarations. This overview will include essential details like type, name, signature, visibility, sequence-based path, and parsed documentation. The output will be available in JSON, YAML, and Markdown formats, with options for visibility filtering. This phase focuses exclusively on providing information for analysis (e.g., by an LLM or human developer) and does not include any code modification capabilities.

**1. Core Requirements & Functionality:**

1.1. **Swift Code Parsing:**
    *   SAAE must be able to parse Swift source code into an Abstract Syntax Tree (AST).
    *   It shall utilize Apple's `swift-syntax` library for all parsing activities.
    *   **Required Functions:**
        *   `func parse(from_url fileURL: URL) throws -> AST_Handle`
            *   **Input:** A `URL` pointing to a local Swift source file.
            *   **Action:** Reads the content of the file, parses it using `swift-syntax`.
            *   **Output:** An opaque `AST_Handle` that internally references the immutable `swift-syntax` `SourceFileSyntax` object.
            *   **Error Handling:** Throws an error if the file cannot be read or if `swift-syntax` reports fatal parsing errors.
        *   `func parse(from_string codeString: String) throws -> AST_Handle`
            *   **Input:** A `String` containing Swift source code.
            *   **Action:** Parses the string using `swift-syntax`.
            *   **Output:** An opaque `AST_Handle`.
            *   **Error Handling:** Throws an error if `swift-syntax` reports fatal parsing errors.
    *   **`AST_Handle` Definition:**
        *   An opaque type (e.g., a struct wrapping a `SourceFileSyntax` object, or a unique identifier like a UUID that SAAE uses to look up the stored `SourceFileSyntax` object). It represents a successfully parsed, immutable AST state.

1.2. **Overview Generation:**
    *   SAAE must provide a function to generate a structured overview of the declarations within a parsed AST.
    *   **Required Function:**
        *   `func generate_overview(ast_handle: AST_Handle, format: OutputFormat = .json, min_visibility: SAAE.VisibilityLevel = .internal) throws -> String`
            *   **Input:**
                *   `ast_handle`: The `AST_Handle` obtained from a successful parse operation.
                *   `format`: An `OutputFormat` enum (`.json`, `.yaml`, `.markdown`). Default: `.json`.
                *   `min_visibility`: A `VisibilityLevel` enum indicating the minimum visibility level of declarations to include in the overview. Default: `.internal`.
            *   **Action:** Traverses the AST associated with `ast_handle`, extracts information about relevant declarations, filters them based on `min_visibility`, and formats the output string according to `format`.
            *   **Output:** A `String` containing the generated overview.
            *   **Error Handling:** Throws an error if `ast_handle` is invalid.

1.3. **`OutputFormat` Enum:**
    *   `enum OutputFormat { case json, yaml, markdown }`

1.4. **`VisibilityLevel` Enum:**
    *   To be used for filtering and reporting declaration visibility.
    *   `enum SAAE.VisibilityLevel: Int, CaseIterable, Comparable { ... }` (as defined previously, including `open`, `public`, `package`, `internal`, `fileprivate`, `private`, with appropriate raw values for comparison). The SAAE must correctly derive the visibility of a declaration from the `swift-syntax` AST (checking for explicit keywords or applying the default `internal`).

**2. Overview Content Details:**

2.1. **Traversal & Hierarchy:**
    *   The overview generation must perform a full, recursive traversal of the AST using a `swift-syntax` `SyntaxVisitor`.
    *   It should capture declarations at all nesting levels (e.g., structs within structs, methods within classes).
    *   Declarations within any given scope should be listed in the order they appear in the source code.

2.2. **Information per Declaration:**
    *   For each Swift declaration included in the overview (after visibility filtering), the following information must be extracted and represented:
        *   `path` (String): A sequence-based path string (e.g., `"1"`, `"1.3"`, `"1.3.2"`) uniquely identifying the node's position within the overall AST structure presented in the overview. The first component is 1-indexed.
        *   `type` (String): The kind of declaration (e.g., `"struct"`, `"class"`, `"enum"`, `"protocol"`, `"extension"`, `"func"`, `"var"`, `"let"`, `"initializer"`, `"subscript"`, `"typealias"`). (The exact list of supported declaration types to be included should be comprehensive for common Swift code).
        *   `name` (String): The name of the declaration (e.g., `"MyStruct"`, `"calculateValue"`). For extensions, this might be the name of the type being extended. For initializers, it could be `"init"`. For subscripts, `"subscript"`.
        *   `full_name` (String, optional but recommended, especially for Markdown): For nested declarations, a qualified name indicating its context (e.g., `"MyStruct.InnerStruct.myMethod"`).
        *   `signature` (String, if applicable):
            *   For functions, methods, initializers, subscripts: The complete signature string, including parameter names, labels, types, return type, `async`, `throws`, generic parameters.
            *   For variables, constants, properties: The type annotation string.
        *   `visibility` (String): The string representation of the declaration's `VisibilityLevel` (e.g., `"public"`, `"internal"`).
        *   `documentation` (Object/Dictionary or Null):
            *   If Swift documentation comments (`///` or `/** */`) are present immediately preceding the declaration, they will be parsed using the provided `Documentation` struct (see section 3).
            *   The output will be a structured object: `{"description": "...", "parameters": {"name": "desc"}, "returns": "..."}`.
            *   If no such comments exist, this field should be `null` (JSON) or absent/empty.
        *   `members` (Array, for JSON/YAML, applicable to container types like structs, classes, enums, protocols, extensions): A nested list of overview entry objects for its direct child declarations (which are also subject to visibility filtering and contain all the fields listed here).
        *   `child_paths` (Array of Strings, for Markdown, applicable to container types): A list of `path` strings of its direct child declarations that are included in the overview.

2.3. **Specific Declaration Types to Include:**
    *   `struct`, `class`, `enum`, `protocol`, `extension`
    *   `func` (global and methods)
    *   `var`, `let` (global, static, instance properties)
    *   `init` (initializers)
    *   `subscript`
    *   `typealias`
    *   (Consider if `associatedtype`, `operator func`, `precedencegroup` are in scope for Phase 1 - start with the list above).

2.4. **Exclusions for Phase 1 Simplicity:**
    *   Attributes (e.g., `@MainActor`, `@propertyWrapper`) should be ignored and not included in the `signature` or as separate entries for Phase 1.
    *   The content/body of functions, methods, initializers, subscripts, and computed properties should not be included in the overview.

**3. Documentation Parsing Integration:**

3.1. **Provided `Documentation` Struct:**
    *   The SAAE implementation will be provided with an existing Swift struct:
        ```swift
        struct Documentation {
            let description: String
            let parameters: [String: String]
            let returns: String?
            init(from text: String) { /* ... implementation as provided ... */ }
        }
        ```
3.2. **Extraction Logic:**
    *   When processing a `swift-syntax` node, SAAE must access its `leadingTrivia`.
    *   It must iterate through the `TriviaPiece`s in `leadingTrivia`.
    *   It will concatenate the textual content of *only* `docLineComment` (`///`) and `docBlockComment` (`/** */`) pieces into a single string.
    *   This concatenated string will be passed to `Documentation(from: collectedDocText)` to obtain a structured `Documentation` object.
    *   This structured object will be serialized as the value for the `documentation` field in the overview.

**4. Output Format Specifics:**

4.1. **JSON & YAML:**
    *   The output must be a valid JSON or YAML string respectively.
    *   The structure must be **nested** to directly reflect the code's hierarchy, using the `members` field for child declarations.

4.2. **Markdown:**
    *   The output must be a valid Markdown string.
    *   The structure must be **flattened**. Each declaration (regardless of nesting level in code) will be a top-level section in the Markdown.
    *   Nesting relationships will be indicated by:
        *   The `full_name` field (e.g., `## Struct: MyType.NestedType`).
        *   For container types, a "Children:" list referencing the `full_name` (or just `name`) and `path` of its direct members included in the overview.
    *   The structured `documentation` object must be rendered appropriately (e.g., description as paragraph, parameters as a bulleted list, returns as a "Returns:" section).

**5. Technical Stack & Constraints:**

5.1. **Primary Library:** Apple's `swift-syntax`. The implementation must leverage this library for all AST parsing, traversal, and information extraction.
5.2. **Language:** Swift.
5.3. **Environment:** Assumed to be a Swift Package Manager project.
5.4. **No Code Modification:** Phase 1 is strictly read-only. No AST modification capabilities are to be implemented.
5.5. **No External Dependencies (beyond `swift-syntax` and standard Swift libraries):** For YAML output, a suitable Swift YAML serialization library may be permitted if necessary and simple to integrate. JSON can use `JSONEncoder`. Markdown is string construction.

**6. Deliverables:**

6.1. A Swift library (SAAE module) implementing the functions and types specified.
6.2. Unit tests covering:
    *   Parsing of valid Swift code (from string and URL).
    *   Correct error handling for invalid input/parse failures.
    *   Generation of overviews in all three formats (JSON, YAML, Markdown).
    *   Correct extraction of all specified declaration details (path, type, name, signature, visibility).
    *   Accurate parsing and structuring of documentation comments using the provided `Documentation` struct.
    *   Correct visibility filtering based on the `min_visibility` parameter.
    *   Correct representation of nested structures in JSON/YAML and flattened representation in Markdown.

**7. Non-Goals for Phase 1:**

*   Any form of AST modification or code writing.
*   Semantic analysis beyond what `swift-syntax` directly provides (e.g., no type resolution across files, no call graph analysis).
*   Integration with SourceKit-LSP.
*   A command-line interface (unless trivial to add for testing; the primary deliverable is the library API).
*   Performance optimization beyond reasonable implementation practices.
*   Support for Swift versions prior to one that `swift-syntax` robustly supports (assume modern Swift, e.g., 5.7+ or as specified by the `swift-syntax` version used).

---

This specification should provide a clear roadmap for the AI Agent (or developer) tasked with implementing Phase 1 of SAAE. It defines the inputs, outputs, core logic, and constraints.
