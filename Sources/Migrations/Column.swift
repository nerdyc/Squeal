import Foundation


/// Used to define the type of a table column.
public enum ColumnType : String {
    
    case Text       = "TEXT"
    case Integer    = "INTEGER"
    case Real       = "REAL"
    case Blob       = "BLOB"
    
}

/// Describes a table column at a particular version of a database table.
public final class Column {
    
    /// The column name.
    public let name:String
    
    /// The column type.
    public let type:ColumnType
    
    /// Constraints defined on the column, like "NOT NULL", or "DEFAULT 0"
    public let constraints:[String]
    
    init(name:String, type:ColumnType, constraints:[String]) {
        self.name = name
        self.type = type
        self.constraints = constraints
    }
    
    var definition:String {
        var definition = "\(escapeIdentifier(name)) \(type.rawValue)"
        if !constraints.isEmpty {
            definition.append(" ")
            definition += constraints.joined(separator: " ")
        }
        return definition
    }
    
    func renamedTo(_ newName:String) -> Column {
        return Column(name:newName, type:type, constraints: constraints)
    }
    
}
