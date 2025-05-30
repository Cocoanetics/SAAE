// Test file: Variable/Function syntax confusion
import Foundation

class SyntaxConfusion {
    
    // MARK: - Colon vs Arrow Confusion
    
    // Using -> instead of : for variable type
    let property1 -> String = "hello"
    var property2 -> Int = 42
    
    // Using : instead of -> for function return type
    func method1() : String {
        return "wrong arrow"
    }
    
    func method2() : Int {
        return 42
    }
    
    // MARK: - Keyword Confusion
    
    // Using func instead of var/let
    func property3: String = "should be var"
    func property4: Int = 123
    
    // Using var/let instead of func  
    var method3() -> String {
        return "should be func"
    }
    
    let method4() -> Int {
        return 42
    }
    
    // MARK: - Mixed up syntax
    
    // Function with assignment instead of body
    func confused() -> String = "this is wrong"
    
    // Variable with parameter list
    let withParams(input: String): String = input
    var withMultipleParams(a: Int, b: String): Bool = true
    
    // Using both : and -> incorrectly
    func doubleWrong() : -> String {
        return "confused"
    }
    
    let alsoDoubleWrong -> : Int = 5
    
    // MARK: - Parameter vs Property confusion
    
    // Property with parameter syntax
    let parameterLike(name: String) = "John"
    
    // Function without parentheses but with return type
    func noParens -> String {
        return "missing parens"
    }
    
    // MARK: - Generic syntax confusion
    
    // Generic property (not valid)
    let genericProp<T>: T = "invalid"
    
    // Function with property-style generic
    func genericFunc: <T>(value: T) -> T {
        return value
    }
    
    // MARK: - Computed property vs function confusion
    
    // Computed property with wrong syntax
    var computed -> String {
        get {
            return "wrong arrow"
        }
    }
    
    // Function that looks like computed property
    func () -> String {
        get {
            return "confused"
        }
    }
} 