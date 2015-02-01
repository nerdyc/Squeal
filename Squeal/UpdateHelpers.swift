import Foundation

public extension Database {
    
    public func prepareUpdate(tableName:   String,
                              columns:     [String],
                              whereExpr:   String? = nil,
                              error:       NSErrorPointer = nil) -> Statement? {
        
        let columnsToSet = join(", ", columns.map { escapeIdentifier($0) + " = ?" })
        var fragments = ["UPDATE", escapeIdentifier(tableName), "SET", columnsToSet]
                                
        if whereExpr != nil {
            fragments.append("WHERE")
            fragments.append(whereExpr!)
        }

        return prepareStatement(join(" ", fragments), error: error)
    }
    
    /// Updates table rows. This is a helper for executing an UPDATE ... SET ... WHERE statement.
    ///
    /// :param: tableName   The name of the table to update.
    /// :param: columns     The columns to update.
    /// :param: values      The updated values. These values must be in the same order as the columns.
    /// :param: whereExpr   A WHERE clause to select which rows to update. If nil, all rows are updated.
    /// :param: parameters  Parameters to the WHERE clause.
    /// :param: error       An error pointer.
    ///
    /// :returns:   The number of rows updated, or nil if an error occurs.
    ///
    public func update(tableName:   String,
                       columns:     [String],
                       values:      [Bindable?],
                       whereExpr:   String? = nil,
                       parameters:  [Bindable?] = [],
                       error:       NSErrorPointer = nil) -> Int? {
        
        var numberOfChangedRows : Int?
        if let statement = prepareUpdate(tableName, columns: columns, whereExpr: whereExpr, error: error) {
            if statement.bind(values + parameters, error: error) {
                if statement.execute(error: error) {
                    numberOfChangedRows = self.numberOfChangedRows
                }
            }
        }
        return numberOfChangedRows
    }
    
    /// Updates table rows. This is a helper for executing an UPDATE ... SET ... WHERE statement.
    ///
    /// :param: tableName   The name of the table to update.
    /// :param: set         The updated values, keyed by column names.
    /// :param: whereExpr   A WHERE clause to select which rows to update. If nil, all rows are updated.
    /// :param: parameters  Parameters to the WHERE clause.
    /// :param: error       An error pointer.
    ///
    /// :returns:   The number of rows updated, or nil if an error occurs.
    ///
    public func update(tableName:   String,
                       set:         [String:Bindable?],
                       whereExpr:   String? = nil,
                       parameters:  [Bindable?] = [],
                       error:       NSErrorPointer = nil) -> Int? {
        
        var columns = [String]()
        var values = [Bindable?]()
        for (columnName, value) in set {
            columns.append(columnName)
            values.append(value)
        }
        
        return update(tableName, columns:columns, values:values, whereExpr:whereExpr, parameters:parameters, error:error)
    }
    
    /// Updates table rows given a set of row IDs.
    ///
    /// :param: tableName   The name of the table to update.
    /// :param: rowIds      The IDs of the rows to update.
    /// :param: values      The updated values. These values must be in the same order as the columns.
    /// :param: error       An error pointer.
    ///
    /// :returns:   The number of rows updated, or nil if an error occurs.
    ///
    public func update(tableName: String,
                       rowIds:    [RowId],
                       values:    [String:Bindable?],
                       error:     NSErrorPointer = nil) -> Int? {
        if rowIds.count == 0 {
            return 0
        }
        
        let parameters : [Bindable?] = rowIds.map { (rowId:RowId) -> Bindable? in rowId }
        
        let whereExpr = "_ROWID_ IN (" + join(",", rowIds.map { _ -> String in "?" }) + ")"
        return update(tableName, set:values, whereExpr:whereExpr, parameters:parameters, error:error)
    }
    
}