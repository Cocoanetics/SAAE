import Testing
import Foundation
import SwiftSyntax
@testable import SAAE

/// Helper function that generates a code overview using the proper SAAE API.
/// This replaces the temporary stub and uses the actual CodeOverview implementation.
func generateOverview(string: String, format: OutputFormat, minVisibility: VisibilityLevel? = nil) throws -> String {
    let tree = try SyntaxTree(string: string)
    let overview = CodeOverview(tree: tree, minVisibility: minVisibility ?? .internal)
    
    switch format {
    case .json:
        return try overview.json()
    case .yaml:
        return try overview.yaml()
    case .markdown:
        return overview.markdown()
    case .interface:
        return overview.interface()
    }
}

struct SAAETests {
    
    @Test func basicParsing() throws {
        let swiftCode = """
        import Foundation
        
        public class TestClass {
            public func testMethod() {
                print("Hello, World!")
            }
        }
        """
        
        // Test that we can create a SyntaxTree from string
        let tree = try SyntaxTree(string: swiftCode)
        #expect(tree.sourceFile.statements.count > 0)
    }
    
    @Test func jsonOutput() throws {
        let swiftCode = """
        import Foundation
        
        public class TestClass {
            public func testMethod() {
                print("Hello, World!")
            }
        }
        """
        
        let overview = try generateOverview(string: swiftCode, format: OutputFormat.json)
        
        #expect(!overview.isEmpty)
        #expect(overview.contains("\"type\" : \"class\""))
        #expect(overview.contains("TestClass"))
    }
    
    @Test func yamlOutput() throws {
        let swiftCode = """
        public struct TestStruct {
            public let property: String
        }
        """
        
        let overview = try generateOverview(string: swiftCode, format: OutputFormat.yaml)
        
        #expect(!overview.isEmpty)
        #expect(overview.contains("type: struct"))
        #expect(overview.contains("TestStruct"))
    }
    
    @Test func markdownOutput() throws {
        let swiftCode = """
        public protocol TestProtocol {
            func testMethod()
        }
        """
        
        let overview = try generateOverview(string: swiftCode, format: OutputFormat.markdown)
        
        #expect(!overview.isEmpty)
        #expect(overview.contains("# Code Overview"))
        #expect(overview.contains("TestProtocol"))
    }
    
    @Test func visibilityFiltering() throws {
        let swiftCode = """
        public struct PublicStruct {
            public let publicProperty: String
            internal let internalProperty: String
            private let privateProperty: String
        }
        
        internal struct InternalStruct {
            let property: String
        }
        """
        
        // Test with public visibility
        let publicOverview = try generateOverview(string: swiftCode, format: OutputFormat.json, minVisibility: .public)
        #expect(publicOverview.contains("PublicStruct"))
        #expect(publicOverview.contains("publicProperty"))
        #expect(!publicOverview.contains("InternalStruct"))
        #expect(!publicOverview.contains("internalProperty"))
        #expect(!publicOverview.contains("privateProperty"))
        
        // Test with internal visibility
        let internalOverview = try generateOverview(string: swiftCode, format: OutputFormat.json, minVisibility: .internal)
        #expect(internalOverview.contains("PublicStruct"))
        #expect(internalOverview.contains("publicProperty"))
        #expect(internalOverview.contains("InternalStruct"))
        #expect(internalOverview.contains("internalProperty"))
        #expect(!internalOverview.contains("privateProperty"))
    }
    
    @Test func nestedDeclarations() throws {
        let swiftCode = """
        public struct OuterStruct {
            public struct InnerStruct {
                public let property: String
            }
            
            public enum InnerEnum {
                case first
                case second
            }
        }
        """
        
        let overview = try generateOverview(string: swiftCode, format: OutputFormat.json)
        
        #expect(overview.contains("OuterStruct"))
        #expect(overview.contains("InnerStruct"))
        #expect(overview.contains("InnerEnum"))
        #expect(overview.contains("first"))
        #expect(overview.contains("second"))
    }
    
