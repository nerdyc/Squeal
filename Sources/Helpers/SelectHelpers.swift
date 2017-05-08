import Foundation

public extension Database {
    
    // ---------------------------------------------------------------------------------------------
    // MARK: SELECT
    
    /// Compiles a SELECT statement, optionally binding values. Use the `next` method to begin
    /// iterating results.
    ///
    /// - Parameters:
    ///   - from:       The name of the table to select from, including any JOIN clauses.
    ///   - columns:    The columns to select. These are not escaped, and can contain expressions. If nil, all
    ///                 columns are returned (e.g. '*').
    ///   - whereClause:  The WHERE clause. If nil, then all rows are returned.
    ///   - groupBy:    The GROUP BY expression.
    ///   - having:     The HAVING clause.
    ///   - orderBy:    The ORDER BY clause.
    ///   - limit:      The LIMIT.
    ///   - offset:     The OFFSET.
    ///   - parameters: An array of parameters to bind to the statement.
    /// - Returns: The prepared `SELECT` statement.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func prepareSelect(from:             String,
                              columns:          [String]? = nil,
                              where whereClause:String? = nil,
                              groupBy:          String? = nil,
                              having:           String? = nil,
                              orderBy:          String? = nil,
                              limit:            Int? = nil,
                              offset:           Int? = nil,
                              parameters:       [Bindable?] = []) throws -> Statement {
        
        var fragments = [ "SELECT" ]
        if let columns = columns {
            fragments.append(columns.joined(separator: ","))
        } else {
            fragments.append("*")
        }
        
        fragments.append("FROM")
        fragments.append(from)
                            
        if let whereClause = whereClause {
            fragments.append("WHERE")
            fragments.append(whereClause)
        }
        
        if let groupBy = groupBy {
            fragments.append("GROUP BY")
            fragments.append(groupBy)
        }
        
        if let having = having {
            fragments.append("HAVING")
            fragments.append(having)
        }
        
        if let orderBy = orderBy {
            fragments.append("ORDER BY")
            fragments.append(orderBy)
        }
        
        if let limit = limit {
            fragments.append("LIMIT")
            fragments.append("\(limit)")
            
            if let offset = offset {
                fragments.append("OFFSET")
                fragments.append("\(offset)")
            }
        }
        
        let statement = try prepareStatement(fragments.joined(separator: " "))
        if parameters.count > 0 {
            try statement.bind(parameters)
        }
        
        return statement
    }
    
    /// Prepares a `SELECT` statement that selects row IDs.
    ///
    /// - Parameters:
    ///   - from:       The name of the table to select from, including any JOIN clauses.
    ///   - whereClause:  The WHERE clause. If nil, then all rows are returned.
    ///   - groupBy:    The GROUP BY expression.
    ///   - having:     The HAVING clause.
    ///   - orderBy:    The ORDER BY clause.
    ///   - limit:      The LIMIT.
    ///   - offset:     The OFFSET.
    ///   - parameters: An array of parameters to bind to the statement.
    /// - Returns: The prepared `SELECT` statement.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func prepareSelectIds(from:              String,
                                 where whereClause: String? = nil,
                                 groupBy:           String? = nil,
                                 having:            String? = nil,
                                 orderBy:           String? = nil,
                                 limit:             Int? = nil,
                                 offset:            Int? = nil,
                                 parameters:        [Bindable?] = []) throws -> Statement {

        return try prepareSelect(from:       from,
                                 columns:    ["_ROWID_"],
                                 where:      whereClause,
                                 groupBy:    groupBy,
                                 having:     having,
                                 orderBy:    orderBy,
                                 limit:      limit,
                                 offset:     offset,
                                 parameters: parameters)
    }
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Count
    
    /// Counts rows in a table. This is a helper for executing a SELECT count(...) FROM statement
    /// and reading the result.
    ///
    /// - Parameters:
    ///   - from: The name of the table to select from, including any JOIN clauses.
    ///   - columns: The columns to count. If nil, then 'count(*)' is returned.
    ///   - whereClause: The WHERE clause. If nil, then all rows are returned.
    ///   - parameters: An array of parameters to bind to the statement.
    /// - Returns: The number of rows counted, or nil if an error occurs.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func count(from:             String,
                      columns:          [String]? = nil,
                      where whereClause:String? = nil,
                      parameters:  [    Bindable?] = []) throws -> Int64 {

        let countExpr = "count(" + (columns ?? ["*"]).joined(separator: ",") + ")"
        let statement = try prepareSelect(from: from,
                                          columns: [countExpr],
                                          where: whereClause,
                                          parameters: parameters)
                                    
        var count:Int64 = 0
        if try statement.next() {
            count = statement.int64ValueAtIndex(0) ?? 0
        }
        return count
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK: Query
    
    /// Executes the given SELECT statement and returns the first column of the first row as an Int.
    ///
    /// - Parameters:
    ///   - sqlString: A SQL `SELECT` statement.
    ///   - parameters: Any parameters to bind to the statement.
    /// - Returns: The selected Int value, or `nil` if no rows were selected.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func selectInt(_ sqlString:String, parameters:[Bindable?] = []) throws -> Int? {
        return try prepareStatement(sqlString, parameters:parameters).selectNextInt()
    }

    /// Executes the given SELECT statement and returns the first column of the first row as an Int64.
    ///
    /// - Parameters:
    ///   - sqlString: A SQL `SELECT` statement.
    ///   - parameters: Any parameters to bind to the statement.
    /// - Returns: The selected Int64 value, or `nil` if no rows were selected.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func selectInt64(_ sqlString:String, parameters:[Bindable?] = []) throws -> Int64? {
        return try prepareStatement(sqlString, parameters:parameters).selectNextInt64()
    }

    /// Executes the given SELECT statement and returns the first column of the first row as a Double.
    ///
    /// - Parameters:
    ///   - sqlString: A SQL `SELECT` statement.
    ///   - parameters: Any parameters to bind to the statement.
    /// - Returns: The selected Double value, or `nil` if no rows were selected.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func selectDouble(_ sqlString:String, parameters:[Bindable?] = []) throws -> Double? {
        return try prepareStatement(sqlString, parameters:parameters).selectNextDouble()
    }

    /// Executes the given SELECT statement and returns the first column of the first row as a String.
    ///
    /// - Parameters:
    ///   - sqlString: A SQL `SELECT` statement.
    ///   - parameters: Any parameters to bind to the statement.
    /// - Returns: The selected String value, or `nil` if no rows were selected.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func selectString(_ sqlString:String, parameters:[Bindable?] = []) throws -> String? {
        return try prepareStatement(sqlString, parameters:parameters).selectNextString()
    }

    /// Executes the given SELECT statement and returns the first column of the first row as a Bool.
    ///
    /// - Parameters:
    ///   - sqlString: A SQL `SELECT` statement.
    ///   - parameters: Any parameters to bind to the statement.
    /// - Returns: The selected Bool value, or `nil` if no rows were selected.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func selectBool(_ sqlString:String, parameters:[Bindable?] = []) throws -> Bool? {
        return try prepareStatement(sqlString, parameters:parameters).selectNextBool()
    }

    /// Executes the given SELECT statement and returns the first row, transformed by the given
    /// block. Returns nil if no rows matched.
    ///
    /// - Parameters:
    ///   - sqlString: A SQL `SELECT` statement.
    ///   - parameters: Any parameters to bind to the statement.
    ///   - block: A block to process the selected row.
    /// - Returns: The value returned by the block, or nil if no rows were selected.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func selectFirst<T>(_ sqlString:String, parameters:[Bindable?] = [], block: (Statement)->T) throws -> T? {
        return try prepareStatement(sqlString, parameters:parameters).selectNextRow(block)
    }
    
    /// Executes the given SELECT statement and returns all matching rows, transformed by the given block.
    ///
    /// - Parameters:
    ///   - sqlString: A SQL `SELECT` statement.
    ///   - parameters: Any parameters to bind to the statement.
    ///   - block: A block to process the selected rows.
    /// - Returns:
    ///     An array of all the selected values (as returned by the block), or an empty array if no rows were selected.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func selectAll<T>(_ sqlString:String, parameters:[Bindable?] = [], block: (Statement)->T) throws -> [T] {
        return try prepareStatement(sqlString, parameters:parameters).selectRows(block)
    }
    
    /// Executes a SELECT statement, and returns all matching rows, transformed by the given block.
    ///
    /// - Parameters:
    ///   - from:       The name of the table to select from, including any JOIN clauses.
    ///   - columns:    The columns to select. These are not escaped, and can contain expressions. If nil, all
    ///                 columns are returned (e.g. '*').
    ///   - whereClause:The WHERE clause. If nil, then all rows are returned.
    ///   - groupBy:    The GROUP BY expression.
    ///   - having:     The HAVING clause.
    ///   - orderBy:    The ORDER BY clause.
    ///   - limit:      The LIMIT.
    ///   - offset:     The OFFSET.
    ///   - parameters: An array of parameters to bind to the statement.
    ///   - block:      A block to process the selected rows.
    /// - Returns:
    ///     An array of all the selected values (as returned by the block), or an empty array if no rows were selected.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func select<T>(from:             String,
                          columns:          [String]? = nil,
                          where whereClause:String? = nil,
                          groupBy:          String? = nil,
                          having:           String? = nil,
                          orderBy:          String? = nil,
                          limit:            Int? = nil,
                          offset:           Int? = nil,
                          parameters:       [Bindable?] = [],
                          block:            ((Statement) throws -> T)) throws -> [T] {
                                
        let statement = try prepareSelect(from:from,
                                          columns:columns,
                                          where:whereClause,
                                          groupBy:groupBy,
                                          having:having,
                                          orderBy:orderBy,
                                          limit:limit,
                                          offset:offset,
                                          parameters:parameters)
        
        return try statement.select(block:block)
    }
    
    /// Prepares a `SELECT` statement that selects row IDs.
    ///
    /// - Parameters:
    ///   - from:       The name of the table to select from, including any JOIN clauses.
    ///   - whereClause:  The WHERE clause. If nil, then all rows are returned.
    ///   - groupBy:    The GROUP BY expression.
    ///   - having:     The HAVING clause.
    ///   - orderBy:    The ORDER BY clause.
    ///   - limit:      The LIMIT.
    ///   - offset:     The OFFSET.
    ///   - parameters: An array of parameters to bind to the statement.
    /// - Returns: The prepared `SELECT` statement.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func selectIds(from:       String,
                          where whereClause: String? = nil,
                          groupBy:      String? = nil,
                          having:       String? = nil,
                          orderBy:      String? = nil,
                          limit:        Int? = nil,
                          offset:       Int? = nil,
                          parameters:   [Bindable?] = []) throws -> [RowId] {

        return try select(from: from,
                          columns: ["ROWID"],
                          where: whereClause,
                          groupBy: groupBy,
                          having: having,
                          orderBy: orderBy,
                          limit: limit,
                          offset: offset,
                          parameters: parameters) { $0.int64ValueAtIndex(0) ?? 0 }
    }
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Iterate
    
    /// Performs a SELECT statement, using the block to iterate through each selected row.
    ///
    /// - Parameters:
    ///   - from:       The name of the table to select from, including any JOIN clauses.
    ///   - columns:    The columns to select. These are not escaped, and can contain expressions. If nil, all
    ///                 columns are returned (e.g. '*').
    ///   - whereClause:The WHERE clause. If nil, then all rows are returned.
    ///   - groupBy:    The GROUP BY expression.
    ///   - having:     The HAVING clause.
    ///   - orderBy:    The ORDER BY clause.
    ///   - limit:      The LIMIT.
    ///   - offset:     The OFFSET.
    ///   - parameters: An array of parameters to bind to the statement.
    ///   - block:      A block to process the selected rows.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    func iterateRows(from:        String,
                     columns:     [String]? = nil,
                     where whereClause:String? = nil,
                     groupBy:     String? = nil,
                     having:      String? = nil,
                     orderBy:     String? = nil,
                     limit:       Int? = nil,
                     offset:      Int? = nil,
                     parameters:  [Bindable?] = [],
                     block: ((Statement) throws -> Void)) throws {
        
        let statement = try prepareSelect(from:     from,
                                          columns:  columns,
                                          where:    whereClause,
                                          groupBy:  groupBy,
                                          having:   having,
                                          orderBy:  orderBy,
                                          limit:    limit,
                                          offset:   offset,
                                          parameters:   parameters)
        try statement.iterateRows(block)
    }
    
}

