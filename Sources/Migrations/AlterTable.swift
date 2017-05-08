import Foundation

public extension VersionBuilder {
    
    /// Alters a table. The provided block is used to define the changes made to the table.
    ///
    /// - Parameters:
    ///   - name: The name of the table to change.
    ///   - block: Builder block that defines changes to the table.
    public func alterTable(_ name:String, block:(TableAlterer)->Void) {
        guard let tableIndex = indexOfTable(name) else {
            fatalError("Unable to alter table: '\(name)' doesn't exist")
        }
        
        let alterer = TableAlterer(table:tables[tableIndex])
        block(alterer)
        
        tables[tableIndex] = alterer.table
        transformers.append(alterer.buildTransformer())
    }
    
}


/// Defines the DSL for making changes to a table.
public final class TableAlterer {
    
    init(table:Table) {
        self.previousTable = table
    }
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Table
    
    let previousTable:Table
    
    var table:Table {
        return transformers.last?.alteredTable ?? previousTable
    }
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Transformer
    
    fileprivate var transformers = [TableTransformer]()
    
    func buildTransformer() -> Transformer {
        return CompositeTransformer(transformers: transformers)
    }
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Add Column
    
    /// Adds a column to a table.
    ///
    /// - Parameters:
    ///   - name: The name of the column to add.
    ///   - type: The column's type (e.g. "TEXT")
    ///   - constraints: An array of constraints to add to the column (e.g. "NOT NULL", "DEFAULT 0").
    public func addColumn(_ name:String, _ type:ColumnType, _ constraints:String...) {
        addColumn(name, type:type, constraints: constraints)
    }

    /// Adds a column to a table, optionally setting a new value for
    ///
    /// - Parameters:
    ///   - name: The name of the column to add.
    ///   - type: The column's type (e.g. "TEXT")
    ///   - constraints: An array of constraints to add to the column (e.g. "NOT NULL", "DEFAULT 0").
    ///   - initialExpr: A SQL expression used to set the value of the column for existing rows in the table. Unlike
    ///                  a `DEFAULT 0` constraint, this expression is only used to set the value for existing rows. The
    ///                  expression can also reference other columns in the table row (before migration). For example
    ///                  adding a "display_name" column could be set to the name or email with `coalesce(name, email)`.
    ///
    public func addColumn(_ name:String, type:ColumnType, constraints:[String] = [], initialExpr:String? = nil) {
        let column = Column(name: name, type: type, constraints: constraints)
        
        if let lastTransform = transformers.last as? AlterTable {
            // Add the column along with the preceding alteration.
            transformers[transformers.endIndex-1] = lastTransform.addingColumn(column, initialExpr:initialExpr)
        } else if let initialExpr = initialExpr {
            // create a new alteration to handle calculating the initial value
            transformers.append(
                AlterTable(table).addingColumn(column, initialExpr:initialExpr)
            )
        } else {
            // Add a transform to add the column using the "ADD COLUMN" form, which is faster than an AlterTable.
            transformers.append(
                AddColumn(
                    table: table,
                    column: column
                )
            )
        }
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK: Alter Column
    
    /// Changes an existing table column.
    ///
    /// - Parameters:
    ///   - name: The name of the column to change.
    ///   - newName: A new name for the column. If nil, the column isn't renamed.
    ///   - newType: The new type for the column. If nil, the column's type isn't changed.
    ///   - constraints: New column constraints. These will replace the existing constraints, not add them.
    ///   - valueExpr: An expression used to change the value of each row in the table. This is useful to cleanup data.
    ///                For example, `ifnull(name,'')` could be used to replace NULL values with the empty string.
    public func alterColumn(_ name:String, renameTo newName:String? = nil, changeTypeTo newType:ColumnType? = nil, setConstraints constraints:[String]? = nil, setValue valueExpr:String? = nil) {
        
        alterTable {
            $0.alteringColumn(
                name,
                renameTo:       newName,
                changeTypeTo:   newType,
                setConstraints: constraints,
                setValue:       valueExpr
            )
        }
    }
    
    fileprivate func alterTable( _ block:(AlterTable)->AlterTable) {
        if let lastTransform = transformers.last as? AlterTable {
            transformers[transformers.endIndex-1] = block(lastTransform)
        } else {
            transformers.append(
                block(AlterTable(table))
            )
        }
    }
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Drop Column
    
    /// Removes a table column.
    ///
    /// - Parameter name: The name of the column to remove.
    public func dropColumn(_ name:String) {
        alterTable {
            $0.droppingColumn(name)
        }
    }
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Constraints
    
    /// Adds a constraint to the table, optionally with a name.
    ///
    /// - Parameters:
    ///   - clause: The constraint clause to add.
    ///   - name: An optional name for the constraint.
    public func addConstraint(_ clause:String, named name:String? = nil) {
        alterTable {
            $0.addingConstraint(clause, named:name)
        }
    }
    
    /// Removes a named constraint.
    ///
    /// - Parameter name: The name of the constraint to remove.
    public func dropConstraint(named name:String) {
        alterTable {
            $0.droppingConstraintNamed(name)
        }
    }
    
    /// Drops the constraint whose clause matches the given string.
    ///
    /// - Parameter constraint: The constraint to remove (e.g. "NOT NULL").
    public func dropConstraint(_ constraint:String) {
        alterTable {
            $0.droppingConstraint(constraint)
        }
    }
    
    /// Removes all constraints from the table.
    public func dropAllConstraints() {
        alterTable {
            $0.droppingAllConstraints()
        }
    }
}

final class CompositeTransformer : Transformer {
    
