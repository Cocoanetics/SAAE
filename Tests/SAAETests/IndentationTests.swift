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
    
    @Test("Test else-if statements")
    func testElseIfStatements() throws {
        let badlyIndentedCode = """
        public func processNumbers(_ numbers: [Int]) -> [Int] {
        var result: [Int] = []
        
        for number in numbers {
        if number > 0 {
        result.append(number * 2)
        } else if number < 0 {
        result.append(abs(number))
        } else {
        result.append(1)
        }
        }
        
        // Do-while equivalent
        repeat {
        result.append(0)
        } while result.count < 10
        
        return result
        }
        """
        
        let tree = try SyntaxTree(string: badlyIndentedCode)
        let reindented = try tree.reindent(indentSize: 4)
        let result = reindented.serializeToCode()
        
        // Check that else-if is properly formatted without extra spaces
        #expect(result.contains("        } else if number < 0 {"))
        #expect(!result.contains("} else             if number < 0 {"))
        
        // Check proper indentation levels
        #expect(result.contains("    var result: [Int] = []"))
        #expect(result.contains("    for number in numbers {"))
        #expect(result.contains("        if number > 0 {"))
        #expect(result.contains("            result.append(number * 2)"))
        #expect(result.contains("        } else if number < 0 {"))
        #expect(result.contains("            result.append(abs(number))"))
        #expect(result.contains("        } else {"))
        #expect(result.contains("            result.append(1)"))
        
        // Check repeat statement indentation
        #expect(result.contains("    repeat {"))
        #expect(result.contains("        result.append(0)"))
        #expect(result.contains("    } while result.count < 10"))
        
        #expect(result.contains("    return result"))
    }

    @Test("Continuation indent for function parameters")
    func testContinuationParameters() throws {
        let code = """
        public func foo(mainFileURL: URL, physicalFileID: String) throws {
        NSLog("[%@] Create Variant %@", objectID, config.name )
        let (imageData, _) = try self.createVariant(config: config,
        inputURL: mainFileURL,
        physicalFileID: physicalFileID,
        sentToVendorUTC: sentToVendorUTC)
        }
        """

        let tree = try SyntaxTree(string: code)
        let reindented = try tree.reindent(indentSize: 4)
        let result = reindented.serializeToCode()

        let lines = result.split(separator: "\n", omittingEmptySubsequences: false)
        let configIndex = lines.firstIndex { $0.contains("config: config") }!
        let nextLine = lines[configIndex + 1]
        #expect(nextLine.trimmingCharacters(in: .whitespaces).hasPrefix("inputURL:"))
        let indentCount = nextLine.prefix { $0 == " " }.count
        #expect(indentCount > 0)
    }

    @Test("Continuation indent for collection literals")
    func testContinuationCollections() throws {
        let code = """
        public func demo() {
        let numbers = [
        1,
        2,
        3
        ]
        let dict = [
        "a": 1,
        "b": 2
        ]
        }
        """

        let tree = try SyntaxTree(string: code)
        let reindented = try tree.reindent(indentSize: 4)
        let result = reindented.serializeToCode()

        let collectionLines = result.split(separator: "\n", omittingEmptySubsequences: false)
        let arrayIndex = collectionLines.firstIndex { $0.contains("let numbers = [") }!
        let arrayLine1 = String(collectionLines[arrayIndex + 1])
        #expect(arrayLine1.trimmingCharacters(in: .whitespaces).hasPrefix("1,"))
        let dictIndex = collectionLines.firstIndex { $0.contains("let dict = [") }!
        let dictLine1 = String(collectionLines[dictIndex + 1])
        #expect(dictLine1.trimmingCharacters(in: .whitespaces).hasPrefix("\"a\":"))
    }
} 