import Foundation

public extension Database {
    
    /// Prepares an `UPDATE` statement.
    ///
    /// - Parameters:
    ///   - tableName: The table to update.
    ///   - setExpr: A SQL expression to update rows (e.g. what follows the `SET` keyword)
    ///   - whereExpr: A SQL `WHERE` expression that selects which rows are updated (e.g. what follows the `WHERE` keyword)
    ///   - parameters: Parameters to bind to the statement.
    /// - Returns: The prepared `Statement`.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func prepareUpdate(_ tableName: String, setExpr:String, whereExpr:String? = nil, parameters: [Bindable?] = []) throws -> Statement {
        var fragments = ["UPDATE", escapeIdentifier(tableName), "SET", setExpr]
        
        if whereExpr != nil {
            fragments.append("WHERE")
            fragments.append(whereExpr!)
        }
        
        let statement = try prepareStatement(fragments.joined(separator: " "))
        if parameters.count > 0 {
            try statement.bind(parameters)
        }
        return statement
    }

    /// Updates table rows using a dynamic SQL expression. This is useful when you would like to use SQL functions or
    /// operators to update the values of particular rows.
    ///
    /// - Parameters:
    ///   - tableName: The table to update.
    ///   - setExpr: A SQL expression to update rows (e.g. what follows the `SET` keyword)
    ///   - whereExpr: A SQL `WHERE` expression that selects which rows are updated (e.g. what follows the `WHERE` keyword)
    ///   - parameters: Parameters to bind to the statement.
    /// - Returns: The number of rows updated.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    @discardableResult
    public func update(_ tableName: String, setExpr:String, whereExpr:String? = nil, parameters: [Bindable?] = []) throws -> Int {
        let statement = try prepareUpdate(tableName,
                                          setExpr:setExpr,
                                          whereExpr:whereExpr,
                                          parameters:parameters)
        try statement.execute()
        
        return self.numberOfChangedRows
    }
    
    /// Prepares an `UPDATE` statement to update the given columns to specific values. The returned `Statement` will
    /// have one parameter for each column, in the same order.
    ///
    /// - Parameters:
    ///   - tableName: The name of the table to update.
    ///   - columns: The columns to update.
    ///   - whereExpr: A SQL expression to select which rows to update. If `nil`, all rows are updated.
    /// - Returns: The prepared UPDATE statement.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func prepareUpdate(_ tableName:   String,
                              columns:     [String],
                              whereExpr:   String? = nil) throws -> Statement {
        
        let columnsToSet = columns.map { escapeIdentifier($0) + " = ?" }.joined(separator: ", ")
        return try prepareUpdate(tableName, setExpr:columnsToSet, whereExpr:whereExpr)
    }
    
    /// Updates table rows with the given values. This is a helper for executing an
    /// `UPDATE ... SET ... WHERE` statement when all updated values are provided.
    ///
    /// - Parameters:
    ///   - tableName: The name of the table to update.
    ///   - columns: The columns to update.
    ///   - values: The column values.
    ///   - whereExpr: A WHERE clause to select which rows to update. If nil, all rows are updated.
    ///   - parameters: Parameters to the WHERE clause.
    /// - Returns: The number of rows updated.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    @discardableResult
    public func update(_ tableName:   String,
                       columns:     [String],
                       values:      [Bindable?],
                       whereExpr:   String? = nil,
                       parameters:  [Bindable?] = []) throws -> Int {
        
        let statement = try prepareUpdate(tableName, columns: columns, whereExpr: whereExpr)
        try statement.bind(values + parameters)
        try statement.execute()
        
        return self.numberOfChangedRows
    }
    
    /// Updates table rows with the given values. This is a helper for executing an `UPDATE ... SET ... WHERE` statement
    /// when all updated values are provided.
    ///
    /// - Parameters:
    ///   - tableName: The name of the table to update.
    ///   - set: A dictionary of column names and values to set.
    ///   - whereExpr: A WHERE clause to select which rows to update. If nil, all rows are updated.
    ///   - parameters: Parameters to the WHERE clause.
    /// - Returns: The number of rows updated.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    @discardableResult
    public func update(_ tableName:   String,
                       set:         [String:Bindable?],
                       whereExpr:   String? = nil,
                       parameters:  [Bindable?] = []) throws -> Int {
        
        var columns = [String]()
        var values = [Bindable?]()
        for (columnName, value) in set {
            columns.append(columnName)
            values.append(value)
        }
        
        return try update(tableName, columns:columns, values:values, whereExpr:whereExpr, parameters:parameters)
    }
    
    /// Updates table rows given a set of row IDs.
    ///
    /// - Parameters:
    ///   - tableName: The name of the table to update.
    ///   - rowIds: The IDs of rows to update.
    ///   - values: A dictionary of column names and values to set on the rows.
    /// - Returns: The number of rows updated.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    @discardableResult
    public func update(_ tableName: String,
                       rowIds:    [RowId],
                       values:    [String:Bindable?]) throws -> Int {
        if rowIds.count == 0 {
            return 0
        }
        
        let whereExpr = "_ROWID_ IN (" + rowIds.map { String($0) }.joined(separator: ",") + ")"
        return try update(tableName, set:values, whereExpr:whereExpr)
    }
    
}
