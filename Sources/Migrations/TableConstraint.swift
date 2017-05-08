import Foundation


/// Describes a constraint defined on a table.
public final class TableConstraint {
    
    /// The name of the contraint, if specified.
    public let name:String?
    
    /// The clause defining the constraint, like "NOT NULL"
    public let clause:String
    
    init(name:String?, clause:String) {
        self.name = name
        self.clause = clause
    }
    
    /// The SQL version of the constraint.
    public var definition:String {
        if let name = name {
            return "CONSTRAINT \(escapeIdentifier(name)) \(clause)"
        } else {
            return clause
        }
    }
}
