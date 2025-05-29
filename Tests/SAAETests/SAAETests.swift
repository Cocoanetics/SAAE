import XCTest
@testable import SAAE

final class SAAETests: XCTestCase {
    
    func testParseFromString() throws {
        let swiftCode = """
        /// A simple struct for testing
        public struct TestStruct {
            /// A test property
            public let name: String
            
            /// Test initializer
            /// - Parameter name: The name value
            public init(name: String) {
                self.name = name
            }
            
            /// Test method
            /// - Parameter prefix: Prefix to add
            /// - Returns: Modified name
            public func getName(with prefix: String) -> String {
                return prefix + name
            }
        }
        """
        
        let handle = try parse(string: swiftCode)
        XCTAssertNotNil(handle)
    }
    
    func testGenerateJSONOverview() throws {
        let swiftCode = """
        /// A test class
        public class TestClass {
            /// Property
            private var value: Int = 0
            
            /// Method
            func testMethod() -> String {
                return "test"
            }
        }
        """
        
        let handle = try parse(string: swiftCode)
        let overview = try generateOverview(astHandle: handle, format: .json)
        
        XCTAssertFalse(overview.isEmpty)
        XCTAssertTrue(overview.contains("TestClass"))
        XCTAssertTrue(overview.contains("class"))
        XCTAssertTrue(overview.contains("public"))
    }
    
    func testGenerateYAMLOverview() throws {
        let swiftCode = """
        internal struct SimpleStruct {
            let property: String
        }
        """
        
        let handle = try parse(string: swiftCode)
        let overview = try generateOverview(astHandle: handle, format: .yaml)
        
        XCTAssertFalse(overview.isEmpty)
        XCTAssertTrue(overview.contains("SimpleStruct"))
    }
    
    func testGenerateMarkdownOverview() throws {
        let swiftCode = """
        /// Documentation for protocol
        public protocol TestProtocol {
            /// Required method
            /// - Parameter input: Input value
            /// - Returns: Output value
            func process(_ input: String) -> String
        }
        """
        
        let handle = try parse(string: swiftCode)
        let overview = try generateOverview(astHandle: handle, format: .markdown)
        
        XCTAssertFalse(overview.isEmpty)
        XCTAssertTrue(overview.contains("# Code Overview"))
        XCTAssertTrue(overview.contains("## Protocol: TestProtocol"))
        XCTAssertTrue(overview.contains("Documentation for protocol"))
        XCTAssertTrue(overview.contains("**Parameters:**"))
        XCTAssertTrue(overview.contains("**Returns:**"))
    }
    
    func testVisibilityFiltering() throws {
        let swiftCode = """
        public struct PublicStruct {
            public let publicProperty: String
            internal let internalProperty: String
            private let privateProperty: String
        }
        """
        
        let handle = try parse(string: swiftCode)
        
        // Test with public visibility
        let publicOverview = try generateOverview(astHandle: handle, format: .json, minVisibility: .public)
        XCTAssertTrue(publicOverview.contains("PublicStruct"))
        XCTAssertTrue(publicOverview.contains("publicProperty"))
        XCTAssertFalse(publicOverview.contains("internalProperty"))
        XCTAssertFalse(publicOverview.contains("privateProperty"))
        
        // Test with internal visibility
        let internalOverview = try generateOverview(astHandle: handle, format: .json, minVisibility: .internal)
        XCTAssertTrue(internalOverview.contains("PublicStruct"))
        XCTAssertTrue(internalOverview.contains("publicProperty"))
        XCTAssertTrue(internalOverview.contains("internalProperty"))
        XCTAssertFalse(internalOverview.contains("privateProperty"))
    }
    
    func testNestedDeclarations() throws {
        let swiftCode = """
        public struct OuterStruct {
            public struct InnerStruct {
                public let value: Int
                
                public func method() -> Int {
                    return value
                }
            }
            
            public let inner: InnerStruct
        }
        """
        
        let handle = try parse(string: swiftCode)
        let overview = try generateOverview(astHandle: handle, format: .json)
        
        XCTAssertTrue(overview.contains("OuterStruct"))
        XCTAssertTrue(overview.contains("InnerStruct"))
        XCTAssertTrue(overview.contains("members"))
    }
    
    func testDocumentationParsing() throws {
        let swiftCode = """
        /// This is a test function
        /// - Parameter name: The name parameter
        /// - Parameter age: The age parameter  
        /// - Returns: A greeting string
        public func greet(name: String, age: Int) -> String {
            return "Hello \\(name), you are \\(age)"
        }
        """
        
        let handle = try parse(string: swiftCode)
        let overview = try generateOverview(astHandle: handle, format: .json)
        
        XCTAssertTrue(overview.contains("This is a test function"))
        XCTAssertTrue(overview.contains("name"))
        XCTAssertTrue(overview.contains("age"))
        XCTAssertTrue(overview.contains("returns"))
    }
    
    func testInvalidASTHandle() throws {
        let invalidHandle = ASTHandle()
        
        XCTAssertThrowsError(try generateOverview(astHandle: invalidHandle)) { error in
            if let saaError = error as? SAAEError {
                XCTAssertEqual(saaError, .invalidASTHandle)
            } else {
                XCTFail("Expected SAAEError.invalidASTHandle")
            }
        }
    }
    
    func testFileNotFound() throws {
        let nonExistentURL = URL(fileURLWithPath: "/nonexistent/file.swift")
        
        XCTAssertThrowsError(try parse(url: nonExistentURL)) { error in
            if let saaError = error as? SAAEError,
               case .fileNotFound = saaError {
                // Expected error
            } else {
                XCTFail("Expected SAAEError.fileNotFound")
            }
        }
    }
    
