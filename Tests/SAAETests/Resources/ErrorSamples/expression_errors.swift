// Test file: Expression and syntax errors
import Foundation

class ExpressionErrors {
    func expressionProblems() {
        // Unexpected tokens
        let value = 5 6 7
        
        // Unbalanced operators
        let math = 1 + + 2
        
        // Invalid character sequences
        let invalid = "hello"@#$
        
        // Missing operand
        let incomplete = 5 +
        
        // Unbalanced brackets
        let array = [1, 2, 3
        
        // Invalid dictionary syntax
        let dict = [: "value"]
        
        // Missing closing quote
        let string = "unclosed string
        
        // Invalid number format
        let number = 123.45.67
    }
    
    // Invalid attribute syntax
    @#$%invalid
    func attributeError() {}
    
    // Missing declaration after attribute
    @objc
    
    // Invalid enum case
    enum BadEnum {
        case
        case valid
        case (invalid)
    }
} 