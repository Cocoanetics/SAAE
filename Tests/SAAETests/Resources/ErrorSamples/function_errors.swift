// Test file: Function declaration errors
import Foundation

class FunctionErrors {
    // Missing function name
    func () {
        print("anonymous function")
    }
    
    // Missing parameter name
    func badParam(: String) {
        print("missing param name")
    }
    
    // Invalid return type syntax
    func badReturn() -> {
        return "invalid"
    }
    
    // Missing parentheses
    func missingParens -> String {
        return "no parens"
    }
    
    // Unbalanced parentheses in call
    func validFunc() {
        print("hello"
        // Missing closing paren
    }
    
    // Invalid generic syntax
    func genericError<>() {
        print("empty generic")
    }
} 