# SAAE (Swift AST Abstractor & Editor)

SAAE is a Swift library that parses Swift source code and generates clean, structured overviews of your API declarations. **Perfect for efficiently providing LLMs with comprehensive API overviews instead of overwhelming them with entire codebases.**

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

## 🎯 Why SAAE for LLMs?

**The Problem**: Feeding entire codebases to LLMs is inefficient and often hits token limits. Implementation details create noise that obscures the actual API structure.

**The Solution**: SAAE's **interface format** extracts only what matters for API understanding:

- 🎯 **Signal over Noise**: Clean interfaces vs. cluttered implementation
- 📏 **Token Efficient**: 10-100x smaller than full source code  
- 🧠 **Better Understanding**: LLMs focus on API contracts, not implementation details
- ⚡ **Faster Processing**: Less content = faster LLM analysis

### Get Your Complete Public API in One Command

```bash
# Copy your entire framework's public interface to clipboard
swift run SAAEDemo Sources -v public -r | pbcopy
```

Then paste directly into your LLM conversation for instant API analysis!

## 📋 Interface Format Example

SAAE transforms verbose implementation code into clean, focused interfaces:

**What you feed the LLM** (SAAE interface):
```swift
import Foundation

/// A utility class for mathematical operations
@MainActor
public final class MathUtils {
    /// The mathematical constant pi
    public static var pi: Double { get }
    
    /**
     Calculates the area of a circle
     
     - Parameter radius: The radius of the circle
     - Returns: The area of the circle
     */
    public static func circleArea(radius: Double) -> Double
}
```

**Instead of** overwhelming with full implementation details, private methods, imports, and internal complexity.

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

### Copy Full API to Clipboard
```bash
# Get complete public API overview 
swift run SAAEDemo Sources -v public -r | pbcopy
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

You can also use SAAE as a library in your own Swift projects with the clean, direct API:

### Two-Step API Pattern
```swift
import SAAE

// Step 1: Parse Swift code into a syntax tree
let tree = try SyntaxTree(url: URL(fileURLWithPath: "MyFile.swift"))

// Step 2: Create code overview with specific visibility
let codeOverview = CodeOverview(tree: tree, minVisibility: .public)

// Generate different formats
let json = try codeOverview.json()
let yaml = try codeOverview.yaml() 
let markdown = codeOverview.markdown()
let interface = codeOverview.interface()

// Access parsed data directly
let imports = codeOverview.imports
let declarations = codeOverview.declarations
```

### Parse from String
```swift
import SAAE

// Parse from Swift source code string
let tree = try SyntaxTree(string: swiftCode)
let overview = CodeOverview(tree: tree, minVisibility: .internal)
let interface = overview.interface()
```

### Multi-File Analysis
```swift
import SAAE

let urls = [
    URL(fileURLWithPath: "File1.swift"),
    URL(fileURLWithPath: "File2.swift")
]

// Analyze each file and combine results
var allDeclarations: [DeclarationOverview] = []
for url in urls {
    let tree = try SyntaxTree(url: url)
    let overview = CodeOverview(tree: tree, minVisibility: .public)
    allDeclarations.append(contentsOf: overview.declarations)
}
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

## 🎯 Why Interface Format Beats Full Source?

### For LLM Analysis:

**Interface Format** ✅
- Clean API contracts only
- Documentation preserved  
- No implementation noise
- 10-100x smaller file sizes
- Faster LLM processing
- Better understanding focus

**Full Source Code** ❌
- Overwhelming implementation details
- Private/internal clutter
- Large token consumption
- Slower processing
- API contracts buried in noise

### Example Token Savings:
- **Full Framework**: 50,000+ tokens
- **SAAE Interface**: 500-2,000 tokens
- **Savings**: 90-95% token reduction!

## 🔍 What SAAE Extracts

SAAE captures comprehensive declaration information:

- **Types**: structs, classes, enums, protocols, extensions
- **Members**: functions, properties, initializers, subscripts
- **Metadata**: visibility, modifiers (`static`, `final`, etc.), attributes (`@Published`, `@MainActor`)
- **Documentation**: Parsed from `///` comments with parameter details
- **Signatures**: Complete function/property signatures
- **Hierarchy**: Nested declarations with proper structure

## 💡 Pro Tips

### For LLM Analysis
```bash
# Get your complete public API and copy to clipboard
swift run SAAEDemo Sources -v public -r | pbcopy

# Then paste into your LLM conversation for instant API understanding!
```

### For Framework Authors
```bash
# See exactly what you're exposing publicly
swift run SAAEDemo Sources/ --visibility public --format interface > public_api.swift
```

### For Code Reviews
```bash
# Quick overview of changes in a specific module
swift run SAAEDemo Sources/MyModule/ --format interface
```

### For Documentation
```bash
# Generate markdown docs for your API
swift run SAAEDemo Sources/ --format markdown --visibility public > API_DOCS.md
```

## 🔧 Requirements

- Swift 5.7+
- macOS 10.15+ / iOS 13+ / tvOS 13+ / watchOS 6+

## 📄 License

[Add your license information here]

## 🤝 Contributing

[Add contributing guidelines here] 
