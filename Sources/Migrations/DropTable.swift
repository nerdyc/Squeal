import Foundation

extension VersionBuilder {
        
    /// Removes a table (and therefore all indexes) from the database.
    ///
    /// - Parameters:
    ///   - name: The name of the table to remove.
    public func dropTable(_ name:String, file:StaticString = #file, line:UInt = #line) {
        guard !didCreateTable(name) else {
            fatalError("Attempt to drop a table created in the same version", file:file, line:line)
        }
        
        guard let index = tables.index(where: { $0.name == name }) else {
            fatalError("Unable to drop table from schema: \'\(name)\' isn't in the schema", file:file, line:line)
        }
        
        tables.remove(at: index)
        
        let dropTable = DropTable(name:name)
        transformers.append(dropTable)
    }
    
}

final class DropTable : Transformer {
    
    let name:String
    
    init(name:String) {
        self.name = name
    }
    
    func transform(_ db: Database) throws {
        try db.dropTable(name)
    }
    
}
