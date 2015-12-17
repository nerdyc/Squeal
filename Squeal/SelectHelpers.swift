import Foundation

public extension Database {
    
    // ---------------------------------------------------------------------------------------------
    // MARK: SELECT
    
    /// Compiles a SELECT statement, optionally binding values. Use the `next` method to begin
    /// iterating results.
    ///
    /// :param: from        The name of the table to select from, including any JOIN clauses.
    /// :param: columns     The columns to select. These are not escaped, and can contain expressions. If nil, all
    ///                     columns are returned (e.g. '*').
    /// :param: whereExpr   The WHERE clause. If nil, then all rows are returned.
    /// :param: groupBy     The GROUP BY expression.
    /// :param: having      The HAVING clause.
    /// :param: orderBy     The ORDER BY clause.
    /// :param: limit       The LIMIT.
    /// :param: offset      The OFFSET.
    /// :param: parameters  An array of parameters to bind to the statement.
    ///
    /// :returns:   An array of all values read, or nil if an error occurs.
    ///
    public func prepareSelectFrom(from:        String,
                                  columns:     [String]? = nil,
                                  whereExpr:   String? = nil,
                                  groupBy:     String? = nil,
                                  having:      String? = nil,
                                  orderBy:     String? = nil,
                                  limit:       Int? = nil,
                                  offset:      Int? = nil,
                                  parameters:  [Bindable?] = []) throws -> Statement {
        
        var fragments = [ "SELECT" ]
        if columns != nil {
            fragments.append(columns!.joinWithSeparator(","))
        } else {
            fragments.append("*")
        }
        
        fragments.append("FROM")
        fragments.append(from)
                            
        if whereExpr != nil {
            fragments.append("WHERE")
            fragments.append(whereExpr!)
        }
        
        if groupBy != nil {
            fragments.append("GROUP BY")
            fragments.append(groupBy!)
        }
        
        if having != nil {
            fragments.append("HAVING")
            fragments.append(having!)
        }
        
        if orderBy != nil {
            fragments.append("ORDER BY")
            fragments.append(orderBy!)
        }
        
        if limit != nil {
            fragments.append("LIMIT")
            fragments.append("\(limit!)")
            
            if offset != nil {
                fragments.append("OFFSET")
                fragments.append("\(offset!)")
            }
        }
        
        let statement = try prepareStatement(fragments.joinWithSeparator(" "))
        if parameters.count > 0 {
            try statement.bind(parameters)
        }
        
        return statement
    }
    
