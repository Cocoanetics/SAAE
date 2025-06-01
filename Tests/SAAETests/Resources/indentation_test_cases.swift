import Foundation

// Test cases for IndentationRewriter
// This file contains various Swift constructs with inconsistent indentation
// to test the IndentationRewriter's ability to fix formatting

// MARK: - Basic Class and Struct Definitions

public class ExampleClass {
    public var name: String = ""
    private var age: Int = 0

    public init(name: String, age: Int) {
        self.name = name
        self.age = age
    }

    public func greet() {
        print("Hello, my name is \(name)")
    }

    private func calculateSomething() -> Int {
        let result = age * 2
        return result
    }
}

public struct Point {
    let x: Double
    let y: Double

    func distance(to other: Point) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }

    static func origin() -> Point {
        return Point(x: 0, y: 0)
    }
}

// MARK: - Enum with Cases and Methods

public enum TaskStatus {
    case pending
    case inProgress(startDate: Date)
    case completed(completionDate: Date)
    case cancelled(reason: String)

    func description() -> String {
        switch self {
            case .pending:
                return "Task is pending"
            case .inProgress(let date):
                return "Task started on \(date)"
            case .completed(let date):
                return "Task completed on \(date)"
            case .cancelled(let reason):
                return "Task cancelled: \(reason)"
        }
    }

    static func defaultStatus() -> TaskStatus {
        return .pending
    }
}

// MARK: - Protocol and Extension

public protocol Drawable {
    func draw()
    func area() -> Double
}

extension Point: Drawable {
    public func draw() {
        print("Drawing point at (\(x), \(y))")
    }

    public func area() -> Double {
        return 0.0
    }
}

// MARK: - Functions with Various Control Flow

public func processNumbers(_ numbers: [Int]) -> [Int] {
    var result: [Int] = []

    for number in numbers {
        if number > 0 {
            result.append(number * 2)
        } else             if number < 0 {
                result.append(abs(number))
            } else {
                result.append(1)
            }
    }

    return result
}

public func demonstrateControlFlow() {
    let numbers = [1, -2, 0, 4, -5]

// For loop with nested conditions
    for i in 0..<numbers.count {
        let num = numbers[i]
        switch num {
            case 0:
                print("Zero at index \(i)")
            case 1...10:
                print("Small positive: \(num)")
            case -10..<0:
                print("Small negative: \(num)")
            default:
                print("Other: \(num)")
        }
    }

// While loop
    var counter = 0
    while counter < 3 {
        print("Counter: \(counter)")
        counter += 1
    }

// Do-while equivalent
repeat {
counter -= 1
print("Countdown: \(counter)")
} while counter > 0
}

// MARK: - Nested Structures

public struct Organization {
    let name: String
    var departments: [Department]

    struct Department {
        let name: String
        var employees: [Employee]

        struct Employee {
            let name: String
            let role: String
            var salary: Double

            func getFormattedSalary() -> String {
                return String(format: "$%.2f", salary)
            }

            mutating func giveRaise(percentage: Double) {
                salary *= (1.0 + percentage / 100.0)
            }
        }

        func getTotalSalary() -> Double {
            return employees.reduce(0) { total, employee in
            return total + employee.salary
        }
        }

        mutating func addEmployee(_ employee: Employee) {
            employees.append(employee)
        }
    }

    func getTotalEmployees() -> Int {
        return departments.reduce(0) { total, dept in
        return total + dept.employees.count
    }
    }
}

// MARK: - Generic Functions and Types

public struct Stack<Element> {
    private var items: [Element] = []

    mutating func push(_ item: Element) {
        items.append(item)
    }

    mutating func pop() -> Element? {
        return items.popLast()
    }

    func peek() -> Element? {
        return items.last
    }

    var isEmpty: Bool {
    return items.isEmpty
}

    var count: Int {
    return items.count
}
}

public func findMaximum<T: Comparable>(_ array: [T]) -> T? {
    guard !array.isEmpty else {
    return nil
}

    var maximum = array[0]
    for element in array[1...] {
        if element > maximum {
            maximum = element
        }
    }
    return maximum
}

// MARK: - Closures and Higher-Order Functions

