import Testing
import Foundation
import SwiftSyntax
@testable import SAAE

struct Phase3_ASTModificationTests {

    @Test func testBasicNodeReplacementAndTrivia() throws {
        // Test basic node replacement, deletion, and trivia modification
        let swiftCode = """
        public struct MyStruct {
            /// Old doc
            public func foo() {}
            public func bar() {}
        }
        """
        let tree = try SyntaxTree(string: swiftCode)

        // TOKEN PATHS (1-indexed for API, token-centric counting by rewriters)
        // public(1) struct(2) MyStruct(3) {(4)
        // /// Old doc (trivia on token 5: public)
        // public(5) func(6) foo(7) ((8) )(9) {(10) }(11)
        // public(12) func(13) bar(14) ((15) )(16) {(17) }(18)
        // }(19)

        let publicStructTokenPath = "1" // Target 'public' of struct for doc comment
        let fooFuncTokenPath = "6"      // Target 'func' keyword of foo()
        let barFuncTokenPath = "13"     // Target 'func' keyword of bar()

        // Replace 'func' of bar() with a new 'func' token that has a trailing space
        var newFuncTokenWithSpace = TokenSyntax.keyword(.func)
        newFuncTokenWithSpace.trailingTrivia = .spaces(1) // Direct assignment
        let replacedTree = try tree.replaceNode(atPath: barFuncTokenPath, withNewNode: Syntax(newFuncTokenWithSpace))

        // Delete 'func' of foo()
        let (deletedText, deletedTree) = try replacedTree.deleteNode(atPath: fooFuncTokenPath)
        #expect(deletedText?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) == "func")
        
        let deletedSource = deletedTree.serializeToCode()
        #expect(!deletedSource.contains("public func foo()"))
        #expect(deletedSource.contains("public foo()")) // func keyword removed

        // Modify leading trivia for the 'public' token of the struct
        let docTree = try deletedTree.modifyLeadingTrivia(forNodeAtPath: publicStructTokenPath, newLeadingTriviaText: "/// New doc")
        let docSource = docTree.serializeToCode()
        
        // Expected: /// New doc
        //           public struct MyStruct ...
        #expect(docSource.contains("/// New doc\npublic struct MyStruct"))

        // Check source of docTree carefully
        // foo() is now "public foo() {}"
        // bar() is still "public func bar() {}" (its func token was replaced by another func token with a space)
        #expect(docSource.contains("public foo() {}"))
        #expect(docSource.contains("public func bar() {}"))

        // Test: Replace the 'bar' identifier token (token 14) with 'baz'
        // This uses a fresh tree to isolate its effect.
        let barIdentifierTokenPath = "14"
        let initialTreeForBarRename = try SyntaxTree(string: swiftCode) 
        var bazToken = TokenSyntax.identifier("baz")
        bazToken.trailingTrivia = [] // Ensure no unwanted trivia by assigning empty
        let renamedBarTree = try initialTreeForBarRename.replaceNode(atPath: barIdentifierTokenPath, withNewNode: Syntax(bazToken))
        let renamedBarSource = renamedBarTree.serializeToCode()
        #expect(renamedBarSource.contains("public func baz()"))
        #expect(!renamedBarSource.contains("public func bar()"))
    }

    @Test func testErrorCasesForNodeReplacementAndInsertion() throws {
        let swiftCode = "public struct S { public func f() {} }"
        let tree = try SyntaxTree(string: swiftCode)
        // Nonexistent path for replaceNode
        do {
            _ = try tree.replaceNode(atPath: "999.999", withNewNode: Syntax(fromProtocol: tree.sourceFile))
            Issue.record("Expected nodeNotFound error for replaceNode")
        } catch let err as NodeOperationError {
            // Expect .nodeNotFound or a similar error indicating path issue
            #expect(err.description.lowercased().contains("node not found"))
        }

        // Insertion - currently not implemented, should throw specific error from API due to rewriter.
        // The rewriter sets foundAnchor = false and invalidContextReason.
        // The API should throw nodeNotFound because foundAnchor is false.
        do {
            _ = try tree.insertNodes([Syntax(fromProtocol: tree.sourceFile)], relativeToNodeAtPath: "1", position: .before)
            Issue.record("Expected nodeNotFound error for insertNodes due to not finding anchor")
        } catch let err as NodeOperationError {
             #expect(err.description.lowercased().contains("node not found at path: 1"))
        }
    }

