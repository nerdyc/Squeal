import Foundation

public extension VersionBuilder {
    
    /// Renames an index.
    ///
    /// - Parameters:
    ///   - from: The name of the index to rename.
    ///   - to: The new name.
    public func renameIndex(_ from:String, to:String, file:StaticString = #file, line:UInt = #line) {
        guard let index = indexNamed(from) else {
            fatalError("Unable to rename index: '\(from)' isn't in the schema", file:file, line:line)
        }
        
        guard let tableIndex = indexOfTable(index.tableName) else {
            fatalError("Unable to rename index: table '\(index.tableName)' isn't in the schema", file:file, line:line)
        }
        
        tables[tableIndex] = tables[tableIndex].renamingIndex(from, to:to)
        
        let renameTable = RenameIndex(
            name:from,
            renamedIndex: tables[tableIndex].indexNamed(to)!
        )
        transformers.append(renameTable)
    }
    
}

final class RenameIndex : Transformer {
    
    let name:String
    let renamedIndex:TableIndex
    
    init(name:String, renamedIndex:TableIndex) {
        self.name = name
        self.renamedIndex = renamedIndex
    }
    
    func transform(_ db: Database) throws {
        try db.dropIndex(name)
        try renamedIndex.createIn(db)
    }
    
}