public extension Statement {
    
    /// Advances to the next row, and returns the result from the given block.
    ///
    /// - Parameter block: A block that processes the row.
    /// - Returns: The value returned by the block, or `nil` if the end of the result set was reached.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func selectNext<T>(_ block: ((Statement) throws -> T)) throws -> T? {
        guard try next() else {
            return nil
        }
        
        return try block(self)
    }
    
    /// Binds the given parameters, executes the statement, and returns all matching rows as processed by the block.
    ///
    /// - Parameters:
    ///   - parameters: Parameters to bind to the statement.
    ///   - block: A block to process each row.
    /// - Returns: The rows selected by the statement, as returned by the block.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func select<T>(_ parameters:[Bindable?]? = nil, block: ((Statement) throws -> T)) throws -> [T] {
        try reset()
        
        if let parametersToBind = parameters {
            clearParameters()
            try bind(parametersToBind)
        }
        
        var rows = [T]()
        while let row = try selectNext(block) {
            rows.append(row)
        }
        return rows
    }
    
    /// Iterates through query results, invoking the block for each row.
    ///
    /// - Parameter block: The block used to process each row.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    func iterateRows(_ block: ((Statement) throws -> Void)) throws {
        while try next() {
            try block(self)
        }
    }
    
    /// Alias for doubleValue(columnName)
    public func realValue(_ columnName:String) -> Double? {
        return doubleValue(columnName)
    }
    
    /// Alias for realValueAtIndex(columnIndex)
    public func realValueAtIndex(_ columnIndex:Int) -> Double? {
        return doubleValueAtIndex(columnIndex)
    }
    
    
    /// Advances to the next row and returns the Int value of the first column.
    ///
    /// - Returns: The Int value of the next row, or nil if there is no next row, or the value is NULL.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func selectNextInt() throws -> Int? {
        guard try next() else {
            return nil
        }
        
        return intValueAtIndex(0)
    }
    
    /// Advances to the next row and returns the Int64 value of the first column.
    ///
    /// - Returns: The Int64 value of the next row, or nil if there is no next row, or the value is NULL.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func selectNextInt64() throws -> Int64? {
        guard try next() else {
            return nil
        }
        
        return int64ValueAtIndex(0)
    }
    
    /// Advances to the next row and returns the Double value of the first column.
    ///
    /// - Returns: The Double value of the next row, or nil if there is no next row, or the value is NULL.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func selectNextDouble() throws -> Double? {
        guard try next() else {
            return nil
        }
        return doubleValueAtIndex(0)
    }
    
    /// Advances to the next row and returns the String value of the first column.
    ///
    /// - Returns: The String value of the next row, or nil if there is no next row, or the value is NULL.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func selectNextString() throws -> String? {
        guard try next() else {
            return nil
        }
        
        return stringValueAtIndex(0)
    }
    
    /// Advances to the next row and returns the Bool value of the first column.
    ///
    /// - Returns: The Bool value of the next row, or nil if there is no next row, or the value is NULL.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func selectNextBool() throws -> Bool? {
        guard try next() else {
            return nil
        }
        
        return boolValueAtIndex(0)
    }
    
    /// Advances to the next row and returns the BLOB value of the first column.
    ///
    /// - Returns: The BLOB value of the next row, or nil if there is no next row, or the value is NULL.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func selectNextBlob() throws -> Data? {
        guard try next() else {
            return nil
        }
        
        return blobValueAtIndex(0)
    }
}