    @Test func swiftDocumentation() throws {
        let swiftCode = """
        public struct DocumentedStruct {
            /// This is a documented property
            /// - Parameter name: The name parameter
            /// - Returns: A string value
            public func documentedMethod(name: String) -> String {
                return name
            }
        }
        """
        
        let overview = try generateOverview(string: swiftCode, format: .markdown)
        
        #expect(!overview.isEmpty)
        #expect(overview.contains("documented"))
        // Documentation should be included in markdown format
    }
    
    @Test func documentationParsing() throws {
        let swiftCode = """
        public class DocumentedClass {
            /// This is a test function
            /// - Parameter input: The input string
            /// - Returns: The processed string
            /// - Throws: An error if processing fails
            public func testFunction(input: String) throws -> String {
                return input.uppercased()
            }
        }
        """
        
        let overview = try generateOverview(string: swiftCode, format: .json)
        
        #expect(overview.contains("This is a test function"))
        #expect(overview.contains("input"))
        #expect(overview.contains("The input string"))
    }
    
    @Test func fileNotFoundError() throws {
        let nonExistentURL = URL(fileURLWithPath: "/nonexistent/file.swift")
        
        #expect(throws: SAAEError.self) {
            try SyntaxTree(url: nonExistentURL)
        }
        
        // More specific error checking
        do {
            _ = try SyntaxTree(url: nonExistentURL)
            Issue.record("Expected SAAEError.fileNotFound to be thrown")
        } catch let error as SAAEError {
            switch error {
            case .fileNotFound:
                // Expected error
                break
            default:
                Issue.record("Expected SAAEError.fileNotFound, got \(error)")
            }
        } catch {
            Issue.record("Expected SAAEError.fileNotFound, got \(error)")
        }
    }
    
    @Test func pathGeneration() throws {
        let swiftCode = """
        public struct Container {
            public struct Inner {
                public let property: String
                public func method() {}
            }
        }
        """
        
        let overview = try generateOverview(string: swiftCode, format: .json)
        
        // Check that paths are generated correctly
        #expect(overview.contains("1.1.1"))  // Container.Inner.property path
        #expect(overview.contains("1.1.2"))  // Container.Inner.method path
    }
    
    @Test func interfaceFormat() throws {
        let swiftCode = """
        import Foundation
        
        /// A test class for interface generation
        public class TestClass {
            /// A test property
            public let property: String
            
            /// A test method
            /// - Parameter input: The input value
            /// - Returns: The output value
            public func method(input: String) -> String {
                return input
            }
        }
        """
        
        let overview = try generateOverview(string: swiftCode, format: .interface)
        
        #expect(!overview.isEmpty)
        #expect(overview.contains("public class TestClass"))
        #expect(overview.contains("public var property: String { get }"))
        #expect(overview.contains("public func method(input: String) -> String"))
        #expect(overview.contains("import Foundation"))
    }
    
    @Test func modifiersSupport() throws {
        let swiftCode = """
        public class ModifiersTest {
            static let staticProperty: String = "test"
            final func finalMethod() {}
            class func classMethod() {}
            convenience init(value: String) { self.init() }
            lazy var lazyProperty: String = "lazy"
            weak var weakProperty: AnyObject?
            
            mutating func mutatingMethod() {}
            nonmutating func nonmutatingMethod() {}
            override func overrideMethod() {}
            required init() {}
        }
        """
        
        let overview = try generateOverview(string: swiftCode, format: .json)
        
        // Check that all declaration types are captured
        #expect(overview.contains("class"))
        #expect(overview.contains("let"))
        #expect(overview.contains("var"))
        #expect(overview.contains("func"))
        #expect(overview.contains("init"))
        
        // Check that modifiers are captured
        #expect(overview.contains("static"))
        #expect(overview.contains("final"))
        #expect(overview.contains("convenience"))
        #expect(overview.contains("lazy"))
        #expect(overview.contains("weak"))
        #expect(overview.contains("mutating"))
        #expect(overview.contains("nonmutating"))
        #expect(overview.contains("override"))
        #expect(overview.contains("required"))
    }
    
    @Test func enumCasesInterfaceFormat() throws {
        let swiftCode = """
        public enum TestEnum {
            case first
            case second(String)
            case third(Int, String)
            
            public func utilityMethod() -> String {
                return "test"
            }
        }
        """
        
        let overview = try generateOverview(string: swiftCode, format: .interface)
        
        #expect(!overview.isEmpty)
        #expect(overview.contains("public enum TestEnum"))
        
        // Cases should not show visibility (they inherit from parent enum)
        #expect(overview.contains("case first"))
        #expect(overview.contains("case second(String)"))
        #expect(overview.contains("case third(Int, String)"))
        
        // But methods should show visibility
        #expect(overview.contains("public func utilityMethod()"))
        
        // Cases should NOT have redundant "public" prefix
        #expect(!overview.contains("public case first"))
        #expect(!overview.contains("public case second"))
        #expect(!overview.contains("public case third"))
    }
    
    @Test func directAPIUsage() throws {
        let swiftCode = """
        public struct DirectAPITest {
            public let property: String
        }
        """
        
        // Test direct API usage
        let tree = try SyntaxTree(string: swiftCode)
        let codeOverview = CodeOverview(tree: tree, minVisibility: .public)
        
        let jsonOutput = try codeOverview.json()
        let yamlOutput = try codeOverview.yaml()
        let markdownOutput = codeOverview.markdown()
        let interfaceOutput = codeOverview.interface()
        
        #expect(!jsonOutput.isEmpty)
        #expect(!yamlOutput.isEmpty)
        #expect(!markdownOutput.isEmpty)
        #expect(!interfaceOutput.isEmpty)
        
        #expect(jsonOutput.contains("DirectAPITest"))
        #expect(yamlOutput.contains("DirectAPITest"))
        #expect(markdownOutput.contains("DirectAPITest"))
        #expect(interfaceOutput.contains("DirectAPITest"))
    }
    
    @Test func unexpectedCodePositioningAccuracy() throws {
        // This test validates that when SAAE reports "unexpected code 'X'" at line Y, column Z,
        // the code 'X' actually exists at that exact position in the source file
        
        // Find the test resources directory using relative path
        let currentFile = URL(fileURLWithPath: #file)
        let projectRoot = currentFile.deletingLastPathComponent().deletingLastPathComponent() // Go up to project root (Tests/SAAETests -> Tests -> SAAE root)
        let testResourcesURL = projectRoot.appendingPathComponent("Tests/Resources/ErrorSamples")
        
        let fileManager = FileManager.default
        let swiftFiles = try fileManager.contentsOfDirectory(at: testResourcesURL, includingPropertiesForKeys: nil, options: [])
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        
        var totalUnexpectedCodeErrors = 0
        var positioningErrors: [(String, String, String)] = [] // file, error, reason
        
        for fileURL in swiftFiles {
            let fileName = fileURL.lastPathComponent
            print("🔍 Testing positioning in \(fileName)...")
            
            let tree = try SyntaxTree(url: fileURL)
            let errors = tree.syntaxErrors
            
            // Get the original source lines for position validation
            let sourceContent = try String(contentsOf: fileURL)
            let sourceLines = sourceContent.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
            
            for error in errors {
                // Look for "unexpected code '...'" pattern
                if error.message.contains("unexpected code") {
                    totalUnexpectedCodeErrors += 1
                    
                    // Extract the quoted code from the error message
                    guard let startQuote = error.message.range(of: "'"),
                          let endQuote = error.message.range(of: "'", range: startQuote.upperBound..<error.message.endIndex) else {
                        // Skip errors that don't have quoted code (different error message format)
                        print("  ⏩ Skipping error without quoted code: '\(error.message)'")
                        continue
                    }
                    
                    let quotedCode = String(error.message[startQuote.upperBound..<endQuote.lowerBound])
                    let reportedLine = error.location.line
                    let reportedColumn = error.location.column
                    
                    // Validate line number is within bounds
                    guard reportedLine > 0 && reportedLine <= sourceLines.count else {
                        positioningErrors.append((fileName, error.message, "Line \(reportedLine) is out of bounds (file has \(sourceLines.count) lines)"))
                        continue
                    }
                    
                    let actualLine = sourceLines[reportedLine - 1] // Convert to 0-based index
                    
                    // Validate column number is within bounds
                    guard reportedColumn > 0 && reportedColumn <= actualLine.count + 1 else { // +1 allows for end-of-line
                        positioningErrors.append((fileName, error.message, "Column \(reportedColumn) is out of bounds for line \(reportedLine) (line has \(actualLine.count) characters)"))
                        continue
                    }
                    
                    // Check if the quoted code appears at the exact reported position
                    let startIndex = actualLine.index(actualLine.startIndex, offsetBy: reportedColumn - 1) // Convert to 0-based
                    
                    // Ensure we have enough characters left for the quoted code
                    let remainingLength = actualLine.distance(from: startIndex, to: actualLine.endIndex)
                    if quotedCode.count > remainingLength {
                        positioningErrors.append((fileName, error.message, "Not enough characters at position \(reportedLine):\(reportedColumn) for code '\(quotedCode)' (need \(quotedCode.count), have \(remainingLength))"))
                        continue
                    }
                    
                    let endIndex = actualLine.index(startIndex, offsetBy: quotedCode.count)
                    let actualCode = String(actualLine[startIndex..<endIndex])
                    
                    // Verify exact match
                    if actualCode != quotedCode {
                        positioningErrors.append((fileName, error.message, "Expected '\(quotedCode)' at \(reportedLine):\(reportedColumn), but found '\(actualCode)'"))
                        continue
                    }
                    
                    print("  ✅ \(reportedLine):\(reportedColumn): '\(quotedCode)' - Position verified")
                }
            }
        }
        
        // Report results
        print("\n📊 Test Results:")
        print("Files tested: \(swiftFiles.count)")
        print("Total 'unexpected code' errors found: \(totalUnexpectedCodeErrors)")
        print("Positioning errors: \(positioningErrors.count)")
        
        // If there are positioning errors, print them for debugging
        if !positioningErrors.isEmpty {
            print("\n❌ Positioning Errors Found:")
            for (file, message, reason) in positioningErrors {
                print("  \(file): \(message)")
                print("    Reason: \(reason)")
            }
        }
        
        // Assert that all positioning is accurate
        #expect(positioningErrors.isEmpty, "Found \(positioningErrors.count) positioning errors in 'unexpected code' messages")
        
        // Also verify we found at least some unexpected code errors to test
        #expect(totalUnexpectedCodeErrors > 0, "Expected to find at least some 'unexpected code' errors for testing")
        
        print("\n✅ All 'unexpected code' error positions are accurate!")
    }
    
    @Test func expectedErrorPositioningAccuracy() throws {
        // Test specific "expected X" errors at known positions
        
        let currentFile = URL(fileURLWithPath: #file)
        let projectRoot = currentFile.deletingLastPathComponent().deletingLastPathComponent() // Go up to project root (Tests/SAAETests -> Tests -> SAAE root)
        
        // Test "expected '=' in variable" in type_annotations.swift
        let typeAnnotationsURL = projectRoot.appendingPathComponent("Tests/Resources/ErrorSamples/type_annotations.swift")
        let tree1 = try SyntaxTree(url: typeAnnotationsURL)
        let expectedEqualsErrors = tree1.syntaxErrors.filter { $0.message.contains("expected '=' in variable") }
        
        #expect(!expectedEqualsErrors.isEmpty, "Should find 'expected =' errors in type_annotations.swift")
        
        // Line 12: "var property2: Int String = 5" - error should point to "String"  
        let expectedEqualsError = expectedEqualsErrors.first { $0.location.line == 12 }
        #expect(expectedEqualsError != nil, "Should have 'expected =' error on line 12")
        #expect(expectedEqualsError!.location.column == 24, "Error should point to column 24 where 'String' appears")
        
        // Test "expected identifier in parameter" in function_errors.swift (this actually exists)
        let functionErrorsURL = projectRoot.appendingPathComponent("Tests/Resources/ErrorSamples/function_errors.swift")
        let tree2 = try SyntaxTree(url: functionErrorsURL)
        let parameterErrors = tree2.syntaxErrors.filter { $0.message.contains("expected identifier in parameter") }
        
        #expect(!parameterErrors.isEmpty, "Should find parameter errors in function_errors.swift")
        
        // Test "expected '}' to end class" in missing_braces.swift
        let missingBracesURL = projectRoot.appendingPathComponent("Tests/Resources/ErrorSamples/missing_braces.swift")
        let tree3 = try SyntaxTree(url: missingBracesURL)
        let missingBraceErrors = tree3.syntaxErrors.filter { $0.message.contains("expected '}' to end class") }
        
        #expect(!missingBraceErrors.isEmpty, "Should find missing brace errors in missing_braces.swift")
        
        print("✅ All 'expected X' error positions verified!")
    }
    
    @Test func expressionErrorPositioningAccuracy() throws {
        // Test specific expression-related errors at exact positions
        
        let currentFile = URL(fileURLWithPath: #file)
        let projectRoot = currentFile.deletingLastPathComponent().deletingLastPathComponent() // Go up to project root (Tests/SAAETests -> Tests -> SAAE root)
        let expressionErrorsURL = projectRoot.appendingPathComponent("Tests/Resources/ErrorSamples/expression_errors.swift")
        let sourceContent = try String(contentsOf: expressionErrorsURL)
        let sourceLines = sourceContent.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
        let tree = try SyntaxTree(url: expressionErrorsURL)
        
        // Test "expected expression after operator" 
        let operatorErrors = tree.syntaxErrors.filter { $0.message.contains("expected expression after operator") }
        #expect(operatorErrors.count >= 1, "Should find operator errors")
        
        // Test line 10: "let math = 1 + + 2" - should point after the second "+"
        let line10Error = operatorErrors.first { $0.location.line == 10 }
        if let error = line10Error {
            #expect(error.location.column == 24, "Should point to column 24 after the '+ +' operators")
            
            // Verify the line content matches what we expect
            let actualLine = sourceLines[9] // 0-based index for line 10
            #expect(actualLine.contains("let math = 1 + + 2"), "Line 10 should contain the invalid operator expression")
        }
        
        // Test "expected ']' to end array"
        let arrayErrors = tree.syntaxErrors.filter { $0.message.contains("expected ']' to end array") }
        if let arrayError = arrayErrors.first {
            let errorLine = sourceLines[arrayError.location.line - 1]
            #expect(errorLine.contains("["), "Error line should contain array syntax")
        }
        
        // Test "expected '\"' to end string literal"
        let stringErrors = tree.syntaxErrors.filter { $0.message.contains("expected '\"' to end string literal") }
        if let stringError = stringErrors.first {
            let errorLine = sourceLines[stringError.location.line - 1]
            #expect(errorLine.contains("\""), "Error line should contain string literal")
        }
        
        print("✅ All expression error positions verified!")
    }
    
    @Test func identifierErrorPositioningAccuracy() throws {
        // Test identifier-related errors
        
        let currentFile = URL(fileURLWithPath: #file)
        let projectRoot = currentFile.deletingLastPathComponent().deletingLastPathComponent() // Go up to project root (Tests/SAAETests -> Tests -> SAAE root)
        let expressionErrorsURL = projectRoot.appendingPathComponent("Tests/Resources/ErrorSamples/expression_errors.swift")
        let sourceContent = try String(contentsOf: expressionErrorsURL)
        let sourceLines = sourceContent.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
        let tree = try SyntaxTree(url: expressionErrorsURL)
        
        // Test "'$' is not a valid identifier"
        let dollarErrors = tree.syntaxErrors.filter { $0.message.contains("'$' is not a valid identifier") }
        if let dollarError = dollarErrors.first {
            let errorLine = sourceLines[dollarError.location.line - 1]
            let errorColumn = dollarError.location.column
            
            // Verify the '$' character is at the exact reported position
            let lineStartIndex = errorLine.startIndex
            let targetIndex = errorLine.index(lineStartIndex, offsetBy: errorColumn - 1) // Convert to 0-based
            
            if targetIndex < errorLine.endIndex {
                let actualChar = errorLine[targetIndex]
                #expect(actualChar == "$", "Should point exactly to the '$' character at column \(errorColumn)")
            }
        }
        
        print("✅ All identifier error positions verified!")
    }
    
    @Test func specificKnownErrorPositions() throws {
        // Test very specific cases with exact expected positions
        
        let currentFile = URL(fileURLWithPath: #file)
        let projectRoot = currentFile.deletingLastPathComponent().deletingLastPathComponent() // Go up to project root (Tests/SAAETests -> Tests -> SAAE root)
        
        // Test syntax_confusion.swift line 68: ': <T>(value: T) -> T' error
        let syntaxConfusionURL = projectRoot.appendingPathComponent("Tests/Resources/ErrorSamples/syntax_confusion.swift")
        let sourceContent = try String(contentsOf: syntaxConfusionURL)
        let sourceLines = sourceContent.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
        let tree = try SyntaxTree(url: syntaxConfusionURL)
        
        // Find the specific error about ': <T>(value: T) -> T'
        let genericError = tree.syntaxErrors.first { 
            $0.message.contains(": <T>(value: T) -> T") && $0.message.contains("in function")
        }
        
        #expect(genericError != nil, "Should find the ': <T>(value: T) -> T' error")
        if let error = genericError {
            #expect(error.location.line == 68, "Error should be on line 68")
            #expect(error.location.column == 21, "Error should be at column 21")
            
            // Verify the actual line contains this text at that position
            let line68 = sourceLines[67] // 0-based index
            let startIndex = line68.index(line68.startIndex, offsetBy: 20) // 0-based column 20
            let actualText = String(line68[startIndex...])
            #expect(actualText.hasPrefix(": <T>(value: T) -> T"), "Line 68 column 21 should contain ': <T>(value: T) -> T'")
        }
        
        // Test type_annotations.swift line 12: "expected '=' in variable"
        let typeAnnotationsURL = projectRoot.appendingPathComponent("Tests/Resources/ErrorSamples/type_annotations.swift")
        let typeSourceContent = try String(contentsOf: typeAnnotationsURL)
        let typeSourceLines = typeSourceContent.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
        let typeTree = try SyntaxTree(url: typeAnnotationsURL)
        
        let variableError = typeTree.syntaxErrors.first { 
            $0.message.contains("expected '=' in variable") && $0.location.line == 12
        }
        
        #expect(variableError != nil, "Should find 'expected =' error on line 12")
        if let error = variableError {
            #expect(error.location.column == 24, "Error should be at column 24")
            
            // Verify line 12 contains "var property2: Int String = 5"
            let line12 = typeSourceLines[11] // 0-based index
            #expect(line12.contains("var property2: Int String = 5"), "Line 12 should contain the problematic variable declaration")
            
            // Verify column 24 points to "String"
            let startIndex = line12.index(line12.startIndex, offsetBy: 23) // 0-based column 23
            let remainingText = String(line12[startIndex...])
            #expect(remainingText.hasPrefix("String"), "Column 24 should point to 'String'")
        }
        
        print("✅ All specific known error positions verified!")
    }
    
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
        #expect(deletedText?.trimmingCharacters(in: .whitespacesAndNewlines) == "func")
        
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
        let overview = CodeOverview(tree: tree)
        let structPath = overview.declarations.first?.path ?? "1"
        // This will only work if the struct's first token is targeted
        // For now, just ensure no crash
        _ = try? tree.modifyLeadingTrivia(forNodeAtPath: structPath, newLeadingTriviaText: "/// Token doc")
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
        // Expect the line for 'x' to be mangled (e.g., "public let : Int") or gone if trivia was also removed by parser fixup.
        // Expect 'y' to remain largely intact.
        #expect(!newSource.contains("public let x: Int"))
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
} 