    @Test func testTriviaModificationOnTokens() throws {
        // Only tokens can have trivia set
        let swiftCode = "public struct S { public func f() {} }"
        let tree = try SyntaxTree(string: swiftCode)
        // Try to set trivia on a token (should succeed)
        // Path "1" is the 'public' token of struct S.
        let structPath = "1" 
        _ = try? tree.modifyLeadingTrivia(forNodeAtPath: structPath, newLeadingTriviaText: "/// Token doc")
        let modifiedTree = try tree.modifyLeadingTrivia(forNodeAtPath: structPath, newLeadingTriviaText: "/// Token doc")
        let finalSource = modifiedTree.serializeToCode()
        #expect(finalSource.contains("/// Token doc\npublic struct S"))
    }

    @Test func testDeleteNodeAndSerialize() throws {
        let swiftCode = """
        public struct S {
            public let x: Int
            public let y: Int
        }
        """
        let tree = try SyntaxTree(string: swiftCode)
        
        // ESTIMATED TOKEN PATHS:
        // public (1) struct (2) S (3) { (4)
        // public (5) let (6) x (7) : (8) Int (9)
        // public (10) let (11) y (12) : (13) Int (14)
        // } (15)
        let xIdentifierTokenPath = "7" // Target the 'x' identifier token

        let (deletedText, newTree) = try tree.deleteNode(atPath: xIdentifierTokenPath)
        #expect(deletedText == "x") // We deleted the 'x' token
        
        let newSource = newTree.serializeToCode()
        // Expect the line for 'x' to be mangled (e.g., "public let : Int")
        // Expect 'y' to remain largely intact.
        #expect(!newSource.contains("public let x: Int"))
        #expect(newSource.contains("public let : Int")) // After 'x' is deleted (replaced by empty token)
        #expect(newSource.contains("public let y: Int"))
    }

    @Test func testReplaceEntireStructWithAnother() throws {
        let swiftCode = "public struct S { public let x: Int }"
        let tree = try SyntaxTree(string: swiftCode)
        // Path "1" will point to the "public" token in the token-centric rewriter.
        let structPath = "1" 

        let newStructCode = "public struct T { public let y: Int }"
        let newStructTree = try SyntaxTree(string: newStructCode)
        // This is a CodeBlockItemSyntax or similar, not a TokenSyntax.
        let newStructNode = Syntax(fromProtocol: newStructTree.sourceFile.statements.first!.item)

        do {
            _ = try tree.replaceNode(atPath: structPath, withNewNode: newStructNode)
            Issue.record("Expected invalidReplacementContext error when replacing a token with a non-token structure.")
        } catch NodeOperationError.invalidReplacementContext(let reason) {
            #expect(reason.contains("replacement node is not a Token"))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func testLineNumberBasedNodeSelectionAndModification() throws {
        let swiftCode = """
        public struct MyStruct {
            /// Old doc
            public func foo() {}
            public func bar() {}
        }
        """
        let tree = try SyntaxTree(string: swiftCode)

        // Test finding nodes at different lines
        let line1Info = tree.findNodesAtLine(1) // "public struct MyStruct {"
        #expect(!line1Info.nodes.isEmpty, "Should find nodes on line 1")
        #expect(line1Info.selectedNode != nil, "Should select a node on line 1")

        let line3Info = tree.findNodesAtLine(3) // "public func foo() {}"
        #expect(!line3Info.nodes.isEmpty, "Should find nodes on line 3")
        #expect(line3Info.selectedNode != nil, "Should select a node on line 3")

        // Test modifying trivia by line number
        let modifiedTree = try tree.modifyLeadingTrivia(atLine: 3, newLeadingTriviaText: "/// New function doc")
        let newSource = modifiedTree.serializeToCode()
        #expect(newSource.contains("/// New function doc"), "Should contain new documentation")
    }

    @Test func testLineNumberSelectionStrategies() throws {
        let swiftCode = """
        let x = 1; let y = 2; let z = 3
        """
        let tree = try SyntaxTree(string: swiftCode)

        // Test different selection strategies on a line with multiple nodes
        let firstNodeInfo = tree.findNodesAtLine(1, selection: .first)
        let lastNodeInfo = tree.findNodesAtLine(1, selection: .last)
        let largestNodeInfo = tree.findNodesAtLine(1, selection: .largest)
        let smallestNodeInfo = tree.findNodesAtLine(1, selection: .smallest)
        let columnNodeInfo = tree.findNodesAtLine(1, selection: .atColumn(15))

        #expect(firstNodeInfo.selectedNode != nil, "Should select first node")
        #expect(lastNodeInfo.selectedNode != nil, "Should select last node")
        #expect(largestNodeInfo.selectedNode != nil, "Should select largest node")
        #expect(smallestNodeInfo.selectedNode != nil, "Should select smallest node")
        #expect(columnNodeInfo.selectedNode != nil, "Should select node near column 15")

        // The first and last selected nodes should be different (unless there's only one node)
        if firstNodeInfo.nodes.count > 1 {
            #expect(firstNodeInfo.selectedNode?.column != lastNodeInfo.selectedNode?.column,
                   "First and last selections should be different when multiple nodes exist")
        }
    }

