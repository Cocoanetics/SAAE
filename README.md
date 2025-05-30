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

# Check for syntax errors with detailed reporting
swift run SAAEDemo errors Sources/ --recursive --format markdown
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

## 🚨 Error Checking & Syntax Validation

SAAE goes beyond just parsing - it provides **advanced error detection and reporting** with precise positioning and helpful fix-it suggestions. Perfect for code validation, CI/CD pipelines, and development tooling.

> **🤖 Perfect for Code Generators**: SAAE provides **ultra-fast syntax validation** for Swift code produced by code generators, LLMs, and automated tools. While it cannot perform semantic checking (like type validation), it **catches all syntax errors** with precise positioning - making it ideal for validating generated code before compilation.

### Quick Error Checking
```bash
# Check syntax errors in a file
swift run SAAEDemo errors MyFile.swift

# Check entire project with detailed reporting
swift run SAAEDemo errors Sources/ --recursive --format markdown

# JSON output for CI/CD integration
swift run SAAEDemo errors Sources/ --format json --show-fixits
```

### Real-World Error Detection

SAAE detects and precisely locates various Swift syntax errors:

```swift
// SAAE will detect and report these issues:

func invalidFunc: <T>(value: T) -> T {  // ❌ Syntax error
    return value
}

var property: Int String = 5  // ❌ Missing '=' operator

let incomplete = 1 + + 2  // ❌ Invalid operator sequence
```

**SAAE Error Output:**
```
Tests/Resources/ErrorSamples/type_annotations.swift:6:18: error: expected ':' in type annotation
5 ┃     // Missing colon in type annotation
6 ┃     let property1 String = "hello"
  ┃                  ┣━━ error: expected ':' in type annotation
  ┃                  ┗━━ fix-it: insert `: ` and remove ` `
7 ┃     

Tests/Resources/ErrorSamples/type_annotations.swift:9:9: error: expected pattern in variable
 8 ┃     // Missing variable name
 9 ┃     let = 42
   ┃         ┣━━ error: expected pattern in variable
   ┃         ┗━━ fix-it: insert `<#pattern#> `
10 ┃     

Tests/Resources/ErrorSamples/type_annotations.swift:12:24: error: expected '=' in variable
11 ┃     // Invalid type syntax
12 ┃     var property2: Int String = 5
   ┃                        ┣━━ error: expected '=' in variable
   ┃                        ┗━━ fix-it: insert `= `
13 ┃     

Tests/Resources/ErrorSamples/type_annotations.swift:15:20: error: expected type in type annotation
14 ┃     // Missing type after colon
15 ┃     let property3: = "test"
   ┃                    ┣━━ error: expected type in type annotation
   ┃                    ┗━━ fix-it: insert `<#type#> `
16 ┃     

Tests/Resources/ErrorSamples/type_annotations.swift:19:21: error: expected ':' in type annotation
18 ┃         // Missing colon in local variable
19 ┃         let localVar Int = 10
   ┃                     ┣━━ error: expected ':' in type annotation
   ┃                     ┗━━ fix-it: insert `: ` and remove ` `
20 ┃         

