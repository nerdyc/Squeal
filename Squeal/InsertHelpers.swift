import Foundation

public extension Database {
    
    public func prepareInsertInto(tableName:String, columns:[String], error:NSErrorPointer = nil) -> Statement? {
        var sqlFragments = ["INSERT INTO"]
        sqlFragments.append(escapeIdentifier(tableName))
        sqlFragments.append("(")
        sqlFragments.append(join(", ", columns.map { escapeIdentifier($0) }))
        sqlFragments.append(")")
        sqlFragments.append("VALUES")
        sqlFragments.append("(")
        sqlFragments.append(join(",", columns.map { _ in "?" }))
        sqlFragments.append(")")
        
        return prepareStatement(join(" ", sqlFragments), error: error)
    }
    
    /// Inserts a table row. This is a helper for executing an INSERT INTO statement.
    ///
    /// :param: tableName   The name of the table to insert into.
    /// :param: columns     The column names of the values to insert.
    /// :param: values      The values to insert. The values in this array must be in the same order as the respective
    ///                     `columns`.
    /// :param: error       An error pointer.
    ///
    /// :returns:   The id of the inserted row. sqlite assigns each row a 64-bit ID, even if the primary key is not an
    ///             INTEGER value. `nil` is returned when an error occurs.
    ///
    public func insertInto(tableName:String, columns:[String], values:[Bindable?], error:NSErrorPointer = nil) -> Int64? {
        var rowId : Int64?
        if let statement = prepareInsertInto(tableName, columns:columns, error: error) {
            if statement.bind(values, error: error) {
                if statement.execute(error: error) {
                    rowId = lastInsertedRowId
                }
            }
        }
        return rowId
    }

    /// Inserts a table row. This is a helper for executing an INSERT INTO statement.
    ///
    /// :param: tableName   The name of the table to insert into.
    /// :param: values      The values to insert, keyed by the column name.
    /// :param: error       An error pointer.
    ///
    /// :returns:   The id of the inserted row. sqlite assigns each row a 64-bit ID, even if the primary key is not an
    ///             INTEGER value. `nil` is returned when an error occurs.
    ///
    public func insertInto(tableName:String, values valuesDictionary:[String:Bindable?], error:NSErrorPointer = nil) -> Int64? {
        var columns = [String]()
        var values = [Bindable?]()
        for (columnName, value) in valuesDictionary {
            columns.append(columnName)
            values.append(value)
        }
        
        return insertInto(tableName, columns:columns, values:values, error:error)
    }
    
}