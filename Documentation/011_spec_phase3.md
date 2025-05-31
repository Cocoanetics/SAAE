
**Project Name:** SAAE (Swift AST Abstractor & Editor) - Phase 3: Targeted AST Modifications

**Version:** 3.0

**Date:** October 26, 2023 (Spec Date)

**Prerequisite:**
*   Successful completion of SAAE Phase 1: Read-Only AST Overview & LLM Context Building. SAAE can parse Swift code into an immutable `SyntaxTree` and generate detailed structural overviews (e.g., via `CodeOverview.generate_overview()`).
*   Successful completion of SAAE Phase 2: Syntax Error Reporting. SAAE's `SyntaxTree` can report detailed syntax errors within it (via `SyntaxTree.getDiagnostics() -> [SAAEDiagnostic]`).

**Goal:**
To empower SAAE with reliable and well-tested capabilities to perform targeted modifications on a Swift `SyntaxTree`. This includes adding/updating documentation (leading trivia), replacing existing syntax nodes with new pre-validated `Syntax` objects, deleting nodes, and inserting new pre-validated `Syntax` objects relative to existing ones. Operations will be addressable via node sequence paths. All modifications will result in a new, immutable `SyntaxTree` state, which can then be serialized back to Swift source code. This phase provides the foundational editing primitives for programmatic code manipulation.

**1. Core Principles:**

