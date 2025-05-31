// Test file: Type annotation errors
import Foundation

class TypeAnnotationErrors {
    // Missing colon in type annotation
    let property1 String = "hello"
    
    // Missing variable name
    let = 42
    
    // Invalid type syntax
    var property2: Int String = 5
    
    // Missing type after colon
    let property3: = "test"
    
    func method() {
        // Missing colon in local variable
        let localVar Int = 10
        
        // Invalid parameter syntax
        func invalidParam( String) {
            print("invalid")
        }
    }
} 