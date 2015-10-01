import Foundation

public extension Database {
    
    public func prepareUpdate(tableName: String, setExpr:String, whereExpr:String? = nil, parameters: [Bindable?] = []) throws -> Statement {
        var fragments = ["UPDATE", escapeIdentifier(tableName), "SET", setExpr]
        
        if whereExpr != nil {
            fragments.append("WHERE")
            fragments.append(whereExpr!)
        }
        
        let statement = try prepareStatement(fragments.joinWithSeparator(" "))
        if parameters.count > 0 {
            try statement.bind(parameters)
        }
        return statement
    }

    /// Updates table rows using a dynamic SQL expression. This is useful when you would like to use
    /// SQL functions or operators to update the values of particular rows.
    ///
    /// :param: tableName   The name of the table to update.
    /// :param: setExpr     The SQL expression used to calculate the updated values.
    /// :param: whereExpr   A WHERE clause to select which rows to update. If nil, all rows are updated.
    /// :param: parameters  Parameters to the SET and WHERE clauses.
    ///
    /// :returns:   The number of rows updated.
    ///
    public func update(tableName: String, setExpr:String, whereExpr:String? = nil, parameters: [Bindable?] = []) throws -> Int {
        let statement = try prepareUpdate(tableName,
                                          setExpr:setExpr,
                                          whereExpr:whereExpr,
                                          parameters:parameters)
        try statement.execute()
        
        return self.numberOfChangedRows
    }
    
    public func prepareUpdate(tableName:   String,
                              columns:     [String],
                              whereExpr:   String? = nil) throws -> Statement {
        
        let columnsToSet = columns.map { escapeIdentifier($0) + " = ?" }.joinWithSeparator(", ")
        return try prepareUpdate(tableName, setExpr:columnsToSet, whereExpr:whereExpr)
    }
    
    /// Updates table rows with the given values. This is a helper for executing an
    /// `UPDATE ... SET ... WHERE` statement when all updated values are provided.
    ///
    /// :param: tableName   The name of the table to update.
    /// :param: columns     The columns to update.
    /// :param: values      The updated values. These values must be in the same order as the columns.
    /// :param: whereExpr   A WHERE clause to select which rows to update. If nil, all rows are updated.
    /// :param: parameters  Parameters to the WHERE clause.
    ///
    /// :returns:   The number of rows updated.
    ///
    public func update(tableName:   String,
                       columns:     [String],
                       values:      [Bindable?],
                       whereExpr:   String? = nil,
                       parameters:  [Bindable?] = []) throws -> Int {
        
        let statement = try prepareUpdate(tableName, columns: columns, whereExpr: whereExpr)
        try statement.bind(values + parameters)
        try statement.execute()
        
        return self.numberOfChangedRows
    }
    
    /// Updates table rows with the given values. This is a helper for executing an
    /// `UPDATE ... SET ... WHERE` statement when all updated values are provided.
    ///
    /// :param: tableName   The name of the table to update.
    /// :param: set         The updated values, keyed by column names.
    /// :param: whereExpr   A WHERE clause to select which rows to update. If nil, all rows are updated.
    /// :param: parameters  Parameters to the WHERE clause.
    ///
    /// :returns:   The number of rows updated.
    ///
    public func update(tableName:   String,
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
    /// :param: tableName   The name of the table to update.
    /// :param: rowIds      The IDs of the rows to update.
    /// :param: values      The updated values. These values must be in the same order as the columns.
    ///
    /// :returns:   The number of rows updated.
    ///
    public func update(tableName: String,
                       rowIds:    [RowId],
                       values:    [String:Bindable?]) throws -> Int {
        if rowIds.count == 0 {
            return 0
        }
        
        let parameters : [Bindable?] = rowIds.map { (rowId:RowId) -> Bindable? in rowId }
        
        let whereExpr = "_ROWID_ IN (" + rowIds.map { _ -> String in "?" }.joinWithSeparator(",") + ")"
        return try update(tableName, set:values, whereExpr:whereExpr, parameters:parameters)
    }
    
}