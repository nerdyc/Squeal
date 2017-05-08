import Foundation

extension VersionBuilder {
    
    /// Adds an index to a table.
    ///
    /// - Parameters:
    ///   - name: The index name.
    ///   - tableName: The table to index.
    ///   - columns: The columns to index.
    ///   - whereClause: An expression used to create a partial index. The index will only cover rows that match this
    ///                  expression.
    ///   - unique: Whether the index should enforce uniqueness.
    public func createIndex(_ name:String, on tableName:String, columns:[String], where whereClause:String? = nil, unique:Bool = false, file:StaticString = #file, line:UInt = #line) {
        
        guard let tableIndex = indexOfTable(tableName) else {
            fatalError("Unable to create '\(name)' index: table '\(tableName)' doesn't exist")
        }
        
        tables[tableIndex] = tables[tableIndex].addingIndex(name,
                                                            columns:    columns,
                                                            where:      whereClause,
                                                            unique:     unique)

        let transformer = CreateIndex(index:tables[tableIndex].indexNamed(name)!)
        transformers.append(transformer)
    }
    
}

final class CreateIndex : Transformer {
    
    let index:TableIndex
    
    init(index:TableIndex) {
        self.index = index
    }
    
    func transform(_ db: Database) throws {
        try db.createIndex(
            index.name,
            on:         index.tableName,
            columns:    index.columns,
            where:      index.whereClause,
            unique:     index.unique
        )
    }
    
}

@available(*, deprecated: 2.0)
public extension VersionBuilder {

    public func createIndex(_ name:String, on tableName:String, columns:[String], partialExpr whereClause:String?, unique:Bool = false, file:StaticString = #file, line:UInt = #line) {

        self.createIndex(name, on: tableName, columns: columns, where: whereClause, unique: unique, file:file, line:line)
        
    }
    
}
