import Foundation

/// Represents the complete overview of a Swift file including imports and declarations
public struct CodeOverview: Codable {
    public let imports: [String]
    public let declarations: [DeclarationOverview]
    
    public init(imports: [String], declarations: [DeclarationOverview]) {
        self.imports = imports
        self.declarations = declarations
    }
}

/// Represents a declaration in the overview
public struct DeclarationOverview: Codable {
    public let path: String
    public let type: String
    public let name: String
    public let fullName: String?
    public let signature: String?
    public let visibility: String
    public let documentation: Documentation?
    public let members: [DeclarationOverview]?
    
    public init(
        path: String,
        type: String,
        name: String,
        fullName: String? = nil,
        signature: String? = nil,
        visibility: String,
        documentation: Documentation? = nil,
        members: [DeclarationOverview]? = nil
    ) {
        self.path = path
        self.type = type
        self.name = name
        self.fullName = fullName
        self.signature = signature
        self.visibility = visibility
        self.documentation = documentation
        self.members = members
    }
} 