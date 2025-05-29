# SAAE (Swift AST Abstractor & Editor) - Phase 1

SAAE is a Swift library that parses Swift source code and generates structured overviews of declarations. This Phase 1 implementation provides read-only analysis capabilities for Swift code.

## Features

- **Swift Code Parsing**: Parse Swift source code from files or strings using Apple's `swift-syntax`
- **Declaration Overview**: Extract structured information about declarations including:
  - Type, name, signature, visibility
  - Documentation comments (parsed into structured format)
  - Nested declarations with path-based identification
  - Visibility filtering
- **Multiple Output Formats**: JSON, YAML, and Markdown
- **Comprehensive Declaration Support**: Structs, classes, enums, protocols, extensions, functions, variables, initializers, subscripts, and type aliases

## Installation

Add SAAE as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-username/SAAE.git", from: "1.0.0")
]
```

## Usage

### Basic Usage

```swift
import SAAE

// Parse Swift code from a string
let swiftCode = """
/// A simple class example
public class Calculator {
    /// Adds two numbers
    /// - Parameter a: First number
    /// - Parameter b: Second number
    /// - Returns: Sum of a and b
    public func add(_ a: Int, _ b: Int) -> Int {
        return a + b
    }
}
"""

// Parse the code
let handle = try parse(from_string: swiftCode)

// Generate overview in different formats
let jsonOverview = try generate_overview(ast_handle: handle, format: .json)
let yamlOverview = try generate_overview(ast_handle: handle, format: .yaml)
let markdownOverview = try generate_overview(ast_handle: handle, format: .markdown)
```

### Parse from File

```swift
let fileURL = URL(fileURLWithPath: "path/to/your/file.swift")
let handle = try parse(from_url: fileURL)
let overview = try generate_overview(ast_handle: handle)
```

### Visibility Filtering

```swift
// Only include public declarations
let publicOnly = try generate_overview(
    ast_handle: handle, 
    format: .json,
    min_visibility: .public
)

// Include internal and above (default)
let internalAndAbove = try generate_overview(
    ast_handle: handle,
    min_visibility: .internal
)
```

## API Reference

### Core Functions

#### `parse(from_string:)`
```swift
func parse(from_string codeString: String) throws -> ASTHandle
```
Parses Swift source code from a string.

#### `parse(from_url:)`
```swift
func parse(from_url fileURL: URL) throws -> ASTHandle
```
Parses Swift source code from a file URL.

#### `generate_overview(ast_handle:format:min_visibility:)`
```swift
func generate_overview(
    ast_handle: ASTHandle,
    format: OutputFormat = .json,
    min_visibility: SAAE.VisibilityLevel = .internal
) throws -> String
```
Generates a structured overview of declarations in the parsed AST.

### Types

#### `OutputFormat`
- `.json` - JSON format with nested structure
- `.yaml` - YAML format with nested structure  
- `.markdown` - Markdown format with flattened structure

#### `VisibilityLevel`
- `.private`
- `.fileprivate`
- `.internal` (default minimum)
- `.package`
- `.public`
- `.open`

## Output Examples

### JSON Output
```json
[
  {
    "path": "1",
    "type": "class",
    "name": "Calculator",
    "fullName": "Calculator",
    "visibility": "public",
    "documentation": {
      "description": "A simple class example",
      "parameters": {},
      "returns": null
    },
    "members": [
      {
        "path": "1.1",
        "type": "func",
        "name": "add",
        "fullName": "Calculator.add",
        "signature": "func add(_ a: Int, _ b: Int) -> Int",
        "visibility": "public",
        "documentation": {
          "description": "Adds two numbers",
          "parameters": {
            "a": "First number",
            "b": "Second number"
          },
          "returns": "Sum of a and b"
        }
      }
    ]
  }
]
```

### Markdown Output
```markdown
# Code Overview

## Class: Calculator

**Path:** `1`  
**Visibility:** `public`  

A simple class example

**Children:**
- Path: `1.1`

---

## Func: Calculator.add

**Path:** `1.1`  
**Visibility:** `public`  
**Signature:** `func add(_ a: Int, _ b: Int) -> Int`  

Adds two numbers

**Parameters:**
- `a`: First number
- `b`: Second number

**Returns:** Sum of a and b

---
```

## Declaration Types Supported

- `struct` - Structures
- `class` - Classes
- `enum` - Enumerations
- `protocol` - Protocols
- `extension` - Extensions
- `func` - Functions and methods
- `var` - Variables and properties
- `let` - Constants
- `initializer` - Initializers
- `subscript` - Subscripts
- `typealias` - Type aliases

## Documentation Parsing

SAAE automatically parses Swift documentation comments (`///` and `/** */`) and structures them into:

- **Description**: Main documentation text
- **Parameters**: Parameter descriptions from `- Parameter name: description`
- **Returns**: Return value description from `- Returns: description`

## Path System

Each declaration is assigned a unique path based on its position in the source code:
- Top-level declarations: `"1"`, `"2"`, `"3"`, etc.
- Nested declarations: `"1.1"`, `"1.2"`, `"2.1.1"`, etc.

## Error Handling

SAAE throws `SAAEError` for various error conditions:
- `.fileNotFound(URL)` - File doesn't exist
- `.fileReadError(URL, Error)` - File read failure
- `.parseError(String)` - Swift syntax parsing error
- `.invalidASTHandle` - Invalid AST handle used

## Requirements

- Swift 5.7+
- macOS 10.15+ / iOS 13+ / tvOS 13+ / watchOS 6+

## Dependencies

- [swift-syntax](https://github.com/apple/swift-syntax) - Apple's Swift syntax library
- [Yams](https://github.com/jpsim/Yams) - YAML support

## Testing

Run the test suite with:

```bash
swift test
```

## License

[Add your license information here]

## Contributing

[Add contributing guidelines here] 
