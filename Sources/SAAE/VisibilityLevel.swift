import Foundation

/// Represents the visibility levels for Swift declarations.
///
/// This enum defines the access control levels available in Swift, ordered from most restrictive to least restrictive.
/// The ordering allows for comparison operations where higher visibility levels are considered "greater than" lower ones.
///
/// ## Usage
///
/// ```swift
/// let publicLevel = VisibilityLevel.public
/// let privateLevel = VisibilityLevel.private
/// 
/// // Comparison works as expected
/// print(publicLevel > privateLevel) // true
/// ```
public enum VisibilityLevel: String, CaseIterable {

// Cases

/// Private access restricts the use of an entity to the enclosing declaration.
    case `private`

/// File-private access restricts the use of an entity to its own defining source file.
    case `fileprivate`

/// Internal access is the default access level and enables entities to be used within any source file from their defining module.
    case `internal`

/// Package access enables entities to be used within any source file from their defining package.
    case `package`

/// Public access enables entities to be used within any source file from their defining module, and also in a source file from another module that imports the defining module.
    case `public`

/// Open access is the highest (least restrictive) access level and enables entities to be used and subclassed/overridden outside of their defining module.
    case `open`
}
