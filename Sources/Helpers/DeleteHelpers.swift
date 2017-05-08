import Foundation

public extension Database {
    
    /// Prepares a DELETE statement for the given table with an optional WHERE clause.
    ///
    /// - Parameters:
    ///   - tableName: The name of the table to delete rows from.
    ///   - whereClause: A SQL expression string (the part following `WHERE`).
    /// - Returns: A prepared DELETE Statement.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func prepareDelete(from tableName:String,
                              where whereClause:String? = nil) throws -> Statement {
        
        var fragments = ["DELETE FROM", escapeIdentifier(tableName)]
        if let whereClause = whereClause {
            fragments.append("WHERE")
            fragments.append(whereClause)
        }

        return try prepareStatement(fragments.joined(separator: " "))
    }

    /// Deletes rows from the named table that match the given expression. This is a helper for executing an
    /// `DELETE FROM ... WHERE statement`.
    ///
    /// - Parameters:
    ///   - tableName: The table to delete rows from.
    ///   - whereClause: An expression that selects rows to delete. If nil, all rows are deleted.
    ///   - parameters: Parameters to bind to the where expression.
    /// - Returns: The number of rows removed.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    @discardableResult
    public func delete(from tableName:   String,
                       where whereClause:   String? = nil,
                       parameters:  [Bindable?] = []) throws -> Int {
            
        let statement = try prepareDelete(from:tableName, where: whereClause)
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
    public func delete(from tableName: String,
                       rowIds:[RowId]) throws -> Int {
        if rowIds.count == 0 {
            return 0
        }
        
        let whereClause = "_ROWID_ IN (" + rowIds.map { String($0) }.joined(separator: ",") + ")"
        return try delete(from:tableName, where: whereClause)
    }
    
}


// =====================================================================================================================
// MARK:- Deprecated Methods
//
// These method signatures pre-date Swift 3 and have been replaced with signatures that match Swift-3 guidelines.

@available(*, deprecated: 2.0)
public extension Database {
    
    @discardableResult
    public func prepareDeleteFrom(_ tableName:String,
                                  whereExpr whereClause:String? = nil) throws -> Statement {
        
        return try self.prepareDelete(from:tableName, where:whereClause)
    }
    
    @discardableResult
    public func deleteFrom(_ tableName: String,
                           whereExpr whereClause:   String? = nil,
                           parameters:  [Bindable?] = []) throws -> Int {
        return try self.delete(from:tableName, where:whereClause, parameters:parameters)
    }
    

    @discardableResult
    public func deleteFrom(_ tableName: String,
                           rowIds:    [RowId]) throws -> Int {
        return try self.delete(from:tableName, rowIds:rowIds)
        
    }
}