// =====================================================================================================================
// MARK:- Deprecated Methods
//
// These method signatures pre-date Swift 3 and have been replaced with signatures that match Swift-3 guidelines.

@available(*, deprecated: 2.0)
public extension Database {

    public func prepareSelectFrom(_ from:        String,
                                  columns:     [String]? = nil,
                                  whereExpr whereClause:   String? = nil,
                                  groupBy:     String? = nil,
                                  having:      String? = nil,
                                  orderBy:     String? = nil,
                                  limit:       Int? = nil,
                                  offset:      Int? = nil,
                                  parameters:  [Bindable?] = []) throws -> Statement {
        
        return try self.prepareSelect(from:from, columns:columns, where:whereClause, groupBy:groupBy, having:having, orderBy:orderBy, limit:limit, offset:offset, parameters:parameters)
        
    }
    
    public func prepareSelectIdsFrom(_ from:        String,
                                     whereExpr whereClause:   String? = nil,
                                     groupBy:     String? = nil,
                                     having:      String? = nil,
                                     orderBy:     String? = nil,
                                     limit:       Int? = nil,
                                     offset:      Int? = nil,
                                     parameters:  [Bindable?] = []) throws -> Statement {
        
        return try self.prepareSelectIds(from:from, where:whereClause, groupBy:groupBy, having:having, orderBy:orderBy, limit:limit, offset:offset, parameters:parameters)
        
    }
    
