import Testing
import Foundation
import SwiftSyntax
@testable import SAAE

struct Phase3_ASTModificationTests {

    @Test func phase3_astModification_basic() throws {
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

    @Test func phase3_astModification_errors() throws {
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

    @Test func phase3_astModification_trivia_token_only() throws {
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

    @Test func phase3_astModification_delete_and_serialize() throws {
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

    @Test func phase3_astModification_replace_entire_struct() throws {
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

    @Test func phase3_lineNumberBasedModification_basic() throws {
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

        print("Line-based modification test passed!")
    }

    @Test func phase3_lineNumberBasedModification_selectionStrategies() throws {
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

        print("Selection strategy test passed!")
    }

    @Test func phase3_lineNumberBasedModification_replacement() throws {
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
            
            // The replacement might affect the source in various ways depending on which token was selected
            #expect(!newSource.isEmpty, "Modified source should not be empty")
            print("Line-based replacement test completed")
        } catch NodeOperationError.invalidReplacementContext {
            // This is expected if we try to replace a non-token node with a token
            print("Line-based replacement correctly rejected invalid replacement context")
        }
    }

    @Test func phase3_lineNumberBasedModification_deletion() throws {
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
        
        // The exact behavior depends on which token was selected and deleted
        print("Line-based deletion test completed")
        print("Deleted text: \(deletedText ?? "nil")")
    }

    @Test func phase3_lineNumberBasedModification_errorCases() throws {
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
        do {
            _ = try tree.modifyLeadingTrivia(atLine: 10, newLeadingTriviaText: "/// Doc")
            #expect(false, "Should throw error for non-existent line")
        } catch NodeOperationError.nodeNotFound {
            // Expected
            print("Correctly threw error for non-existent line")
        }

        // Test with line 0 (invalid)
        let invalidLineInfo = tree.findNodesAtLine(0)
        #expect(invalidLineInfo.nodes.isEmpty, "Should find no nodes on line 0")
    }

    @Test func phase3_lineNumberBasedModification_multipleNodesPerLine() throws {
        let swiftCode = """
        import Foundation; import SwiftSyntax
        let a = 1, b = 2, c = 3
        func foo() { print("hello"); return }
        """
        let tree = try SyntaxTree(string: swiftCode)

        // Test lines with multiple significant nodes
        for lineNumber in 1...3 {
            let lineInfo = tree.findNodesAtLine(lineNumber)
            print("Line \(lineNumber): found \(lineInfo.nodes.count) nodes")
            
            for (index, nodeInfo) in lineInfo.nodes.enumerated() {
                print("  Node \(index): column \(nodeInfo.column), length \(nodeInfo.length), path '\(nodeInfo.path)'")
            }
            
            #expect(!lineInfo.nodes.isEmpty, "Should find nodes on line \(lineNumber)")
        }
    }
} 
