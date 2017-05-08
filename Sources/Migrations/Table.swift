import Foundation

/// Describes a table at a particular version of a database schema.
public final class Table : TableIndexSet {
    
    /// The table's name.
    public let name:String
    
    /// Columns of the database.
    public let columns:[Column]
    
    /// Constraints defined on the table.
    public let constraints:[TableConstraint]
    
    /// Any indexes defined on the table.
    public let indexes:[TableIndex]
    
    init(name:String, columns:[Column], constraints:[TableConstraint], indexes:[TableIndex]) {
        for index in indexes {
            // validate index refers to this table
            precondition(
                index.tableName == name,
                "index '\(index.name)' table name (\(index.tableName)) doesn't match table (\(name))"
            )
            
            // validate all columns exist
            let unknownColumns = index.columns.filter { columnName in
                !columns.contains { $0.name == columnName }
            }
            precondition(
                unknownColumns.isEmpty,
                "index '\(index.name)' on '\(index.tableName)' references unknown columns: \(unknownColumns)"
            )
        }
        
        self.name = name
        self.columns = columns
        self.constraints = constraints
        self.indexes = indexes
    }
    
    var definitions:[String] {
        return columns.map { $0.definition } + constraints.map { $0.definition }
    }
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Columns
    
    /// The names of all columns in the table.
    public var columnNames:[String] {
        return columns.map { $0.name }
    }
    
    var escapedColumnNames:[String] {
        return columns.map { escapeIdentifier($0.name) }
    }
    
    var columnDefinitions:[String] {
        return columns.map { $0.definition }
    }
    
    /// Gets a column in the table by its name.
    ///
    /// - Parameter name: The name of the column to return.
    /// - Returns: The column, or `nil` if not found.
    public func columnNamed(_ name:String) -> Column? {
        for column in columns {
            if column.name == name {
                return column
            }
        }
        
        return nil
    }
    
    /// Gets a column in the table by its name.
    ///
    /// - Parameter name: The name of the column to return.
    /// - Returns: The column, or `nil` if not found.
    public subscript(columnName:String) -> Column? {
        return columnNamed(columnName)
    }
    
    func indexOfColumn(_ columnName:String) -> Int? {
        return columns.index { $0.name == columnName }
    }
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Add Column
    
    func addingColumn(_ column:Column) -> Table {
        guard columnNamed(column.name) == nil else {
            fatalError("Unable to add '\(column.name)' column to '\(name)': column already exists.")
        }
        
        return Table(
            name:        name,
            columns:     columns + [column],
            constraints: constraints,
            indexes:     indexes
        )
    }
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Alter Column
    
    func alteringColumn(_ columnName:String, renameTo newName:String?, changeTypeTo newType:ColumnType?, setConstraints constraints:[String]?) -> Table {
        guard let columnIndex = indexOfColumn(columnName) else {
            fatalError("Unable to alter column: '\(columnName)' column doesn't exist.")
        }
        
        // update the column
        let originalColumn = columns[columnIndex]
        var alteredColumns = columns
        alteredColumns[columnIndex] = Column(
            name:        newName     ?? originalColumn.name,
            type:        newType     ?? originalColumn.type,
            constraints: constraints ?? originalColumn.constraints
        )
        
        // update indexes if the column was renamed
        let alteredIndexes:[TableIndex]
        if let newName = newName {
            alteredIndexes = indexes.map {
                $0.renamingColumn(originalColumn.name, to:newName)
            }
        } else {
            alteredIndexes = indexes
        }
        
        return Table(
            name:        name,
            columns:     alteredColumns,
            constraints: self.constraints,
            indexes:     alteredIndexes
        )
    }
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Drop Column

    func droppingColumn(_ columnName:String) -> Table {
        guard let columnIndex = indexOfColumn(columnName) else {
            // a previous alteration already modified the column
            fatalError("Unable to alter column: '\(columnName)' column has already been renamed or dropped.")
        }

        var alteredColumns = columns
        alteredColumns.remove(at: columnIndex)
        
        let alteredIndexes = indexes.filter { !$0.columns.contains(columnName) }
        return Table(
            name: self.name,
            columns: alteredColumns,
            constraints: constraints,
            indexes: alteredIndexes
        )
    }
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Indexes
    