    public func countFrom(_ from:      String,
                          columns:     [String]? = nil,
                          whereExpr whereClause:   String? = nil,
                          parameters:  [Bindable?] = []) throws -> Int64 {
        
        return try self.count(from:from, columns:columns, where:whereClause, parameters:parameters)
    }

    public func selectFrom<T>(_ from:       String,
                           columns:      [String]? = nil,
                           whereExpr whereClause:    String? = nil,
                           groupBy:      String? = nil,
                           having:       String? = nil,
                           orderBy:      String? = nil,
                           limit:        Int? = nil,
                           offset:       Int? = nil,
                           parameters:   [Bindable?] = [],
                           block:        ((Statement) throws -> T)) throws -> [T] {

        return try self.select(from: from, columns: columns, where: whereClause, groupBy: groupBy, having: having, orderBy: orderBy, limit: limit, offset: offset, parameters: parameters, block: block)
        
    }
    
    public func selectIdsFrom(_ from:       String,
                              whereExpr whereClause:    String? = nil,
                              groupBy:      String? = nil,
                              having:       String? = nil,
                              orderBy:      String? = nil,
                              limit:        Int? = nil,
                              offset:       Int? = nil,
                              parameters:   [Bindable?] = []) throws -> [RowId] {
        
        return try selectIds(from:from, where:whereClause, groupBy: groupBy, having: having, orderBy: orderBy, limit: limit, offset: offset, parameters: parameters)
        
    }
    
    func iterateRowsFrom(_ from:        String,
                         columns:     [String]? = nil,
                         whereExpr whereClause:   String? = nil,
                         groupBy:     String? = nil,
                         having:      String? = nil,
                         orderBy:     String? = nil,
                         limit:       Int? = nil,
                         offset:      Int? = nil,
                         parameters:  [Bindable?] = [],
                         block: ((Statement) throws -> Void)) throws {
        
        return try self.iterateRows(from: from, columns: columns, where: whereClause, groupBy: groupBy, having: having, orderBy: orderBy, limit: limit, offset: offset, parameters: parameters, block: block)
        
    }
    
}