    func testPathGeneration() throws {
        let swiftCode = """
        struct OuterStruct {
            struct InnerStruct {
                let value: Int
                func method() -> Int { return value }
            }
            let property: String
        }
        """
        
        let handle = try parse(string: swiftCode)
        let overview = try generateOverview(astHandle: handle, format: .json)
        
        // Check that paths are generated correctly
        XCTAssertTrue(overview.contains("\"path\" : \"1\"")) // OuterStruct
        XCTAssertTrue(overview.contains("\"path\" : \"1.1\"")) // InnerStruct  
        XCTAssertTrue(overview.contains("\"path\" : \"1.1.1\"")) // value
        XCTAssertTrue(overview.contains("\"path\" : \"1.1.2\"")) // method
        XCTAssertTrue(overview.contains("\"path\" : \"1.2\"")) // property
    }
    
    func testGenerateInterfaceOverview() throws {
        let swiftCode = """
        /// A calculator for testing
        public class Calculator {
            /// Divides two numbers
            /// - Parameter value: The divisor
            /// - Throws: `CalculatorError.divisionByZero` if value is zero
            /// - Returns: The result
            public func divide(by value: Double) throws -> Double {
                guard value != 0 else { throw CalculatorError.divisionByZero }
                return 10.0 / value
            }
        }
        
        /// Calculator errors
        public enum CalculatorError: Error {
            case divisionByZero
        }
        """
        
        let handle = try parse(string: swiftCode)
        let overview = try generateOverview(astHandle: handle, format: .interface)
        
        XCTAssertFalse(overview.isEmpty)
        XCTAssertTrue(overview.contains("/// A calculator for testing"))
        XCTAssertTrue(overview.contains("public class Calculator"))
        XCTAssertTrue(overview.contains("/**\n"))
        XCTAssertTrue(overview.contains(" Divides two numbers"))
        XCTAssertTrue(overview.contains(" - Parameters:\n"))
        XCTAssertTrue(overview.contains("   - value: The divisor"))
        XCTAssertTrue(overview.contains(" - Throws: `CalculatorError.divisionByZero` if value is zero"))
        XCTAssertTrue(overview.contains(" - Returns: The result"))
        XCTAssertTrue(overview.contains("public func divide(by value: Double) throws -> Double"))
        XCTAssertTrue(overview.contains("/// Calculator errors"))
        XCTAssertTrue(overview.contains("public enum CalculatorError"))
    }
    
    func testAllDeclarationTypes() throws {
        let swiftCode = """
        /// Enum declaration
        enum TestEnum {
            case first, second
        }
        
        /// Protocol declaration
        protocol TestProtocol {
            associatedtype T
            func method() -> T
        }
        
        /// Class declaration
        class TestClass: TestProtocol {
            typealias T = String
            
            func method() -> String {
                return "test"
            }
            
            subscript(index: Int) -> String {
                return "subscript"
            }
        }
        
        /// Extension declaration
        extension TestClass {
            var computed: String {
                return "computed"
            }
        }
        """
        
        let handle = try parse(string: swiftCode)
        let overview = try generateOverview(astHandle: handle, format: .json)
        
        // Check that all declaration types are captured
        XCTAssertTrue(overview.contains("enum"))
        XCTAssertTrue(overview.contains("protocol"))
        XCTAssertTrue(overview.contains("class"))
        XCTAssertTrue(overview.contains("extension"))
        XCTAssertTrue(overview.contains("typealias"))
        XCTAssertTrue(overview.contains("func"))
        XCTAssertTrue(overview.contains("subscript"))
        XCTAssertTrue(overview.contains("var"))
    }
    
    func testBlockCommentDocumentation() throws {
        let swiftCode = """
        /**
         A test class with block comment documentation
         This class demonstrates multi-line block comments
         - Parameter value: A test parameter
         - Returns: A test return value
         - Throws: An error if something goes wrong
         */
        public class BlockCommentTest {
            /** Single line block comment */
            public func singleLineMethod() -> String {
                return "test"
            }
            
            /**
             Multi-line block comment method
             - Parameter input: The input string
             - Returns: The processed string
             */
            public func multiLineMethod(_ input: String) -> String {
                return input.uppercased()
            }
        }
        """
        
        let handle = try parse(string: swiftCode)
        let overview = try generateOverview(astHandle: handle, format: .interface)
        
        XCTAssertFalse(overview.isEmpty)
        
        // Check for /** */ format for multi-line descriptions and /** */ for complex
        XCTAssertTrue(overview.contains("/**\n"))
        XCTAssertTrue(overview.contains(" A test class with block comment documentation"))
        XCTAssertTrue(overview.contains(" This class demonstrates multi-line block comments"))
        XCTAssertTrue(overview.contains("/// Single line block comment"))
        XCTAssertTrue(overview.contains(" Multi-line block comment method"))
        XCTAssertTrue(overview.contains(" - Parameters:\n"))
        XCTAssertTrue(overview.contains("   - input: The input string"))
        XCTAssertTrue(overview.contains(" - Returns: The processed string"))
        XCTAssertTrue(overview.contains(" */"))
        
        // Ensure we're using /// for simple comments now
        XCTAssertTrue(overview.contains("///"))
        
        // Ensure no input-style comment artifacts remain
        XCTAssertFalse(overview.contains(" * "))
    }
} 