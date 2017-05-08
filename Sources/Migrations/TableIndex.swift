import Foundation


/// Describes an index on a `Table`.
public final class TableIndex {
    
    /// The name of the index.
    public let name:String
    
    /// The name of the table indexed.
    public let tableName:String
    
    /// The names of the indexed columns.
    public let columns:[String]
    
    /// The expression used to select the rows to index, e.g. "name IS NOT NULL".
    public let whereClause:String?
    
    @available(*, deprecated: 2.0)
    public var partialExpr:String? {
        return whereClause
    }
    
    /// Whether the index is unique.
    public let unique:Bool
    
    @available(*, deprecated: 2.0)
    convenience init(name:String, tableName:String, columns:[String], partialExpr whereClause:String?, unique:Bool = false) {
        self.init(name: name, tableName: tableName, columns: columns, whereClause: whereClause, unique: unique)
    }
    
    init(name:String, tableName:String, columns:[String], whereClause:String?, unique:Bool = false) {
        self.name = name
        self.tableName = tableName
        self.columns = columns
        self.whereClause = whereClause
        self.unique = unique
    }
    
    func withTableName(_ newTableName:String) -> TableIndex {
        return TableIndex(
            name:        name,
            tableName:   newTableName,
            columns:     columns,
            whereClause: whereClause,
            unique:      unique
        )
    }
    
    func renamedTo(_ newName:String) -> TableIndex {
        return TableIndex(
            name:        newName,
            tableName:   tableName,
            columns:     columns,
            whereClause: whereClause,
            unique:      unique
        )
    }
    
    func renamingColumn(_ columnName:String, to newName:String) -> TableIndex {
        guard let columnIndex = columns.index(of: columnName) else {
            return self
        }
        
        var renamedColumns = columns
        renamedColumns[columnIndex] = newName
        
        return TableIndex(
            name:        name,
            tableName:   tableName,
            columns:     renamedColumns,
            whereClause: whereClause,
            unique:      unique
        )
    }
    
    func createIn(_ db:Database) throws {
        try db.createIndex(
            name,
            on:     tableName,
            columns:columns,
            where:  whereClause,
            unique: unique
        )
    }
    
}

// =====================================================================================================================
// MARK:- TableIndexSet

public protocol TableIndexSet {
    
    var indexes:[TableIndex] { get }
    
}

public extension TableIndexSet {
    
    public func indexOfIndex(_ name:String) -> Int? {
        return indexes.index(where: { $0.name == name })
    }
    
    public var indexNames:[String] {
        return indexes.map { $0.name }
    }
    
    public func indexNamed(_ name:String) -> TableIndex? {
        guard let index = indexes.index(where: { $0.name == name }) else {
            return nil
        }
        
        return indexes[index]
    }
    
    public func containsIndexNamed(_ name:String) -> Bool {
        return indexNamed(name) != nil
    }
    
}

