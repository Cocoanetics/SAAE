// Test file: Valid Swift code (no syntax errors)
import Foundation

/// A valid class for testing error-free parsing
public class ValidExample {
    /// A string property
    public let name: String
    
    /// An optional integer property
    public var count: Int?
    
    /// Initializer
    public init(name: String, count: Int? = nil) {
        self.name = name
        self.count = count
    }
    
    /// A method with parameters and return value
    public func processData(input: String, options: [String: Any] = [:]) throws -> String {
        guard !input.isEmpty else {
            throw ValidationError.emptyInput
        }
        
        let processed = input.uppercased()
        count = (count ?? 0) + 1
        
        return processed
    }
    
    /// Generic method
    public func transform<T, U>(_ value: T, using transformer: (T) -> U) -> U {
        return transformer(value)
    }
}

/// A valid enum
public enum ValidationError: Error {
    case emptyInput
    case invalidFormat(String)
    case timeout
}

/// A valid struct
public struct DataContainer<Element> {
    private var elements: [Element] = []
    
    public var count: Int {
        return elements.count
    }
    
    public mutating func append(_ element: Element) {
        elements.append(element)
    }
    
    public func forEach(_ body: (Element) throws -> Void) rethrows {
        try elements.forEach(body)
    }
}

/// Extension with computed property
extension DataContainer where Element: Equatable {
    public func contains(_ element: Element) -> Bool {
        return elements.contains(element)
    }
} 