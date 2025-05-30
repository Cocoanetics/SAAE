import XCTest
@testable import SAAE

// Mock enums for test stubs
enum MockFormat {
    case json, yaml, markdown, interface
}

enum MockVisibility {
    case `public`, `internal`
}

// Extension to allow direct access to these values
extension MockFormat {
    static let json = MockFormat.json
    static let yaml = MockFormat.yaml
    static let markdown = MockFormat.markdown
    static let interface = MockFormat.interface
}

extension MockVisibility {
    static let `public` = MockVisibility.public
    static let `internal` = MockVisibility.internal
}

// Temporary stub for missing helper function
func generateOverview(string: String, format: Any, minVisibility: Any? = nil) throws -> String {
    // This is a stub for Phase 1 functionality that we're implementing in Phase 2
    let tree = try SyntaxTree(string: string)
    let overview = CodeOverview(tree: tree)
    return try overview.json() // Return basic JSON for now
}

final class SAAETests: XCTestCase {
    
    func testBasicParsing() throws {
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
        XCTAssertNotNil(tree)
    }
    
    func testJSONOutput() throws {
        let swiftCode = """
        import Foundation
        
        public class TestClass {
            public func testMethod() {
                print("Hello, World!")
            }
        }
        """
        
        let overview = try generateOverview(string: swiftCode, format: .json)
        
        XCTAssertFalse(overview.isEmpty)
        XCTAssertTrue(overview.contains("\"type\" : \"class\""))
        XCTAssertTrue(overview.contains("TestClass"))
    }
    
    func testYAMLOutput() throws {
        let swiftCode = """
        public struct TestStruct {
            public let property: String
        }
        """
        
        let overview = try generateOverview(string: swiftCode, format: .yaml)
        
        XCTAssertFalse(overview.isEmpty)
        XCTAssertTrue(overview.contains("type: struct"))
        XCTAssertTrue(overview.contains("TestStruct"))
    }
    
    func testMarkdownOutput() throws {
        let swiftCode = """
        public protocol TestProtocol {
            func testMethod()
        }
        """
        
        let overview = try generateOverview(string: swiftCode, format: .markdown)
        
        XCTAssertFalse(overview.isEmpty)
        XCTAssertTrue(overview.contains("# Code Overview"))
        XCTAssertTrue(overview.contains("TestProtocol"))
    }
    
    func testVisibilityFiltering() throws {
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
        let publicOverview = try generateOverview(string: swiftCode, format: .json, minVisibility: .public)
        XCTAssertTrue(publicOverview.contains("PublicStruct"))
        XCTAssertTrue(publicOverview.contains("publicProperty"))
        XCTAssertFalse(publicOverview.contains("InternalStruct"))
        XCTAssertFalse(publicOverview.contains("internalProperty"))
        XCTAssertFalse(publicOverview.contains("privateProperty"))
        
        // Test with internal visibility
        let internalOverview = try generateOverview(string: swiftCode, format: .json, minVisibility: .internal)
        XCTAssertTrue(internalOverview.contains("PublicStruct"))
        XCTAssertTrue(internalOverview.contains("publicProperty"))
        XCTAssertTrue(internalOverview.contains("InternalStruct"))
        XCTAssertTrue(internalOverview.contains("internalProperty"))
        XCTAssertFalse(internalOverview.contains("privateProperty"))
    }
    
    func testNestedDeclarations() throws {
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
        
        let overview = try generateOverview(string: swiftCode, format: .json)
        
        XCTAssertTrue(overview.contains("OuterStruct"))
        XCTAssertTrue(overview.contains("InnerStruct"))
        XCTAssertTrue(overview.contains("InnerEnum"))
        XCTAssertTrue(overview.contains("first"))
        XCTAssertTrue(overview.contains("second"))
    }
    
    func testSwiftDocumentation() throws {
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
        
        XCTAssertFalse(overview.isEmpty)
        XCTAssertTrue(overview.contains("documented"))
        // Documentation should be included in markdown format
    }
    
    func testDocumentationParsing() throws {
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
        
        XCTAssertTrue(overview.contains("This is a test function"))
        XCTAssertTrue(overview.contains("input"))
        XCTAssertTrue(overview.contains("The input string"))
    }
    
    func testFileNotFoundError() throws {
        let nonExistentURL = URL(fileURLWithPath: "/nonexistent/file.swift")
        
        XCTAssertThrowsError(try SyntaxTree(url: nonExistentURL)) { error in
            if let saaError = error as? SAAEError,
               case .fileNotFound = saaError {
                // Expected error
            } else {
                XCTFail("Expected SAAEError.fileNotFound, got \(error)")
            }
        }
    }
    
    func testPathGeneration() throws {
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
        XCTAssertTrue(overview.contains("1.1.1"))  // Container.Inner.property path
        XCTAssertTrue(overview.contains("1.1.2"))  // Container.Inner.method path
    }
    
    func testInterfaceFormat() throws {
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
        
        XCTAssertFalse(overview.isEmpty)
        XCTAssertTrue(overview.contains("public class TestClass"))
        XCTAssertTrue(overview.contains("public var property: String { get }"))
        XCTAssertTrue(overview.contains("public func method(input: String) -> String"))
        XCTAssertTrue(overview.contains("import Foundation"))
    }
    
    func testModifiersSupport() throws {
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
        XCTAssertTrue(overview.contains("class"))
        XCTAssertTrue(overview.contains("let"))
        XCTAssertTrue(overview.contains("var"))
        XCTAssertTrue(overview.contains("func"))
        XCTAssertTrue(overview.contains("init"))
        
        // Check that modifiers are captured
        XCTAssertTrue(overview.contains("static"))
        XCTAssertTrue(overview.contains("final"))
        XCTAssertTrue(overview.contains("convenience"))
        XCTAssertTrue(overview.contains("lazy"))
        XCTAssertTrue(overview.contains("weak"))
        XCTAssertTrue(overview.contains("mutating"))
        XCTAssertTrue(overview.contains("nonmutating"))
        XCTAssertTrue(overview.contains("override"))
        XCTAssertTrue(overview.contains("required"))
    }
    
    func testEnumCasesInterfaceFormat() throws {
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
        
        XCTAssertFalse(overview.isEmpty)
        XCTAssertTrue(overview.contains("public enum TestEnum"))
        
        // Cases should not show visibility (they inherit from parent enum)
        XCTAssertTrue(overview.contains("case first"))
        XCTAssertTrue(overview.contains("case second(String)"))
        XCTAssertTrue(overview.contains("case third(Int, String)"))
        
        // But methods should show visibility
        XCTAssertTrue(overview.contains("public func utilityMethod()"))
        
        // Cases should NOT have redundant "public" prefix
        XCTAssertFalse(overview.contains("public case first"))
        XCTAssertFalse(overview.contains("public case second"))
        XCTAssertFalse(overview.contains("public case third"))
    }
    
    func testDirectAPIUsage() throws {
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
        
        XCTAssertFalse(jsonOutput.isEmpty)
        XCTAssertFalse(yamlOutput.isEmpty)
        XCTAssertFalse(markdownOutput.isEmpty)
        XCTAssertFalse(interfaceOutput.isEmpty)
        
        XCTAssertTrue(jsonOutput.contains("DirectAPITest"))
        XCTAssertTrue(yamlOutput.contains("DirectAPITest"))
        XCTAssertTrue(markdownOutput.contains("DirectAPITest"))
        XCTAssertTrue(interfaceOutput.contains("DirectAPITest"))
    }
} 