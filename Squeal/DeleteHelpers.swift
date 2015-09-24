import Foundation

public extension Database {
    
    public func prepareDeleteFrom(tableName:   String,
                                  whereExpr:   String? = nil) throws -> Statement {
        
        var fragments = ["DELETE FROM", escapeIdentifier(tableName)]
        if whereExpr != nil {
            fragments.append("WHERE")
            fragments.append(whereExpr!)
        }

        return try prepareStatement(fragments.joinWithSeparator(" "))
    }

    /// Deletes table rows. This is a helper for executing an DELETE FROM ... WHERE statement.
    ///
    /// :param: tableName   The name of the table to update.
    /// :param: whereExpr   A WHERE clause to select which rows to update. If nil, all rows are deleted.
    /// :param: parameters  Parameters to the WHERE clause.
    ///
    /// :returns:   The number of rows removed.
    ///
    public func deleteFrom(tableName:   String,
                           whereExpr:   String? = nil,
                           parameters:  [Bindable?] = []) throws -> Int {
            
        let statement = try prepareDeleteFrom(tableName, whereExpr: whereExpr)
        try statement.bind(parameters)
        try statement.execute()
                            
        return self.numberOfChangedRows
    }
    
    /// Deletes table rows identified by their IDs.
    ///
    /// :param: tableName   The name of the table to update.
    /// :param: rowIds      The IDs of the rows to delete.
    ///
    /// :returns:   The number of rows removed.
    ///
    public func deleteFrom(tableName: String,
                           rowIds:    [RowId]) throws -> Int {
        if rowIds.count == 0 {
            return 0
        }
        
        let parameters : [Bindable?] = rowIds.map { (rowId:RowId) -> Bindable? in rowId }
        
        let whereExpr = "_ROWID_ IN (" + rowIds.map { _ -> String in "?" }.joinWithSeparator(",") + ")"
        return try deleteFrom(tableName, whereExpr: whereExpr, parameters: parameters)
    }
}