    let transformers:[TableTransformer]
    
    init(transformers:[TableTransformer]) {
        self.transformers = transformers
    }
    
    func transform(_ db: Database) throws {
        for transformer in transformers {
            try transformer.transform(db)
        }
    }
    
}

final class AddColumn : TableTransformer {

    let previousTable:Table
    let column:Column
    let alteredTable:Table
    
    init(table:Table, column:Column) {
        self.previousTable = table
        self.column = column
        self.alteredTable = table.addingColumn(column)
    }
    
    func transform(_ db: Database) throws {
        try db.addColumnToTable(
            previousTable.name,
            column: column.definition
        )
    }
    
}

private final class AlterTable : TableTransformer {
    
    let alteredTable:Table
    let alteredValues:[String]
    
    init(_ table:Table) {
        self.alteredTable = table
        self.alteredValues = table.escapedColumnNames
    }
    
    init(alteredTable:Table, alteredValues:[String]) {
        self.alteredTable = alteredTable
        self.alteredValues = alteredValues
    }
    
    func transform(_ db: Database) throws {
        let tempTableName = alteredTable.name + "_" + String(Int(Date().timeIntervalSinceReferenceDate))
        
        try db.createTable(tempTableName, definitions: alteredTable.definitions)
        
        // copy data to the temporary table
        let copySql =
            "INSERT INTO " +
            escapeIdentifier(tempTableName) +
            " (" +
            alteredTable.escapedColumnNames.joined(separator: ", ") +
            ") SELECT " +
            alteredValues.joined(separator: ", ") +
            " FROM " +
            escapeIdentifier(alteredTable.name)
        
        try db.execute(copySql)
        
        // drop the previous table
        try db.dropTable(alteredTable.name)
        
        // rename the copied table
        try db.renameTable(tempTableName, to: alteredTable.name)
        
        // re-create indexes
        for index in alteredTable.indexes {
            try index.createIn(db)
        }
        
        // check foreign keys
        let violations = try db.selectAll("PRAGMA foreign_key_check", block: ForeignKeyViolation.init)
        if !violations.isEmpty {
            throw SquealMigrationError.foreignKeysViolated(violations:violations)
        }
    }
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Add Column
    
    func addingColumn(_ column:Column, initialExpr:String?) -> AlterTable {
        return AlterTable(
            alteredTable:   alteredTable.addingColumn(column),
            alteredValues:  alteredValues + [initialExpr ?? "NULL"]
        )
    }
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Alter Column

    func alteringColumn(_ columnName:String, renameTo newName:String?, changeTypeTo newType:ColumnType?, setConstraints constraints:[String]?, setValue valueExpr:String?) -> AlterTable {
        
        guard let columnIndex = self.alteredTable.indexOfColumn(columnName) else {
            fatalError("Unable to alter column in '\(self.alteredTable.name)': '\(columnName)' column doesn't exist.")
        }
        
        // alter the column in the table...
        let alteredTable = self.alteredTable.alteringColumn(
            columnName,
            renameTo: newName,
            changeTypeTo: newType,
            setConstraints: constraints
        )
        
        // ...and alter its value if needed.
        var alteredValues = self.alteredValues
        if let valueExpr = valueExpr {
            alteredValues[columnIndex] = valueExpr
        }
        
        return AlterTable(
            alteredTable: alteredTable,
            alteredValues: alteredValues
        )
    }
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Drop Column
    
    func droppingColumn(_ columnName:String) -> AlterTable {
        guard let columnIndex = self.alteredTable.indexOfColumn(columnName) else {
            // a previous alteration already modified the column
            fatalError("Unable to drop column: '\(columnName)' column not found.")
        }

        let alteredTable = self.alteredTable.droppingColumn(columnName)
        var alteredValues = self.alteredValues
        alteredValues.remove(at: columnIndex)
        
        return AlterTable(
            alteredTable: alteredTable,
            alteredValues: alteredValues
        )
    }
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Add Constraint
    
    func addingConstraint(_ clause:String, named name:String?) -> AlterTable {
        return AlterTable(
            alteredTable:   alteredTable.addingConstraint(clause, named:name),
            alteredValues:  alteredValues
        )
    }
    
    func droppingConstraintNamed(_ name:String) -> AlterTable {
        return AlterTable(
            alteredTable:   alteredTable.droppingConstraintNamed(name),
            alteredValues:  alteredValues
        )
    }
    
    func droppingConstraint(_ clause:String) -> AlterTable {
        return AlterTable(
            alteredTable:   alteredTable.droppingConstraint(clause),
            alteredValues:  alteredValues
        )
    }
    
    func droppingAllConstraints() -> AlterTable {
        return AlterTable(
            alteredTable:   alteredTable.droppingAllConstraints(),
            alteredValues:  alteredValues
        )
    }
}

public final class ForeignKeyViolation {
    
    let fromTable:String
    let fromRowId:Int
    let toTable:String
    let foreignKeyIndex:Int
    
    init(row:Statement) {
        fromTable       = row.stringValueAtIndex(0) ?? ""
        fromRowId       = row.intValueAtIndex(0)    ?? 0
        toTable         = row.stringValueAtIndex(0) ?? ""
        foreignKeyIndex = row.intValueAtIndex(0)    ?? 0
    }
    
}

protocol TableTransformer : Transformer {
    
    var alteredTable:Table { get }
    
}
