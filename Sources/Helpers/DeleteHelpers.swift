import Foundation

public extension Database {
    
    /// Prepares a DELETE statement for the given table with an optional WHERE clause.
    ///
    /// - Parameters:
    ///   - tableName: The name of the table to delete rows from.
    ///   - whereExpr: A SQL expression string (the part following `WHERE`).
    /// - Returns: A prepared DELETE Statement.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func prepareDeleteFrom(_ tableName:   String,
                                  whereExpr:   String? = nil) throws -> Statement {
        
        var fragments = ["DELETE FROM", escapeIdentifier(tableName)]
        if whereExpr != nil {
            fragments.append("WHERE")
            fragments.append(whereExpr!)
        }

        return try prepareStatement(fragments.joined(separator: " "))
    }

    /// Deletes rows from the named table that match the given expression. This is a helper for executing an
    /// `DELETE FROM ... WHERE statement`.
    ///
    /// - Parameters:
    ///   - tableName: The table to delete rows from.
    ///   - whereExpr: An expression that selects rows to delete. If nil, all rows are deleted.
    ///   - parameters: Parameters to bind to the where expression.
    /// - Returns: The number of rows removed.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    @discardableResult
    public func deleteFrom(_ tableName:   String,
                           whereExpr:   String? = nil,
                           parameters:  [Bindable?] = []) throws -> Int {
            
        let statement = try prepareDeleteFrom(tableName, whereExpr: whereExpr)
        try statement.bind(parameters)
        try statement.execute()
                            
        return self.numberOfChangedRows
    }
    
    /// Deletes table rows with the given IDs.
    ///
    /// - Parameters:
    ///   - tableName: The table name.
    ///   - rowIds: The IDs of rows to delete.
    /// - Returns: The number of rows removed.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    @discardableResult
    public func deleteFrom(_ tableName: String,
                           rowIds:    [RowId]) throws -> Int {
        if rowIds.count == 0 {
            return 0
        }
        
        let whereExpr = "_ROWID_ IN (" + rowIds.map { String($0) }.joined(separator: ",") + ")"
        return try deleteFrom(tableName, whereExpr: whereExpr)
    }
    
}
