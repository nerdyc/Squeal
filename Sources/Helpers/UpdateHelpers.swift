import Foundation

public extension Database {
    
    /// Prepares an `UPDATE` statement.
    ///
    /// - Parameters:
    ///   - tableName: The table to update.
    ///   - setClause: A SQL expression to update rows (e.g. what follows the `SET` keyword)
    ///   - whereClause: A SQL `WHERE` expression that selects which rows are updated (e.g. what follows the `WHERE` keyword)
    ///   - parameters: Parameters to bind to the statement.
    /// - Returns: The prepared `Statement`.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func prepareUpdate(_ tableName: String, set setClause:String, where whereClause:String? = nil, parameters: [Bindable?] = []) throws -> Statement {
        var fragments = ["UPDATE", escapeIdentifier(tableName), "SET", setClause]
        
        if let whereClause = whereClause {
            fragments.append("WHERE")
            fragments.append(whereClause)
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
    ///   - setClause: A SQL expression to update rows (e.g. what follows the `SET` keyword)
    ///   - whereClause: A SQL `WHERE` expression that selects which rows are updated (e.g. what follows the `WHERE` keyword)
    ///   - parameters: Parameters to bind to the statement.
    /// - Returns: The number of rows updated.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    @discardableResult
    public func update(_ tableName: String, set setClause:String, where whereClause:String? = nil, parameters: [Bindable?] = []) throws -> Int {
        let statement = try prepareUpdate(tableName,
                                          set:setClause,
                                          where:whereClause,
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
    ///   - whereClause: A SQL expression to select which rows to update. If `nil`, all rows are updated.
    /// - Returns: The prepared UPDATE statement.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func prepareUpdate(_ tableName:   String,
                              setColumns columns:     [String],
                              where whereClause:   String? = nil) throws -> Statement {
        
        let setClause = columns.map { escapeIdentifier($0) + " = ?" }.joined(separator: ", ")
        return try prepareUpdate(tableName, set:setClause, where:whereClause)
    }
    
    /// Updates table rows with the given values. This is a helper for executing an
    /// `UPDATE ... SET ... WHERE` statement when all updated values are provided.
    ///
    /// - Parameters:
    ///   - tableName: The name of the table to update.
    ///   - columns: The columns to update.
    ///   - values: The column values.
    ///   - whereClause: A WHERE clause to select which rows to update. If nil, all rows are updated.
    ///   - parameters: Parameters to the WHERE clause.
    /// - Returns: The number of rows updated.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    @discardableResult
    public func update(_ tableName:         String,
                       set columns:         [String],
                       to values:           [Bindable?],
                       where whereClause:   String? = nil,
                       parameters:          [Bindable?] = []) throws -> Int {
        
        let statement = try prepareUpdate(tableName, setColumns: columns, where: whereClause)
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
    ///   - whereClause: A WHERE clause to select which rows to update. If nil, all rows are updated.
    ///   - parameters: Parameters to the WHERE clause.
    /// - Returns: The number of rows updated.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    @discardableResult
    public func update(_ tableName:      String,
                       set:              [String:Bindable?],
                       where whereClause:String? = nil,
                       parameters:       [Bindable?] = []) throws -> Int {
        
        var columns = [String]()
        var values = [Bindable?]()
        for (columnName, value) in set {
            columns.append(columnName)
            values.append(value)
        }
        
        return try update(tableName, set:columns, to:values, where:whereClause, parameters:parameters)
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
        
        let whereClause = "_ROWID_ IN (" + rowIds.map { String($0) }.joined(separator: ",") + ")"
        return try update(tableName, set:values, where:whereClause)
    }
    
}


// =====================================================================================================================
// MARK:- Deprecated Methods
//
// These method signatures pre-date Swift 3 and have been replaced with signatures that match Swift-3 guidelines.

@available(*, deprecated: 2.0)
public extension Database {

    public func prepareUpdate(_ tableName: String, setExpr setClause:String, whereExpr whereClause:String? = nil, parameters: [Bindable?] = []) throws -> Statement {

        return try self.prepareUpdate(tableName, set: setClause, where: whereClause, parameters: parameters)
        
    }
    
    @discardableResult
    public func update(_ tableName: String, setExpr setClause:String, whereExpr whereClause:String? = nil, parameters: [Bindable?] = []) throws -> Int {

        return try self.update(tableName, set:setClause, where:whereClause, parameters:parameters)
        
    }
    
    public func prepareUpdate(_ tableName:   String,
                              columns:     [String],
                              whereExpr whereClause:   String? = nil) throws -> Statement {

        return try self.prepareUpdate(tableName, setColumns:columns, where:whereClause)
    }
    
    @discardableResult
    public func update(_ tableName:   String,
                       columns:     [String],
                       values:      [Bindable?],
                       whereExpr whereClause:   String? = nil,
                       parameters:  [Bindable?] = []) throws -> Int {
        return try self.update(tableName, set:columns, to:values, where:whereClause, parameters:parameters)
    }
    
    @discardableResult
    public func update(_ tableName:   String,
                       set:         [String:Bindable?],
                       whereExpr whereClause:   String? = nil,
                       parameters:  [Bindable?] = []) throws -> Int {
        
        return try self.update(tableName, set:set, where:whereClause, parameters:parameters)
        
    }
    

}
