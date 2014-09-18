import Foundation

extension Database {
    
    public func prepareDeleteFrom(tableName:   String,
                                  whereExpr:   String? = nil,
                                  error:       NSErrorPointer) -> Statement? {
        
        var fragments = ["DELETE FROM", escapeIdentifier(tableName)]
        if whereExpr != nil {
            fragments.append("WHERE")
            fragments.append(whereExpr!)
        }

        return prepareStatement(join(" ", fragments), error: error)
    }

    /// Deletes table rows. This is a helper for executing an DELETE FROM ... WHERE statement.
    ///
    /// :param: tableName   The name of the table to update.
    /// :param: whereExpr   A WHERE clause to select which rows to update. If nil, all rows are deleted.
    /// :param: parameters  Parameters to the WHERE clause.
    /// :param: error       An error pointer.
    ///
    /// :returns:   The number of rows removed, or nil if an error occurs.
    ///
    public func deleteFrom(tableName:   String,
                           whereExpr:   String? = nil,
                           parameters:  [Bindable?] = [],
                           error:       NSErrorPointer) -> Int? {
            
        var numberOfChangedRows : Int?
        if let statement = prepareDeleteFrom(tableName, whereExpr: whereExpr, error: error) {
            if statement.bind(parameters, error: error) {
                if statement.execute(error) {
                    numberOfChangedRows = self.numberOfChangedRows
                }
            }
            statement.close()
        }
        return numberOfChangedRows
    }
}