    public func prepareSelectIdsFrom(from:        String,
                                     whereExpr:   String? = nil,
                                     groupBy:     String? = nil,
                                     having:      String? = nil,
                                     orderBy:     String? = nil,
                                     limit:       Int? = nil,
                                     offset:      Int? = nil,
                                     parameters:  [Bindable?] = []) throws -> Statement {

        return try prepareSelectFrom(from,
                                     columns:    ["_ROWID_"],
                                     whereExpr:  whereExpr,
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
    /// :param: from        The name of the table to select from, including any JOIN clauses.
    /// :param: columns     The columns to count. If nil, then 'count(*)' is returned.
    /// :param: whereExpr   The WHERE clause. If nil, then all rows are returned.
    /// :param: parameters  An array of parameters to bind to the statement.
    ///
    /// :returns:   The number of rows counted, or nil if an error occurs.
    ///
    public func countFrom(from:        String,
                          columns:     [String]? = nil,
                          whereExpr:   String? = nil,
                          parameters:  [Bindable?] = []) throws -> Int64 {

        let countExpr = "count(" + (columns ?? ["*"]).joinWithSeparator(",") + ")"
        let statement = try prepareSelectFrom(from,
                                              columns:   [countExpr],
                                              whereExpr: whereExpr,
                                              parameters:parameters)
                                    
        var count:Int64 = 0
        if try statement.next() {
            count = statement.int64ValueAtIndex(0) ?? 0
        }
        return count
    }
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Query
    
    ///
    /// Executes the given SELECT statement and returns the first column of the first row as an Int.
    /// This is great for counting, or getting a single id. Returns nil if no rows matched, or the
    /// first column contained a NULL value.
    ///
    public func selectInt(sqlString:String, parameters:[Bindable?] = []) throws -> Int? {
        return try prepareStatement(sqlString, parameters:parameters).selectNextInt()
    }

    ///
    /// Executes the given SELECT statement and returns the first column of the first row as an
    /// Int64. Returns nil if no rows matched, or the first column contained a NULL value.
    ///
    public func selectInt64(sqlString:String, parameters:[Bindable?] = []) throws -> Int64? {
        return try prepareStatement(sqlString, parameters:parameters).selectNextInt64()
    }

    ///
    /// Executes the given SELECT statement and returns the first column of the first row as a
    /// Double. Returns nil if no rows matched, or the first column contained a NULL value.
    ///
    public func selectDouble(sqlString:String, parameters:[Bindable?] = []) throws -> Double? {
        return try prepareStatement(sqlString, parameters:parameters).selectNextDouble()
    }

    ///
    /// Executes the given SELECT statement and returns the first column of the first row as a
    /// String. Returns nil if no rows matched, or the first column contained a NULL value.
    ///
    public func selectString(sqlString:String, parameters:[Bindable?] = []) throws -> String? {
        return try prepareStatement(sqlString, parameters:parameters).selectNextString()
    }

    ///
    /// Executes the given SELECT statement and returns the first column of the first row as a
    /// Bool. Returns nil if no rows matched, or the first column contained a NULL value.
    ///
    public func selectBool(sqlString:String, parameters:[Bindable?] = []) throws -> Bool? {
        return try prepareStatement(sqlString, parameters:parameters).selectNextBool()
    }

    ///
    /// Executes the given SELECT statement and returns the first row, transformed by the given
    /// block. Returns nil if no rows matched.
    ///
    public func selectFirst<T>(sqlString:String, parameters:[Bindable?] = [], block:(Statement)->T) throws -> T? {
        return try prepareStatement(sqlString, parameters:parameters).selectNextRow(block)
    }
    
    ///
    /// Executes the given SELECT statement and returns all matching rows, transformed by the given
    /// block.
    ///
    public func selectAll<T>(sqlString:String, parameters:[Bindable?] = [], block:(Statement)->T) throws -> [T] {
        return try prepareStatement(sqlString, parameters:parameters).selectRows(block)
    }
    
    public func selectFrom<T>(from:        String,
                              columns:     [String]? = nil,
                              whereExpr:   String? = nil,
                              groupBy:     String? = nil,
                              having:      String? = nil,
                              orderBy:     String? = nil,
                              limit:       Int? = nil,
                              offset:      Int? = nil,
                              parameters:  [Bindable?] = [],
                              block:       ((Statement) throws -> T)) throws -> [T] {
                                
        let statement = try prepareSelectFrom(from,
                                              columns:columns,
                                              whereExpr:whereExpr,
                                              groupBy:groupBy,
                                              having:having,
                                              orderBy:orderBy,
                                              limit:limit,
                                              offset:offset,
                                              parameters:parameters)
        
        return try statement.select(block:block)
    }
    
    public func selectIdsFrom(from:        String,
                              whereExpr:   String? = nil,
                             groupBy:     String? = nil,
                             having:      String? = nil,
                             orderBy:     String? = nil,
                             limit:       Int? = nil,
                             offset:      Int? = nil,
                             parameters:  [Bindable?] = []) throws -> [RowId] {

        let statement = try prepareSelectIdsFrom(from,
                                                 whereExpr: whereExpr,
                                                 groupBy: groupBy,
                                                 having: having,
                                                 orderBy: orderBy,
                                                 limit: limit,
                                                 offset: offset,
                                                 parameters: parameters)
        
        return try statement.select() { $0.int64ValueAtIndex(0) ?? 0 }
    }
    
}

public extension Statement {
    
    public func selectNext<T>(block:((Statement) throws -> T)) throws -> T? {
        guard try next() else {
            return nil
        }
        
        return try block(self)
    }
    
    public func select<T>(parameters:[Bindable?]? = nil, block:((Statement) throws -> T)) throws -> [T] {
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
    
}