    @Test func testLineNumberBasedReplacement() throws {
        let swiftCode = """
        public struct MyStruct {
            public func oldName() {}
        }
        """
        let tree = try SyntaxTree(string: swiftCode)

        // Find a token on line 2 to replace
        let line2Info = tree.findNodesAtLine(2)
        #expect(line2Info.selectedNode != nil, "Should find node on line 2")

        // Try to replace a token (this will work with token-level replacement)
        // Note: We're testing the API, actual replacement depends on token selection
        do {
            let newToken = TokenSyntax.identifier("newName")
            let modifiedTree = try tree.replaceNode(atLine: 2, withNewNode: Syntax(newToken))
            let newSource = modifiedTree.serializeToCode()
            
            #expect(!newSource.isEmpty, "Modified source should not be empty")
        } catch NodeOperationError.invalidReplacementContext {
            // This is expected if we try to replace a non-token node with a token
            print("Line-based replacement correctly rejected invalid replacement context")
        }
    }

    @Test func testLineNumberBasedDeletion() throws {
        let swiftCode = """
        public struct MyStruct {
            public let x: Int
            public let y: Int
        }
        """
        let tree = try SyntaxTree(string: swiftCode)

        // Delete a node on line 2
        let (deletedText, modifiedTree) = try tree.deleteNode(atLine: 2)
        let newSource = modifiedTree.serializeToCode()

        #expect(deletedText != nil, "Should return deleted text")
        #expect(!newSource.isEmpty, "Modified source should not be empty")
    }

    @Test func testLineNumberBasedErrorCases() throws {
        let swiftCode = """
        public struct MyStruct {
            public func foo() {}
        }
        """
        let tree = try SyntaxTree(string: swiftCode)

        // Test with non-existent line numbers
        let emptyLineInfo = tree.findNodesAtLine(10) // Line doesn't exist
        #expect(emptyLineInfo.nodes.isEmpty, "Should find no nodes on non-existent line")
        #expect(emptyLineInfo.selectedNode == nil, "Should not select any node on non-existent line")

        // Test modification on non-existent line
        #expect(throws: NodeOperationError.self) {
            _ = try tree.modifyLeadingTrivia(atLine: 10, newLeadingTriviaText: "/// Doc")
        }

