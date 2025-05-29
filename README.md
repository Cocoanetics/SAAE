# SAAE (Swift AST Abstractor & Editor)

SAAE is a Swift library that parses Swift source code and generates clean, structured overviews of your API declarations. **Perfect for quickly giving LLMs a comprehensive overview of your Swift codebase's public interface.**

## 🚀 Quick Start with Demo App

The fastest way to try SAAE is with the included demo app:

```bash
# Clone the repository
git clone https://github.com/Cocoanetics/SAAE.git
cd SAAE

# Run the demo on any Swift file
swift run SAAEDemo path/to/your/file.swift

# Or analyze multiple files
swift run SAAEDemo Sources/MyFramework/ --format interface --visibility public
```

## 🎯 Primary Use Case: LLM API Analysis

SAAE's **interface format** generates clean, Xcode-style Swift interfaces that are perfect for:

- 📋 **API Documentation**: Get a quick overview of your framework's public interface
- 🤖 **LLM Context**: Provide AI assistants with your complete API structure 
- 🔍 **Code Review**: Understand what's exposed publicly in large codebases
- 📖 **Documentation**: Generate interface files for documentation

## 📋 Interface Format Example

Given this Swift code:

```swift
/// A utility class for mathematical operations
@MainActor
public final class MathUtils {
    /// The mathematical constant pi
    public static let pi: Double = 3.14159
    
    /// Calculates the area of a circle
    /// - Parameter radius: The radius of the circle
    /// - Returns: The area of the circle
    public static func circleArea(radius: Double) -> Double {
        return pi * radius * radius
    }
}
```

SAAE generates this clean interface:

```swift
import Foundation

@MainActor
public final class MathUtils {
    public static let pi: Double
    public static func circleArea(radius: Double) -> Double
}
```

**Perfect for LLMs!** Clean, concise, and shows exactly what's available in your API.

## 🛠️ Demo App Usage

The demo app supports multiple input types and formats:

### Analyze a Single File
```bash
swift run SAAEDemo MyClass.swift --format interface
```

### Analyze an Entire Directory  
```bash
swift run SAAEDemo Sources/MyFramework/ --format interface --visibility public
```

### Different Output Formats
```bash
# Swift interface (recommended for LLMs)
swift run SAAEDemo MyFile.swift --format interface

# JSON (for programmatic use)
swift run SAAEDemo MyFile.swift --format json

# YAML (human-readable structured data)
swift run SAAEDemo MyFile.swift --format yaml

# Markdown (for documentation)
swift run SAAEDemo MyFile.swift --format markdown
```

### Visibility Filtering
```bash
# Only public declarations (great for frameworks)
swift run SAAEDemo MyFramework/ --visibility public

# Include internal and above (default)
swift run SAAEDemo MyFramework/ --visibility internal

# Everything including private
swift run SAAEDemo MyFramework/ --visibility private
```

## 📦 Library Usage

You can also use SAAE as a library in your own Swift projects:

```swift
import SAAE

// Parse Swift code
let handle = try parse(from_url: URL(fileURLWithPath: "MyFile.swift"))

// Generate interface overview
let interface = try generate_overview(
    ast_handle: handle,
    format: .interface,
    min_visibility: .public
)

print(interface)
```

## 🔧 Installation

Add SAAE as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Cocoanetics/SAAE.git", branch: "main")
]
```

## 📊 Output Formats

| Format | Best For | Description |
|--------|----------|-------------|
| **interface** | 🤖 **LLM Analysis** | Clean Swift interface like Xcode's "Generated Interface" |
| json | 📱 Programmatic use | Structured data with full metadata |
| yaml | 👤 Human reading | Structured data, more readable than JSON |
| markdown | 📖 Documentation | Rich formatting with headers and sections |

## 🎯 Why the Interface Format?

The interface format is specifically designed for **LLM consumption**:

- ✅ **Clean & Minimal**: No implementation details, just the public contract
- ✅ **Swift Syntax**: LLMs understand Swift syntax better than JSON/YAML
- ✅ **Comprehensive**: Includes modifiers, attributes, and signatures
- ✅ **Familiar**: Looks exactly like Xcode's "Generated Interface" view

## 🔍 What SAAE Extracts

SAAE captures comprehensive declaration information:

- **Types**: structs, classes, enums, protocols, extensions
- **Members**: functions, properties, initializers, subscripts
- **Metadata**: visibility, modifiers (`static`, `final`, etc.), attributes (`@Published`, `@MainActor`)
- **Documentation**: Parsed from `///` comments
- **Signatures**: Complete function/property signatures
- **Hierarchy**: Nested declarations with proper structure

## 💡 Pro Tips

### For LLM Analysis
```bash
# Get public API overview for an entire framework
swift run SAAEDemo Sources/MyFramework/ --format interface --visibility public > api_overview.swift

# Then include api_overview.swift in your LLM prompt!
```

### For Multiple Files
```bash
# Analyze all Swift files in a directory
swift run SAAEDemo MyProject/ --format interface --recursive
```

### For Quick Debugging
```bash
# See what's actually public in your module
swift run SAAEDemo Sources/ --visibility public --format interface
```

## 🔧 Requirements

- Swift 5.7+
- macOS 10.15+ / iOS 13+ / tvOS 13+ / watchOS 6+

## 📄 License

[Add your license information here]

## 🤝 Contributing

[Add contributing guidelines here] 
