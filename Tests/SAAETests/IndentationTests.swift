import Testing
import Foundation
@testable import SAAE

@Suite("Indentation Tests")
struct IndentationTests {
    
    @Test("Test basic indentation with 4 spaces")
    func testBasicIndentationFourSpaces() throws {
        let badlyIndentedCode = """
        import Foundation
        
        public class TestClass {
        public var property: String = ""
        
        public func method() {
        print("Hello")
        }
        }
        """
        
        let tree = try SyntaxTree(string: badlyIndentedCode)
        let reindented = try tree.reindent(indentSize: 4)
        let result = reindented.serializeToCode()
        
        // Check that properties and methods are indented with 4 spaces
        #expect(result.contains("    public var property"))
        #expect(result.contains("    public func method"))
        #expect(result.contains("        print(\"Hello\")"))
    }
    
    @Test("Test basic indentation with 2 spaces")
    func testBasicIndentationTwoSpaces() throws {
        let badlyIndentedCode = """
        public struct TestStruct {
        let value: Int
        
        func compute() {
        return value * 2
        }
        }
        """
        
        let tree = try SyntaxTree(string: badlyIndentedCode)
        let reindented = try tree.reindent(indentSize: 2)
        let result = reindented.serializeToCode()
        
        // Check that properties and methods are indented with 2 spaces
        #expect(result.contains("  let value"))
        #expect(result.contains("  func compute"))
        #expect(result.contains("    return value"))
    }
    
    @Test("Test switch statement indentation")
    func testSwitchStatementIndentation() throws {
        let badlyIndentedCode = """
        public func process(_ value: String) {
        switch value {
        case "a":
        print("Found a")
        case "b":
        print("Found b")
        default:
        print("Other")
        }
        }
        """
        
        let tree = try SyntaxTree(string: badlyIndentedCode)
        let reindented = try tree.reindent(indentSize: 4)
        let result = reindented.serializeToCode()
        
        // Check switch case indentation
        #expect(result.contains("    switch value"))
        #expect(result.contains("        case \"a\":"))
        #expect(result.contains("            print(\"Found a\")"))
        #expect(result.contains("    }"))  // Closing brace aligned with switch
    }
    
    @Test("Test nested structures")
    func testNestedStructures() throws {
        let badlyIndentedCode = """
        public struct Outer {
        public struct Inner {
        let value: Int
        
        func process() {
        if value > 0 {
        print("Positive")
        } else {
        print("Non-positive")
        }
        }
        }
        }
        """
        
        let tree = try SyntaxTree(string: badlyIndentedCode)
        let reindented = try tree.reindent(indentSize: 4)
        let result = reindented.serializeToCode()
        
        // Check nested indentation
        #expect(result.contains("    public struct Inner"))
        #expect(result.contains("        let value"))
        #expect(result.contains("        func process"))
        #expect(result.contains("            if value > 0"))
        #expect(result.contains("            } else {"))
    }
    
    @Test("Test enum with cases")
    func testEnumWithCases() throws {
        let badlyIndentedCode = """
        public enum Status {
        case pending
        case active(String)
        case completed(Date)
        
        func description() -> String {
        switch self {
        case .pending:
        return "Pending"
        case .active(let name):
        return "Active: \\(name)"
        case .completed(let date):
        return "Completed: \\(date)"
        }
        }
        }
        """
        
        let tree = try SyntaxTree(string: badlyIndentedCode)
        let reindented = try tree.reindent(indentSize: 4)
        let result = reindented.serializeToCode()
        
        // Check enum case indentation
        #expect(result.contains("    case pending"))
        #expect(result.contains("    case active(String)"))
        #expect(result.contains("    func description"))
        #expect(result.contains("        switch self"))
    }
    
    @Test("Test multiline string literals")
    func testMultilineStringLiterals() throws {
        let badlyIndentedCode = """
        public class Example {
        public func test() {
        let message = \"\"\"
            This is line 1
            This is line 2
                Indented line 3
            \"\"\"
        
        let anotherString = \"\"\"
        No leading spaces
            Some spaces here
        \"\"\"
        
        print(message)
        }
        }
        """
        
        let tree = try SyntaxTree(string: badlyIndentedCode)
        let reindented = try tree.reindent(indentSize: 4)
        let result = reindented.serializeToCode()
        
        // Check that the class and function are properly indented
        #expect(result.contains("    public func test"))
        #expect(result.contains("        let message"))
        #expect(result.contains("        print(message)"))
        
        // Check that string literal content is preserved exactly as in the original
        #expect(result.contains("    This is line 1"))           // Original: 4 spaces
        #expect(result.contains("    This is line 2"))           // Original: 4 spaces
        #expect(result.contains("        Indented line 3"))      // Original: 8 spaces
        #expect(result.contains("No leading spaces"))            // Original: no spaces
        #expect(result.contains("    Some spaces here"))         // Original: 4 spaces
        
        // The main requirement: surrounding code is indented, string content preserved
        #expect(result.contains("public class Example {"))
        #expect(result.contains("    public func test() {"))
        #expect(result.contains("        let message = "))
        #expect(result.contains("        let anotherString = "))
    }
} 