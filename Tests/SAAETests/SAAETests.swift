import Testing
import Foundation
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
        
        // Find the test resources directory using absolute path
        let testResourcesURL = URL(fileURLWithPath: "/Users/oliver/Developer/SAAE/Tests/Resources/ErrorSamples")
        
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
} 