        // Test with line 0 (invalid)
        let invalidLineInfo = tree.findNodesAtLine(0)
        #expect(invalidLineInfo.nodes.isEmpty, "Should find no nodes on line 0")
    }

    @Test func testLineNumberBasedMultipleNodesPerLine() throws {
        let swiftCode = """
        import Foundation; import SwiftSyntax
        let a = 1, b = 2, c = 3
        func foo() { print("hello"); return }
        """
        let tree = try SyntaxTree(string: swiftCode)

        // Test lines with multiple significant nodes
        for lineNumber in 1...3 {
            let lineInfo = tree.findNodesAtLine(lineNumber)
            
            #expect(!lineInfo.nodes.isEmpty, "Should find nodes on line \(lineNumber)")
        }
    }
	
	
	@Test func testNonDocCommentsNotIncludedInDocumentation() throws {
		let swiftCode = """
		// This is a file-level comment
		// It should not be considered documentation for the struct
		
		public struct MyStruct {
			// This is an implementation comment
			/// This is a doc comment for foo
			public func foo() {}
			// Another implementation comment
			public func bar() {}
		}
		
		// This is a trailing comment after the struct
		"""
		let overview = try generateOverview(string: swiftCode, format: .json)
		
		// The file-level comments should NOT appear as documentation for MyStruct
		#expect(!overview.contains("file-level comment"), "File-level comments should not be extracted as documentation")
		#expect(!overview.contains("It should not be considered documentation"), "Non-doc comments should not be extracted as documentation")
		
		// The implementation comment should NOT be included as documentation for foo
		#expect(!overview.contains("implementation comment"), "Implementation comments should not be extracted as documentation")
		
		// The doc comment should be included for foo
		#expect(overview.contains("This is a doc comment for foo"), "Doc comment should be extracted as documentation")
		
		// The trailing comment after the struct should NOT be included as documentation
		#expect(!overview.contains("trailing comment"), "Trailing comments should not be extracted as documentation")
	}
	
	@Test func testLeadingTriviaInsertionWithNonDocComments() throws {
		let swiftCode = """
		// File-level comment
		// Not documentation
		
		public struct MyStruct {
			// Implementation comment
			public func foo() {}
		}
		"""
		let tree = try SyntaxTree(string: swiftCode)

		// Find the line for 'public func foo()' (should be line 6)
		let lineInfo = tree.findNodesAtLine(6)
		#expect(!lineInfo.nodes.isEmpty, "Should find nodes on line 6")
		let selected = lineInfo.selectedNode
		#expect(selected != nil, "Should select a node on line 6")

		// Insert a doc comment as leading trivia for the selected node
		let modifiedTree = try tree.modifyLeadingTrivia(atLine: 6, newLeadingTriviaText: "/// Inserted doc comment")
		let newSource = modifiedTree.serializeToCode()
		
		// The inserted doc comment should appear immediately before 'public func foo()'
		#expect(newSource.range(of: #"/// Inserted doc comment[\s\S]*?public func foo\(\)"#, options: .regularExpression) != nil, "Inserted doc comment should appear before the function")

		// The file-level and implementation comments should remain unchanged
		#expect(newSource.contains("// File-level comment"), "File-level comment should remain")
		#expect(newSource.contains("// Implementation comment"), "Implementation comment should remain")
	}

    @Test func testAddMultiLineDocCommentsPathBased() throws {
        let swiftCode = """
        public struct MyStruct {
            public func simpleFunction() {}
            public func anotherFunction() {}
        }
        """
        let tree = try SyntaxTree(string: swiftCode)

        // TOKEN PATHS (estimated):
        // public(1) struct(2) MyStruct(3) {(4)
        // public(5) func(6) simpleFunction(7) ((8) )(9) {(10) }(11)
        // public(12) func(13) anotherFunction(14) ((15) )(16) {(17) }(18)
        // }(19)

        let firstFunctionPublicPath = "5"  // Target 'public' of first function
        let secondFunctionPublicPath = "12" // Target 'public' of second function

        // Add multi-line doc comment to first function
        let multiLineDoc1 = """
        /// Performs a simple operation.
        /// 
        /// This function does something important and useful.
        /// It demonstrates multi-line documentation.
        /// 
        /// - Returns: Nothing, but does important work
        """
        
        let modifiedTree1 = try tree.modifyLeadingTrivia(forNodeAtPath: firstFunctionPublicPath, newLeadingTriviaText: multiLineDoc1)
        let source1 = modifiedTree1.serializeToCode()
        
        #expect(source1.contains("/// Performs a simple operation."), "Should contain first line of doc comment")
        #expect(source1.contains("/// This function does something important"), "Should contain description line")
        #expect(source1.contains("/// - Returns: Nothing"), "Should contain returns documentation")
        #expect(source1.contains("public func simpleFunction()"), "Should preserve function declaration")
        
        // Add different multi-line doc comment to second function
        let multiLineDoc2 = """
        /// Another important function.
        /// 
        /// - Parameter input: The input value
        /// - Parameter options: Configuration options
        /// - Returns: The processed result
        /// - Throws: `Error` if processing fails
        """
        
        let modifiedTree2 = try modifiedTree1.modifyLeadingTrivia(forNodeAtPath: secondFunctionPublicPath, newLeadingTriviaText: multiLineDoc2)
        let source2 = modifiedTree2.serializeToCode()
        
        #expect(source2.contains("/// Performs a simple operation."), "Should still contain first function's doc")
        #expect(source2.contains("/// Another important function."), "Should contain second function's doc")
        #expect(source2.contains("/// - Parameter input:"), "Should contain parameter documentation")
        #expect(source2.contains("/// - Throws:"), "Should contain throws documentation")
    }
    
    @Test func testModifyExistingMultiLineDocCommentsPathBased() throws {
        let swiftCode = """
        public struct MyStruct {
            /// Old simple comment
            public func functionWithDocs() {}
            
            /// Very brief
            /// Old multi-line
            public func anotherWithDocs() {}
        }
        """
        let tree = try SyntaxTree(string: swiftCode)

        // The debug shows:
        // Line 1: tokens 1,2,3,4 are `public struct MyStruct {`
        // Line 3: tokens 5,6,7,8,9,10,11 are `public func functionWithDocs() {}`  
        // Line 7: tokens 12,13,14,15,16,17,18 are `public func anotherWithDocs() {}`
        
        let firstFunctionPublicPath = "5"  // Target 'public' of first function (Line 3, column 5)
        let secondFunctionPublicPath = "12" // Target 'public' of second function (Line 7, column 5)

        // Replace first function's simple comment with comprehensive multi-line doc
        let newDoc1 = """
        /// Performs advanced processing with detailed documentation.
        /// 
        /// This function has been enhanced with comprehensive documentation
        /// that explains its purpose, parameters, and behavior in detail.
        /// 
        /// ## Usage Example
        /// ```swift
        /// let result = functionWithDocs()
        /// ```
        /// 
        /// - Important: This function requires proper initialization
        /// - Returns: A processed result value
        """
        
        let modifiedTree1 = try tree.modifyLeadingTrivia(forNodeAtPath: firstFunctionPublicPath, newLeadingTriviaText: newDoc1)
        let source1 = modifiedTree1.serializeToCode()
        
        #expect(source1.contains("/// Performs advanced processing"), "Should contain new comprehensive doc")
        #expect(source1.contains("## Usage Example"), "Should contain usage example section")
        #expect(source1.contains("- Important:"), "Should contain important note")

        // Replace second function's multi-line comment with different multi-line doc
        let newDoc2 = """
        /// Handles complex operations with multiple parameters.
        /// 
        /// This function processes various inputs and provides detailed
        /// error handling and validation capabilities.
        /// 
        /// - Parameters:
        ///   - data: The input data to process
        ///   - options: Processing configuration options
        ///   - callback: Completion handler for async operations
        /// - Returns: Processing result or nil if failed
        /// - Throws: 
        ///   - `ValidationError` if input data is invalid
        ///   - `ProcessingError` if operation fails
        """
        
        let modifiedTree2 = try modifiedTree1.modifyLeadingTrivia(forNodeAtPath: secondFunctionPublicPath, newLeadingTriviaText: newDoc2)
        let source2 = modifiedTree2.serializeToCode()
        
        #expect(source2.contains("/// Handles complex operations"), "Should contain second function's new doc")
        #expect(source2.contains("- Parameters:"), "Should contain parameters section")
        #expect(source2.contains("ValidationError"), "Should contain specific error types")
        #expect(source2.contains("/// Performs advanced processing"), "Should still contain first function's new doc")
    }
    
    @Test func testBlockStyleMultiLineDocCommentsPathBased() throws {
        let swiftCode = """
        public class MyClass {
            public func methodOne() {}
            public func methodTwo() {}
        }
        """
        let tree = try SyntaxTree(string: swiftCode)

        // TOKEN PATHS (estimated):
        // public(1) class(2) MyClass(3) {(4)
        // public(5) func(6) methodOne(7) ((8) )(9) {(10) }(11)
        // public(12) func(13) methodTwo(14) ((15) )(16) {(17) }(18)
        // }(19)

        let firstMethodPublicPath = "5"  // Target 'public' of first method
        let secondMethodPublicPath = "12" // Target 'public' of second method

        // Note: For block-style comments, we'll simulate by using triple-slash format
        // since the trivia system expects individual lines
        let blockStyleDoc1 = """
        /// **Summary:** Primary processing method
        /// 
        /// **Description:**
        /// This method handles the primary processing workflow
        /// with comprehensive error handling and validation.
        /// 
        /// **Parameters:**
        /// - input: The data to be processed
        /// - config: Configuration settings
        /// 
        /// **Returns:** Processed data result
        /// 
        /// **Throws:** ProcessingError on failure
        """
        
        let modifiedTree1 = try tree.modifyLeadingTrivia(forNodeAtPath: firstMethodPublicPath, newLeadingTriviaText: blockStyleDoc1)
        let source1 = modifiedTree1.serializeToCode()
        
        #expect(source1.contains("/// **Summary:**"), "Should contain summary section")
        #expect(source1.contains("/// **Description:**"), "Should contain description section")
        #expect(source1.contains("/// **Parameters:**"), "Should contain parameters section")
        #expect(source1.contains("/// **Returns:**"), "Should contain returns section")
        #expect(source1.contains("/// **Throws:**"), "Should contain throws section")
        
        // Add documentation with code examples
        let codeExampleDoc = """
        /// Secondary processing method with examples.
        /// 
        /// This method demonstrates how to include code examples
        /// in documentation comments.
        /// 
        /// ## Example Usage:
        /// ```swift
        /// let processor = MyClass()
        /// let result = try processor.methodTwo()
        /// print("Result: \\(result)")
        /// ```
        /// 
        /// ## Alternative Usage:
        /// ```swift
        /// MyClass().methodTwo()
        /// ```
        /// 
        /// - Note: Ensure proper error handling in production code
        /// - SeeAlso: `methodOne()` for primary processing
        """
        
        let modifiedTree2 = try modifiedTree1.modifyLeadingTrivia(forNodeAtPath: secondMethodPublicPath, newLeadingTriviaText: codeExampleDoc)
        let source2 = modifiedTree2.serializeToCode()
        
        #expect(source2.contains("## Example Usage:"), "Should contain example usage section")
        #expect(source2.contains("```swift"), "Should contain code block markers")
        #expect(source2.contains("let processor = MyClass()"), "Should contain example code")
        #expect(source2.contains("- Note:"), "Should contain note section")
        #expect(source2.contains("- SeeAlso:"), "Should contain see also section")
    }
    
    @Test func testMultiLineDocCommentsPathBasedErrorCases() throws {
        let swiftCode = """
        public struct TestStruct {
            public func validFunction() {}
        }
        """
        let tree = try SyntaxTree(string: swiftCode)

        // Test with invalid path
        #expect(throws: NodeOperationError.nodeNotFound(path: "999")) {
            _ = try tree.modifyLeadingTrivia(forNodeAtPath: "999", newLeadingTriviaText: "/// Should fail")
        }
        
        // Test with empty doc comment
        let validPath = "5" // Should be 'public' token of the function
        let modifiedTree = try tree.modifyLeadingTrivia(forNodeAtPath: validPath, newLeadingTriviaText: "")
        let source = modifiedTree.serializeToCode()
        
        #expect(source.contains("public func validFunction()"), "Should preserve function after empty doc comment")
        
        // Test with very long multi-line doc comment
        let longDoc = (1...50).map { i in "/// Line \(i) of a very long documentation comment." }.joined(separator: "\n")
        let longDocTree = try tree.modifyLeadingTrivia(forNodeAtPath: validPath, newLeadingTriviaText: longDoc)
        let longDocSource = longDocTree.serializeToCode()
        
        #expect(longDocSource.contains("/// Line 1 of a very long"), "Should contain first line of long doc")
        #expect(longDocSource.contains("/// Line 50 of a very long"), "Should contain last line of long doc")
    }
}