Tests/Resources/ErrorSamples/type_annotations.swift:22:34: error: expected ':' and type in parameter
21 ┃         // Invalid parameter syntax
22 ┃         func invalidParam( String) {
   ┃                                  ┣━━ error: expected ':' and type in parameter
   ┃                                  ┗━━ fix-it: insert `: <#type#>`
23 ┃             print("invalid")
```

### Error Checking Features

#### 🎯 **Precise Positioning**
- **Exact line and column** positioning for every error
- **Context-aware reporting** with source line display
- **Multi-line error context** for complex issues

#### 🔧 **Intelligent Fix-It Suggestions**
- **Automatic fix recommendations** based on SwiftSyntax analysis
- **Multi-step fix-its** combined into logical operations
- **User-friendly descriptions** instead of cryptic compiler internals

#### 📊 **Multiple Output Formats**
```bash
# Markdown format (human-readable)
swift run SAAEDemo errors Sources/ --format markdown

# JSON format (CI/CD integration)
swift run SAAEDemo errors Sources/ --format json

# YAML format (structured but readable)
swift run SAAEDemo errors Sources/ --format yaml
```

#### 🚀 **CI/CD Integration Ready**
```bash
# Exit with error code if syntax errors found
swift run SAAEDemo errors Sources/ --format json

# Use in GitHub Actions, Jenkins, etc.
if swift run SAAEDemo errors Sources/; then
    echo "✅ No syntax errors found"
else
    echo "❌ Syntax errors detected"
    exit 1
fi
```

### Error Checking API

Use SAAE's error detection programmatically:

```swift
import SAAE

// Check errors in a file
let tree = try SyntaxTree(url: URL(fileURLWithPath: "MyFile.swift"))
let errors = tree.syntaxErrors

// Process each error
for error in errors {
    print("Error at \(error.location.line):\(error.location.column)")
    print("Message: \(error.message)")
    print("Source: \(error.sourceLineText)")
    
    // Check for fix-it suggestions
    if !error.fixIts.isEmpty {
        print("Fix-its available:")
        for fixIt in error.fixIts {
            print("  - \(fixIt.description)")
        }
    }
}

// Generate comprehensive error report
let hasErrors = !errors.isEmpty
let errorReport = errors.map { error in
    "\(error.location.line):\(error.location.column): \(error.message)"
}.joined(separator: "\n")
```

### Advanced Error Detection

SAAE catches sophisticated syntax errors that basic parsers miss:

- **Generic syntax errors** with precise type parameter positioning
- **Function declaration issues** including parameter list problems  
- **Variable declaration errors** with missing operators or types
- **Expression syntax errors** in complex statements
- **Operator precedence issues** and malformed expressions
- **Missing braces, brackets, and delimiters** with context

### Why SAAE for Error Checking?

**🤖 Code Generator Validation**
- **Ultra-fast syntax checking** for generated Swift code from LLMs, templates, and automation tools
- **Instant feedback** without compilation overhead - perfect for validating code before writing to disk
- **Syntax-only validation** catches malformed declarations, missing operators, invalid expressions
- **Not semantic checking** - won't catch type mismatches or undefined variables, but catches all syntax errors

**🎯 Superior Accuracy**
- Built on SwiftSyntax for **100% Swift-compliant** parsing
- **Precise character-level positioning** verified by comprehensive tests
- **Context-aware error messages** that make sense to developers

**⚡ Performance Optimized**
- **Fast parsing** suitable for real-time validation
- **Efficient memory usage** for large codebases
- **Parallel processing** support for multiple files

**🔧 Developer Friendly**
- **Clear, actionable error messages** without compiler jargon
- **Visual error context** with source line highlighting
- **Automated fix suggestions** to speed up debugging

**🚀 Integration Ready**  
- **Multiple output formats** for different workflows
- **Exit codes** for CI/CD pipeline integration
- **Structured data** for custom tooling development

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
| **json** | 📱 **Programmatic use** | Structured data with full metadata for API analysis |
| **yaml** | 👤 **Human reading** | Structured data, more readable than JSON |
| **markdown** | 📖 **Documentation** | Rich formatting with headers and sections |
| **errors** | 🚨 **Error checking** | Precise syntax error detection with fix-it suggestions |

### Error Checking Formats
| Format | Use Case | Output |
|--------|----------|---------|
| `errors` + `--format markdown` | **Human review** | Formatted error reports with context |
| `errors` + `--format json` | **CI/CD integration** | Structured error data for automation |
| `errors` + `--format yaml` | **Configuration** | Readable structured error reports |

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

### For Code Quality
```bash
# Validate syntax before commits
swift run SAAEDemo errors Sources/ --format json

# Generate error reports for review
swift run SAAEDemo errors Sources/ --recursive --format markdown > error_report.md

# Quick syntax check
swift run SAAEDemo errors MyChangedFile.swift
```

### For Code Generators
```bash
# Validate generated Swift code instantly
swift run SAAEDemo errors generated_code.swift

# Batch validate multiple generated files
swift run SAAEDemo errors GeneratedCode/ --recursive --format json

# Use in code generation pipelines
if swift run SAAEDemo errors "$generated_file"; then
    echo "✅ Generated code is syntactically valid"
    # Safe to write to final destination
else
    echo "❌ Generated code has syntax errors - regenerating..."
    # Handle regeneration or fix-up logic
fi
```

## 🔧 Requirements

- Swift 5.7+
- macOS 10.15+ / iOS 13+ / tvOS 13+ / watchOS 6+

## 📄 License

[Add your license information here]

## 🤝 Contributing

[Add contributing guidelines here] 
