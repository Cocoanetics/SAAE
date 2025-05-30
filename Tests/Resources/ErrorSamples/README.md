# Swift Syntax Error Samples

This directory contains Swift files with intentional syntax errors to demonstrate SAAE's Phase 2 error detection capabilities. Each file showcases different categories of common Swift syntax mistakes.

## Error Sample Files

### `missing_braces.swift`
Demonstrates missing closing braces in various contexts:
- Missing function closing braces
- Missing class closing braces  
- Missing control flow statement braces
- Nested brace mismatches

### `type_annotations.swift`
Shows type annotation related errors:
- Missing colons in type annotations (`let property String = "hello"`)
- Missing variable names (`let = 42`)
- Invalid type syntax combinations
- Missing types after colons
- Incorrect parameter type syntax

### `function_errors.swift`
Covers function declaration syntax errors:
- Missing function names (`func () { }`)
- Missing parameter names
- Invalid return type syntax
- Missing parentheses in function signatures
- Unbalanced parentheses in function calls
- Invalid generic parameter syntax

### `expression_errors.swift`
Contains expression and token-related syntax errors:
- Unexpected token sequences (`let value = 5 6 7`)
- Unbalanced operators (`let math = 1 + + 2`)
- Invalid character sequences
- Missing operands
- Unbalanced brackets and parentheses
- Invalid dictionary syntax
- Unclosed string literals
- Invalid number formats
- Malformed attributes and enum cases

### `syntax_confusion.swift`
Demonstrates confusion between similar Swift constructs:
- Using `->` instead of `:` for variable types
- Using `:` instead of `->` for function return types
- Mixing `func`/`var`/`let` keywords incorrectly
- Function assignment syntax vs proper function bodies
- Properties with parameter lists
- Functions without required parentheses
- Invalid generic syntax combinations
- Computed property syntax errors

### `valid_file.swift`
A syntactically correct Swift file containing:
- Proper class, struct, and enum declarations
- Correct function signatures and implementations
- Valid generic syntax
- Proper documentation comments
- Extension declarations

## Error Categories Covered

- **Structural Errors**: Missing braces, unbalanced parentheses
- **Type System Errors**: Incorrect type annotations, missing types
- **Declaration Errors**: Invalid function/variable/class declarations
- **Expression Errors**: Malformed expressions, invalid tokens
- **Syntax Confusion**: Common mistakes between similar constructs
- **Generic Syntax**: Invalid generic parameter declarations
- **Attribute Errors**: Malformed attributes and decorators

These samples provide comprehensive coverage of Swift syntax error patterns that developers commonly encounter. 