*   **Immutability:** All modification functions will take a `SyntaxTree` as input and return a *new* `SyntaxTree` instance representing the modified AST. The original `SyntaxTree` remains unchanged.
*   **Addressability via Node Path:** Modifications will target nodes identified by their `path` (a sequence-based path string, e.g., `"1.3.2"`) as obtainable from SAAE's Phase 1 overview generation. The caller is responsible for ensuring the `path` is valid for the input `SyntaxTree`.
*   **Pre-Validated Inputs:** Functions that introduce new Swift code structures (`replaceNode`, `insertNodes`) will expect these new structures to be provided as already parsed and syntactically validated `swift-syntax` `Syntax` objects (or collections thereof). The SAAE client/orchestrator is responsible for this pre-validation (e.g., by parsing a string from an LLM into a temporary `SyntaxTree` and checking its diagnostics using SAAE Phase 2's `getDiagnostics()` method).
*   **Syntactic Focus:** Modifications are primarily syntactic. SAAE Phase 3 aims to produce syntactically valid ASTs based on valid inputs. Full semantic correctness (e.g., type checking across a project) is out of scope.
*   **Leverage `SyntaxRewriter`:** Apple's `swift-syntax` `SyntaxRewriter` class will be the primary mechanism for implementing AST transformations.

**2. Core SAAE Modification Functions:**

These functions will likely be methods on the `SyntaxTree` struct or top-level functions that operate on `SyntaxTree` instances.

2.1. **Modify/Add Leading Trivia (Documentation):**
	*   **Function Signature:** `func modifyLeadingTrivia(forNodeAtPath nodePath: String, newLeadingTriviaText: String?) throws -> SyntaxTree`
	*   **Input:**
		*   `self` (`SyntaxTree`): The current AST.
		*   `nodePath`: The sequence-based path string to the declaration node whose leading trivia is to be modified.
		*   `newLeadingTriviaText`: An optional `String` containing the new, complete leading trivia (e.g., `/// New line 1\n/// New line 2`). If `nil` or empty, existing *documentation-specific* leading trivia (`docLineComment`, `docBlockComment`) for the node should be removed.
	*   **Action:** Uses a `SyntaxRewriter` to locate the target node. It then modifies the node's `leadingTrivia` by removing existing documentation comments and prepending new `TriviaPiece`s constructed from `newLeadingTriviaText`. Non-documentation leading trivia should be preserved.
	*   **Output:** A new `SyntaxTree` instance reflecting the modified trivia.
	*   **Error Handling:** Throws `NodeOperationError` (e.g., `.nodeNotFound`).

2.2. **Replace Node with New Parsed Syntax:**
	*   **Function Signature:** `func replaceNode(atPath nodePath: String, withNewNode newNode: Syntax) throws -> SyntaxTree`
	*   **Input:**
		*   `self` (`SyntaxTree`): The current AST.
		*   `nodePath`: The path to the `Syntax` node to be replaced.
		*   `newNode: Syntax`: A `swift-syntax` `Syntax` node (or a suitable syntax collection like `CodeBlockItemListSyntax` if replacing multiple items, though the API might be simplified to one-for-one replacement initially) that has been pre-parsed and syntactically validated by the caller.
	*   **Action:** Uses a `SyntaxRewriter` to locate the original node by `nodePath` and replace it with `newNode`. The rewriter must validate that `newNode` is a contextually valid replacement for the original node's position in the AST (e.g., a statement can replace a statement).
	*   **Output:** A new `SyntaxTree` instance with the node replaced.
	*   **Error Handling:** Throws `NodeOperationError` (e.g., `.nodeNotFound`, `.invalidReplacementContext`).

2.3. **Delete Node:**
	*   **Function Signature:** `func deleteNode(atPath nodePath: String) throws -> (deletedNodeSourceText: String?, newTree: SyntaxTree)`
	*   **Input:**
		*   `self` (`SyntaxTree`): The current AST.
		*   `nodePath`: The path to the `Syntax` node to be deleted.
	*   **Action:** Uses a `SyntaxRewriter` to locate and remove the target node from its parent's collection. Surrounding trivia should be handled to maintain clean formatting. The source text of the deleted node is captured before removal.
	*   **Output:** A tuple containing an optional `String` (the source text of the deleted node) and the new `SyntaxTree` instance with the node removed.
	*   **Error Handling:** Throws `NodeOperationError` (e.g., `.nodeNotFound`).

2.4. **Insert Node(s) Relative to an Existing Node:**
	*   **Function Signature:** `func insertNodes(_ newNodes: [Syntax], relativeToNodeAtPath anchorNodePath: String, position: InsertionPosition) throws -> SyntaxTree`
	*   **Supporting Enum:** `public enum InsertionPosition { case before, after }`
	*   **Input:**
		*   `self` (`SyntaxTree`): The current AST.
		*   `newNodes: [Syntax]`: An array of `swift-syntax` `Syntax` nodes, pre-parsed and syntactically validated by the caller, to be inserted.
		*   `anchorNodePath`: The path to an existing node that serves as the anchor for the insertion.
		*   `position`: Specifies whether to insert `newNodes` `.before` or `.after` the `anchorNode`.
	*   **Action:** Uses a `SyntaxRewriter` to locate the `anchorNode`. It then modifies the `anchorNode`'s parent collection to insert `newNodes` at the appropriate index relative to the `anchorNode`. The insertion must be contextually valid.
	*   **Output:** A new `SyntaxTree` instance reflecting the insertion.
	*   **Error Handling:** Throws `NodeOperationError` (e.g., `.nodeNotFound`, `.invalidInsertionPoint`).

2.5. **Error Enum for Node Operations:**
	```swift
	public enum NodeOperationError: Error {
		/// The specified node path could not be resolved in the AST.
		case nodeNotFound(path: String)

		/// The attempted insertion is not valid for the anchor node's context.
		case invalidInsertionPoint(reason: String)

		/// The new node is not a valid replacement for the original node in its current context.
		case invalidReplacementContext(reason: String)

		/// A generic failure occurred during the AST modification process.
		case astModificationFailed(reason: String)
		// Note: Errors related to parsing new code snippets are now handled by the client
		// using SAAE Phase 2's `SyntaxTree.getDiagnostics()` *before* calling these Phase 3 functions.
	}
	```

**3. Workflow for Client/LLM Interaction (Example with `replaceNode`):**

1.  **LLM generates `newSwiftCodeString`** intended to replace a node at `targetPath` in `currentTree: SyntaxTree`.
2.  **Client/Orchestrator (using SAAE Phase 2):**
	a.  `let snippetTree = try SyntaxTree(string: newSwiftCodeString, fileNameForDiagnostics: "llm_snippet.swift")`
	b.  `let snippetDiagnostics = snippetTree.getDiagnostics()`
	c.  **If `snippetDiagnostics` contains errors:** Send these errors (e.g., `[SAAEDiagnostic]`) back to the LLM for correction. LLM provides corrected code. Repeat from step 2a.
3.  **Client/Orchestrator (using SAAE Phase 3, if snippet is clean):**
	a.  Extract the relevant `Syntax` node(s) from `snippetTree.sourceFile` (e.g., the first statement if it's a single declaration: `guard let replacementNode = snippetTree.sourceFile.statements.first?.item else { /* error: snippet empty or not a single item */ }`).
	b.  `let resultTree = try currentTree.replaceNode(atPath: targetPath, withNewNode: replacementNode)`
	c.  `currentTree = resultTree`
4.  Client handles potential `NodeOperationError`s from the SAAE Phase 3 call (e.g., `.invalidReplacementContext`).
5.  Client can now `currentTree.serializeToCode()` to get the updated source string.

**4. Serialization:**

*   The existing function (likely `SyntaxTree.serializeToCode() -> String` or similar from Phase 1/2 evolution) will be used to convert the new `SyntaxTree` instances back into Swift source code strings.

**5. Unit Testing Strategy (Critical Deliverable):**

A comprehensive suite of unit tests must validate each modification function, focusing on the AST manipulation logic and assuming valid `Syntax` objects are provided for new code. Tests should cover:
*   **`modifyLeadingTrivia`:** Adding, replacing, removing documentation; preservation of non-doc trivia; correct newline/spacing.
*   **`replaceNode`:** Replacement with contextually valid `Syntax` nodes; correct error throwing for contextually invalid replacements; various node types and positions.
*   **`deleteNode`:** Deletion of various node types; accurate `deletedNodeSourceText`; clean trivia handling.
*   **`insertNodes`:** Insertion `before`/`after`; insertion of single/multiple nodes; correct error throwing for contextually invalid insertions.
*   **General:** Operations on nodes at start/middle/end of collections; error handling for invalid `nodePath`s; ensuring unrelated AST parts are unaffected.
*   **Post-Modification Verification:** After each modification, generating an overview (`generate_overview` from Phase 1) or checking diagnostics (`getDiagnostics` from Phase 2) on the *new* `SyntaxTree` should reflect the changes accurately.

**6. Technical Considerations:**

*   **`SyntaxRewriter` Implementation:** Custom `SyntaxRewriter` subclasses will be the core of implementing these transformations. They need to correctly identify target nodes via paths and perform structural changes to collections (e.g., `CodeBlockItemListSyntax`, `MemberDeclListSyntax`).
*   **Path Resolution in Rewrites:** For simplicity in Phase 3, each public SAAE modification function should ideally perform a single conceptual rewrite pass. If a single operation involves multiple internal changes that could shift paths, careful path management or re-resolution within that operation will be needed.
*   **Trivia Handling:** Special attention must be paid to preserving or intelligently adjusting trivia (whitespace, comments) around modified, inserted, or deleted nodes to maintain readable and well-formatted output code.

**7. Deliverables:**

7.1. Updated SAAE Swift library with the new Phase 3 modification functions and supporting types (e.g., `InsertionPosition`, `NodeOperationError`).
7.2. A comprehensive suite of unit tests as outlined, demonstrating the correctness and robustness of each AST modification operation.
7.3. Updated SAAE documentation (README, API documentation) for Phase 3 functionalities, including clear examples of the two-step workflow (client validates snippet, then calls SAAE to modify).

**8. Non-Goals for Phase 3:**

*   SAAE performing syntax validation of raw code strings *within* the modification functions themselves (this is delegated to the client using Phase 2 tools).
*   Full semantic analysis or integration with SourceKit-LSP.
*   Automatic, complex import management (beyond the basic `import OSLog` from Phase 2).
*   Complex, multi-stage refactorings (e.g., "Rename Symbol Project-Wide") as single SAAE operations. SAAE provides the primitives for such orchestrations.
*   Automatic code formatting beyond `swift-syntax`'s default serialization behavior.

---

This self-contained Phase 3 specification clearly defines the scope, responsibilities, and critical testing requirements, setting the stage for building powerful yet focused AST editing capabilities within SAAE.
