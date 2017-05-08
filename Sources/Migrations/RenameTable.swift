import Foundation

public extension VersionBuilder {

    /// Renames a table.
    ///
    /// - Parameters:
    ///   - from: The name of the table to rename.
    ///   - to: The new name of the table.
    public func renameTable(_ from:String, to:String, file:StaticString = #file, line:UInt = #line) {
        guard !containsTableNamed(to) else {
            fatalError("Unable to rename table: '\(to)' already exists.", file:file, line:line)
        }
        
        guard let index = indexOfTable(from) else {
            fatalError("Unable to rename table: '\(from)' isn't in the schema", file:file, line:line)
        }
        
        tables[index] = tables[index].renamedTo(to)
        
        let renameTable = RenameTable(from: from, to: to)
        transformers.append(renameTable)
    }
    
}

final class RenameTable : Transformer {
    
    let from:String
    let to:String
    
    init(from:String, to:String) {
        self.from = from
        self.to = to
    }
    
    func transform(_ db: Database) throws {
        try db.renameTable(from, to: to)
    }
    
}

extension Table {
    
    func renamedTo(_ name:String) -> Table {
        return Table(
            name:        name,
            columns:     columns,
            constraints: constraints,
            indexes:     indexes.map {
                $0.withTableName(name)
            }
        )
    }
    
}