public func demonstrateClosures() {
    let numbers = [1, 2, 3, 4, 5]

// Map with trailing closure
    let doubled = numbers.map { number in
    return number * 2
}

// Filter with shorthand
    let evens = numbers.filter {     $0 % 2 == 0 }

// Reduce with explicit closure
    let sum = numbers.reduce(0) { (result, number) in
    return result + number
}

// Sort with comparison
    let sorted = numbers.sorted { (first, second) in
    return first > second
}

    print("Doubled: \(doubled)")
    print("Evens: \(evens)")
    print("Sum: \(sum)")
    print("Sorted desc: \(sorted)")
}

// MARK: - Multiline String Literals

public func demonstrateMultilineStrings() {
    let poem = """
    Roses are red,
    Violets are blue,
        Swift is awesome,
    And so are you!
    """

    let jsonExample = """
{
    "name": "John Doe",
    "age": 30,
    "address": {
        "street": "123 Main St",
        "city": "Anytown"
    }
}
"""

    let code = """
func example() {
    print("Hello")
    if true {
        print("World")
    }
}
"""

    print("Poem:\n\(poem)")
    print("\nJSON:\n\(jsonExample)")
    print("\nCode:\n\(code)")
}

// MARK: - Error Handling

public enum ValidationError: Error {
    case emptyString
    case tooShort(minimum: Int)
    case tooLong(maximum: Int)
    case invalidCharacters
}

public func validateName(_ name: String) throws -> String {
    guard !name.isEmpty else {
    throw ValidationError.emptyString
}

    guard name.count >= 2 else {
    throw ValidationError.tooShort(minimum: 2)
}

    guard name.count <= 50 else {
    throw ValidationError.tooLong(maximum: 50)
}

    let allowedCharacters = CharacterSet.letters.union(.whitespaces)
    guard name.unicodeScalars.allSatisfy({     allowedCharacters.contains($0) }) else {
    throw ValidationError.invalidCharacters
}

    return name.trimmingCharacters(in: .whitespaces)
}

public func processNames(_ names: [String]) {
    for name in names {
        do {
        let validName = try validateName(name)
        print("Valid name: \(validName)")
    } catch ValidationError.emptyString {
        print("Error: Name cannot be empty")
    } catch ValidationError.tooShort(let minimum) {
        print("Error: Name must be at least \(minimum) characters")
    } catch ValidationError.tooLong(let maximum) {
        print("Error: Name must be no more than \(maximum) characters")
    } catch ValidationError.invalidCharacters {
        print("Error: Name contains invalid characters")
    } catch {
        print("Unexpected error: \(error)")
    }
    }
}

// MARK: - Actors (Swift 5.5+)

@available(macOS 10.15, *)
public actor BankAccount {
    private var balance: Double = 0.0

    func deposit(_ amount: Double) {
        guard amount > 0 else { return     }
        balance += amount
        print("Deposited $\(amount). New balance: $\(balance)")
    }

    func withdraw(_ amount: Double) -> Bool {
        guard amount > 0 && amount <= balance else {
        return false
    }
        balance -= amount
        print("Withdrew $\(amount). New balance: $\(balance)")
        return true
    }

    func getBalance() -> Double {
        return balance
    }
}

// MARK: - Complex Switch Statements

public func processValue(_ value: Any) {
    switch value {
        case let stringValue as String:
            print("String: \(stringValue)")
        case let intValue as Int where intValue > 100:
            print("Large integer: \(intValue)")
        case let intValue as Int:
            print("Integer: \(intValue)")
        case let doubleValue as Double:
            print("Double: \(doubleValue)")
        case let arrayValue as [Any]:
            print("Array with \(arrayValue.count) elements")
        case let point as Point:
            print("Point at (\(point.x), \(point.y))")
        default:
            print("Unknown type: \(type(of: value))")
    }
}

// MARK: - Property Wrappers and Computed Properties

@propertyWrapper
public struct Clamped<T: Comparable> {
    private var value: T
    private let min: T
    private let max: T

    public init(wrappedValue: T, min: T, max: T) {
        self.min = min
        self.max = max
        self.value = Swift.min(Swift.max(wrappedValue, min), max)
    }

    public var wrappedValue: T {
get {     value }
set {     value = Swift.min(Swift.max(newValue, min), max) }
}
}

public struct Settings {
    @Clamped(min: 0, max: 100)
var volume: Int = 50

    @Clamped(min: 0.0, max: 1.0)
var brightness: Double = 0.8

    var isValid: Bool {
    return volume >= 0 && brightness >= 0.0
}

    func summary() -> String {
        return "Volume: \(volume)%, Brightness: \(Int(brightness * 100))%"
    }
} 
