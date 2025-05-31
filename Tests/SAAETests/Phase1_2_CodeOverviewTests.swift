import Testing
import Foundation
import SwiftSyntax
@testable import SAAE

/// Test-specific errors
enum TestError: Error {
    case resourcesNotFound(String)
}

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

struct Phase1_2_CodeOverviewTests {
    
    /// Helper function to get resource URLs from the test bundle
    func getResourceURL(for name: String, withExtension ext: String) -> URL? {
        return Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources/ErrorSamples")
    }
    
    /// Helper function to get all Swift files from ErrorSamples directory
    func getAllErrorSampleFiles() throws -> [URL] {
        guard let resourcesURL = Bundle.module.url(forResource: "ErrorSamples", withExtension: "", subdirectory: "Resources") else {
            throw TestError.resourcesNotFound("ErrorSamples directory not found in bundle")
        }
        
        let fileManager = FileManager.default
        let files = try fileManager.contentsOfDirectory(at: resourcesURL, includingPropertiesForKeys: nil, options: [])
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        
        return files
    }
    
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
        
        let swiftFiles = try getAllErrorSampleFiles()
        
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
        
        // Test "expected '=' in variable" in type_annotations.swift
        guard let typeAnnotationsURL = getResourceURL(for: "type_annotations", withExtension: "swift") else {
            throw TestError.resourcesNotFound("type_annotations.swift not found in bundle")
        }
        let tree1 = try SyntaxTree(url: typeAnnotationsURL)
        let expectedEqualsErrors = tree1.syntaxErrors.filter { $0.message.contains("expected '=' in variable") }
        
        #expect(!expectedEqualsErrors.isEmpty, "Should find 'expected =' errors in type_annotations.swift")
        
        // Line 12: "var property2: Int String = 5" - error should point to "String"  
        let expectedEqualsError = expectedEqualsErrors.first { $0.location.line == 12 }
        #expect(expectedEqualsError != nil, "Should have 'expected =' error on line 12")
        #expect(expectedEqualsError!.location.column == 24, "Error should point to column 24 where 'String' appears")
        
        // Test "expected identifier in parameter" in function_errors.swift (this actually exists)
        guard let functionErrorsURL = getResourceURL(for: "function_errors", withExtension: "swift") else {
            throw TestError.resourcesNotFound("function_errors.swift not found in bundle")
        }
        let tree2 = try SyntaxTree(url: functionErrorsURL)
        let parameterErrors = tree2.syntaxErrors.filter { $0.message.contains("expected identifier in parameter") }
        
        #expect(!parameterErrors.isEmpty, "Should find parameter errors in function_errors.swift")
        
        // Test "expected '}' to end class" in missing_braces.swift
        guard let missingBracesURL = getResourceURL(for: "missing_braces", withExtension: "swift") else {
            throw TestError.resourcesNotFound("missing_braces.swift not found in bundle")
        }
        let tree3 = try SyntaxTree(url: missingBracesURL)
        let missingBraceErrors = tree3.syntaxErrors.filter { $0.message.contains("expected '}' to end class") }
        
        #expect(!missingBraceErrors.isEmpty, "Should find missing brace errors in missing_braces.swift")
        
        print("✅ All 'expected X' error positions verified!")
    }
    
    @Test func expressionErrorPositioningAccuracy() throws {
        // Test specific expression-related errors at exact positions
        
        guard let expressionErrorsURL = getResourceURL(for: "expression_errors", withExtension: "swift") else {
            throw TestError.resourcesNotFound("expression_errors.swift not found in bundle")
        }
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
        
        guard let expressionErrorsURL = getResourceURL(for: "expression_errors", withExtension: "swift") else {
            throw TestError.resourcesNotFound("expression_errors.swift not found in bundle")
        }
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
        
        // Test syntax_confusion.swift line 68: ': <T>(value: T) -> T' error
        guard let syntaxConfusionURL = getResourceURL(for: "syntax_confusion", withExtension: "swift") else {
            throw TestError.resourcesNotFound("syntax_confusion.swift not found in bundle")
        }
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
        guard let typeAnnotationsURL = getResourceURL(for: "type_annotations", withExtension: "swift") else {
            throw TestError.resourcesNotFound("type_annotations.swift not found in bundle")
        }
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
    
    @Test func leadingTrivia_nonDocComments_notIncludedInDocumentation() throws {
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
        
        print("Non-doc comments are not included in documentation extraction.")
    }
    
    @Test func leadingTrivia_insertion_with_nonDocComments() throws {
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
        #expect(newSource.contains("/// Inserted doc comment\npublic func foo()"), "Inserted doc comment should appear before the function")

        // The file-level and implementation comments should remain unchanged
        #expect(newSource.contains("// File-level comment"), "File-level comment should remain")
        #expect(newSource.contains("// Implementation comment"), "Implementation comment should remain")

        print("Leading trivia insertion with non-doc comments behaves as expected.")
    }
} 
