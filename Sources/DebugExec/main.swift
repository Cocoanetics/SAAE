import SAAE
import Foundation

let swiftCode = """
public struct MyStruct {
    /// Old doc
    public func foo() {}
    public func bar() {}
}
"""

print("Token locations:")
debugPrintTokenLines(swiftCode)

do {
    let tree = try SyntaxTree(string: swiftCode)
    let info1 = tree.findNodesAtLine(1)
    print("Line 1 nodes: \(info1.nodes.count)")
    let info3 = tree.findNodesAtLine(3)
    print("Line 3 nodes: \(info3.nodes.count)")
} catch {
    print("Error: \(error)")
} 