    func addingIndex(_ indexName:String, columns indexColumns:[String], partialExpr:String? = nil, unique:Bool = false) -> Table {
        guard indexNamed(name) == nil else {
            fatalError("Unable to create index: '\(indexName)' already exists")
        }
        
        let index = TableIndex(
            name:           indexName,
            tableName:      name,
            columns:        indexColumns,
            partialExpr:    partialExpr,
            unique:         unique
        )
        
        return Table(
            name:        name,
            columns:     columns,
            constraints: constraints,
            indexes:     indexes + [ index ]
        )
    }
    
    func renamingIndex(_ indexName:String, to:String) -> Table {
        guard !containsIndexNamed(to) else {
            fatalError("Unable to rename index: '\(to)' already exists.")
        }
        
        guard let indexOfIndex = self.indexOfIndex(indexName) else {
            fatalError("Unable to rename '\(indexName)' index: index doesn't exist.")
        }
        
        var updatedIndexes = indexes
        updatedIndexes[indexOfIndex] = indexes[indexOfIndex].renamedTo(to)
        
        return Table(
            name:        name,
            columns:     columns,
            constraints: constraints,
            indexes:     updatedIndexes
        )
    }
    
    func droppingIndex(_ indexName:String) -> Table {
        guard let _ = indexNamed(indexName) else {
            fatalError("Unable to drop index: \'\(indexName)\' doesn't exist on '\(name)'")
        }

        return Table(
            name:        name,
            columns:     columns,
            constraints: constraints,
            indexes:     indexes.filter { $0.name != indexName }
        )
    }
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Constraints

    func indexOfConstraintNamed(_ constraintName:String) -> Int? {
        return constraints.index(where: { $0.name == constraintName })
    }

    func indexOfConstraintWithClause(_ clause:String) -> Int? {
        return constraints.index(where: { $0.clause == clause })
    }
    
    // ----- Add -----------------------------------------------------------------------------------
    
    func addingConstraint(_ clause:String, named constraintName:String?) -> Table {
        if let constraintName = constraintName {
            guard indexOfConstraintNamed(constraintName) == nil else {
                fatalError("Unable to add constraint to '\(name)': '\(constraintName)' constraint already exists.")
            }
        }
        
        let constraint = TableConstraint(name: constraintName, clause: clause)
        return Table(
            name:        name,
            columns:     columns,
            constraints: constraints + [constraint],
            indexes:     indexes
        )
    }
    
    // ----- Drop ----------------------------------------------------------------------------------
    
    func droppingConstraintNamed(_ constraintName:String) -> Table {
        guard let index = indexOfConstraintNamed(constraintName) else {
            fatalError("Unable to drop constraint from '\(self.name)': '\(constraintName)' constraint not found.")
        }
        
        return droppingConstraintAtIndex(index)
    }
    
    func droppingConstraint(_ clause:String) -> Table {
        guard let index = indexOfConstraintWithClause(clause) else {
            fatalError("Unable to drop constraint from '\(self.name)': '\(clause)' constraint not found.")
        }
        
        return droppingConstraintAtIndex(index)
    }
    
    fileprivate func droppingConstraintAtIndex(_ index:Int) -> Table {
        var remainingConstraints = self.constraints
        remainingConstraints.remove(at: index)
        
        return Table(
            name:        name,
            columns:     columns,
            constraints: remainingConstraints,
            indexes:     indexes
        )
    }
    
    func droppingAllConstraints() -> Table {
        return Table(
            name:        name,
            columns:     columns,
            constraints: [],
            indexes:     indexes
        )
    }
    
}

// =================================================================================================
// MARK:- TableSet

public protocol TableSet {
    
    var tables:[Table] { get }
    
}

public extension TableSet {
    
    
    /// Returns the index of a table given its name.
    ///
    /// - Parameter name: The name of the table whose index will be returned.
    /// - Returns: The table's index, or `nil` if not found.
    public func indexOfTable(_ name:String) -> Int? {
        return tables.index(where: { $0.name == name })
    }
    
    /// The names of all tables
    public var tableNames:[String] {
        return tables.map { $0.name }
    }
    
    /// Finds a `Table` based on its name.
    ///
    /// - Parameter name: The name of the table to find.
    /// - Returns: The `Table`, or `nil` if not found.
    public func tableNamed(_ name:String) -> Table? {
        guard let index = tables.index(where: { $0.name == name }) else {
            return nil
        }
        
        return tables[index]
    }
    
    /// Whether a table with the given name exists.
    ///
    /// - Parameter name: A table name.
    /// - Returns: `true` if found, otherwise `false.
    public func containsTableNamed(_ name:String) -> Bool {
        return tableNamed(name) != nil
    }
    
}

