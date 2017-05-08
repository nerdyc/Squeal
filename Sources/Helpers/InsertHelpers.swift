import Foundation

public extension Database {
    
    /// Prepares an `INSERT` Statement.
    ///
    /// - Parameters:
    ///   - tableName: The name of the table to insert into.
    ///   - columns: An array of column names.
    /// - Returns: The prepared INSERT statement.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func prepareInsertInto(_ tableName:String, columns:[String]) throws -> Statement {
        var sqlFragments = ["INSERT INTO"]
        sqlFragments.append(escapeIdentifier(tableName))
        sqlFragments.append("(")
        sqlFragments.append(columns.map { escapeIdentifier($0) }.joined(separator: ", "))
        sqlFragments.append(")")
        sqlFragments.append("VALUES")
        sqlFragments.append("(")
        sqlFragments.append(columns.map { _ in "?" }.joined(separator: ","))
        sqlFragments.append(")")
        
        return try prepareStatement(sqlFragments.joined(separator: " "))
    }
    
    /// Inserts a new row using an array of column names, and an array of values. Both arrays should have the same size.
    ///
    /// - Parameters:
    ///   - tableName: A table name.
    ///   - columns: An array of column names.
    ///   - values: Values to insert into the row. The size of this array must match `columns`.
    /// - Returns: The ID of the inserted row.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    @discardableResult
    public func insertInto(_ tableName:String, columns:[String], values:[Bindable?]) throws -> Int64 {
        let statement = try prepareInsertInto(tableName, columns:columns)
        try statement.bind(values)
        try statement.execute()
        
        return lastInsertedRowId
    }

    /// Inserts a new row into the database, using a dictionary.
    ///
    /// - Parameters:
    ///   - tableName: A table name.
    ///   - valuesDictionary: A dictionary whose keys are column names, and values are the column values.
    /// - Returns: The ID of the inserted row.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    @discardableResult
    public func insertInto(_ tableName:String, values valuesDictionary:[String:Bindable?]) throws -> Int64 {
        var columns = [String]()
        var values = [Bindable?]()
        for (columnName, value) in valuesDictionary {
            columns.append(columnName)
            values.append(value)
        }
        
        return try insertInto(tableName, columns:columns, values:values)
    }
    
}
