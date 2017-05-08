import Foundation

extension VersionBuilder {
    
    /// Removes an index from a database table.
    ///
    /// - Parameters:
    ///   - name: The name of the index to remove.
    public func dropIndex(_ name:String, file:StaticString = #file, line:UInt = #line) {
        guard let index = indexNamed(name) else {
            fatalError("Unable to drop index from schema: \'\(name)\' isn't in the schema", file:file, line:line)
        }
        
        guard let tableIndex = indexOfTable(index.tableName) else {
            fatalError("Unable to drop index from schema: table \'\(index.tableName)\' isn't in the schema", file:file, line:line)
        }
        
        tables[tableIndex] = tables[tableIndex].droppingIndex(name)
        
        let dropIndex = DropIndex(name:name)
        transformers.append(dropIndex)
    }
    
}

final class DropIndex : Transformer {
    
    let name:String
    
    init(name:String) {
        self.name = name
    }
    
    func transform(_ db: Database) throws {
        try db.dropIndex(name)
    }
    
}
