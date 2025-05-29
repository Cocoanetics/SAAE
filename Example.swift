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
    
    /// Subtracts a value from the current value
    /// - Parameter value: The value to subtract
    /// - Returns: The new current value
    public func subtract(_ value: Double) -> Double {
        currentValue -= value
        return currentValue
    }
    
    /// Multiplies the current value by another value
    /// - Parameter value: The value to multiply by
    /// - Returns: The new current value
    public func multiply(by value: Double) -> Double {
        currentValue *= value
        return currentValue
    }
    
    /// Divides the current value by another value
    /// - Parameter value: The value to divide by
    /// - Returns: The new current value
    /// - Throws: CalculatorError.divisionByZero if value is zero
    public func divide(by value: Double) throws -> Double {
        guard value != 0 else {
            throw CalculatorError.divisionByZero
        }
        currentValue /= value
        return currentValue
    }
    
    /// Resets the calculator to zero
    public func clear() {
        currentValue = 0
    }
    
    /// Gets the current value without modification
    public var value: Double {
        return currentValue
    }
}

/// Errors that can occur during calculator operations
public enum CalculatorError: Error {
    case divisionByZero
    case overflow
    case underflow
}

/// Extension to add advanced mathematical operations
extension Calculator {
    /// Calculates the square of the current value
    /// - Returns: The squared value
    public func square() -> Double {
        currentValue = currentValue * currentValue
        return currentValue
    }
    
    /// Calculates the square root of the current value
    /// - Returns: The square root value
    /// - Throws: CalculatorError.underflow if current value is negative
    public func squareRoot() throws -> Double {
        guard currentValue >= 0 else {
            throw CalculatorError.underflow
        }
        currentValue = currentValue.squareRoot()
        return currentValue
    }
} 