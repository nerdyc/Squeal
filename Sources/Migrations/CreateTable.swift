import Foundation

extension VersionBuilder {
    
    /// Adds a table to the database.
    ///
    /// - Parameters:
    ///   - name: The name of the table.
    ///   - block: A block that defines the table's structure.
    public func createTable(_ name:String, block:(TableBuilder)->Void) {
        let builder = TableBuilder(name:name)
        block(builder)
        let table = builder.build()
        
        let transformer = CreateTable(table: table)
        tables.append(table)
        transformers.append(transformer)
    }

    func didCreateTable(_ name:String) -> Bool {
        for createTable in transformers.flatMap({ $0 as? CreateTable }) {
            if createTable.table.name == name {
                return true
            }
        }
        
        return false
    }

}

final class CreateTable : Transformer {
    
    let table:Table
    
    init(table:Table) {
        self.table = table
    }
    
    func transform(_ db: Database) throws {
        try db.createTable(
            table.name,
            definitions: table.definitions
        )
    }
    
}

// =================================================================================================
// MARK:- TableBuilder


/// Defines the DSL used to define new tables.
public final class TableBuilder {
    
    /// The name of the table.
    public let name:String
    
    init(name:String) {
        self.name = name
    }
    
    func build() -> Table {
        return Table(name:name, columns: columns, constraints: constraints, indexes: [])
    }
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Columns
    
    fileprivate(set) var columns = [Column]()

    
    /// Adds an integer primary key column to the table.
    ///
    /// - Parameters:
    ///   - name: The name of the column.
    ///   - autoincrement: Whether the column should auto-increment. Note that "AUTOINCREMENT" has special meaning in
    ///                    sqlite.
    public func primaryKey(_ name:String, autoincrement:Bool = false) {
        var constraints = [ "PRIMARY KEY" ]
        if autoincrement {
            constraints.append("AUTOINCREMENT")
        }
        
        column(name, type:.Integer, constraints: constraints)
    }
    
    /// Adds a column to the table.
    ///
    /// - Parameters:
    ///   - name: The column name.
    ///   - type: The type of column to add.
    ///   - constraints: constraints on the column, like "NOT NULL".
    public func column(_ name:String, type:ColumnType, constraints:[String] = []) {
        let column = Column(name: name, type: type, constraints: constraints)
        columns.append(column)
    }
    
    /// Adds a column to the table.
    ///
    /// - Parameters:
    ///   - name: The column name.
    ///   - type: The type of column to add.
    ///   - constraints: constraints on the column, like "NOT NULL".
    public func column(_ name:String, _ type:ColumnType, _ constraints:String...) {
        column(name, type: type, constraints: constraints)
    }
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Constraints
    
    fileprivate(set) var constraints = [TableConstraint]()

    
    /// Adds a constraint to the table.
    ///
    /// - Parameters:
    ///   - clause: The constraint clause.
    ///   - name: A name for the constraint.
    public func constraint(_ clause:String, named name:String? = nil) {
        constraints.append(TableConstraint(name:name, clause:clause))
    }

}
