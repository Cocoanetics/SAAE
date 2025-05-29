import Foundation
import SAAE

// Demo of SAAE functionality
print("🚀 SAAE (Swift AST Abstractor & Editor) Demo")
print("=============================================\n")

// Example Swift code to analyze
let exampleCode = """
/// A calculator class that performs basic arithmetic operations
public class Calculator {
    /// The current value stored in the calculator
    private var currentValue: Double = 0
    
    /// Creates a new calculator with an initial value
    /// - Parameter initialValue: The starting value for calculations
    public init(initialValue: Double = 0) {
        self.currentValue = initialValue
    }
    
    /// Adds a value to the current value
    /// - Parameter value: The value to add
    /// - Returns: The new current value
    public func add(_ value: Double) -> Double {
        currentValue += value
        return currentValue
    }
}

/// Errors that can occur during calculator operations
public enum CalculatorError: Error {
    case divisionByZero
    case overflow
}
"""

do {
    print("Parsing Swift code...")
    let handle = try parse(string: exampleCode)
    
    print("✅ Code parsed successfully!")
    print("\n📄 Generating JSON overview...")
    let jsonOverview = try generateOverview(astHandle: handle, format: .json)
    print(jsonOverview)
    
    print("\n📝 Generating Markdown overview...")
    let markdownOverview = try generateOverview(astHandle: handle, format: .markdown)
    print(markdownOverview)
    
} catch {
    print("❌ Error: \(error)")
} 