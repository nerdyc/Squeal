import Foundation

public extension Database {
    
    public func prepareSelectFrom(from:        String,
                                  columns:     [String]? = nil,
                                  whereExpr:   String? = nil,
                                  groupBy:     String? = nil,
                                  having:      String? = nil,
                                  orderBy:     String? = nil,
                                  limit:       Int? = nil,
                                  offset:      Int? = nil,
                                  parameters:  [Bindable?] = [],
                                  error:       NSErrorPointer = nil) -> Statement? {
        
        var fragments = [ "SELECT" ]
        if columns != nil {
            fragments.append(join(",", columns!))
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
        
        var statement = prepareStatement(join(" ", fragments), error: error)
        if statement != nil && parameters.count > 0 {
            if false == statement!.bind(parameters, error:error) {
                statement = nil
            }
        }
        
        return statement
    }
    
    // =================================================================================================================
    // MARK:- SELECT
    
    /// Selects table rows and iterates over them. This is a helper for executing a SELECT statement, and reading the
    /// results.
    ///
    /// Results are read by the `collector` block. The block will be invoked for each row of the result set, and is
    /// expected to return a value read from the row. It will be provided a Statement, from which the row can be read.
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
    /// :param: error       An error pointer.
    /// :param: collector   A block used to read each row.
    ///
    /// :returns:   An array of all values read, or nil if an error occurs.
    ///
    public func selectFrom(from:        String,
                           columns:     [String]? = nil,
                           whereExpr:   String? = nil,
                           groupBy:     String? = nil,
                           having:      String? = nil,
                           orderBy:     String? = nil,
                           limit:       Int? = nil,
                           offset:      Int? = nil,
                           parameters:  [Bindable?] = [],
                           error:       NSErrorPointer = nil) -> StepSequence {
        
        let statement = prepareSelectFrom(from,
                                          columns:   columns,
                                          whereExpr: whereExpr,
                                          groupBy:   groupBy,
                                          having:    having,
                                          orderBy:   orderBy,
                                          limit:     limit,
                                          offset:    offset,
                                          error:     error)
        if statement == nil {
            return StepSequence(statement:nil, errorPointer:error, hasError:true)
        }

        return statement!.query(parameters:parameters, error:error)
    }
    
    /// Fetches the IDs of all rows that match the given WHERE clause. This makes use of SQLite's `_ROWID_` alias to
    /// select the primary key from the given table.
    ///
    /// :param: tableName   The name of the table to select from. Should not include join clauses.
    /// :param: whereExpr   The WHERE clause. If nil, then all rows are returned.
    /// :param: orderBy     The ORDER BY clause.
    /// :param: limit       The LIMIT.
    /// :param: offset      The OFFSET.
    /// :param: parameters  An array of parameters to bind to the statement.
    /// :param: error       An error pointer.
    ///
    public func selectRowIdsFrom(tableName:   String,
                                 whereExpr:   String? = nil,
                                 orderBy:     String? = nil,
                                 limit:       Int? = nil,
                                 offset:      Int? = nil,
                                 parameters:  [Bindable?] = [],
                                 error:       NSErrorPointer = nil) -> [RowId]? {
        
        let statement = prepareSelectFrom(tableName,
                                          columns:   ["_ROWID_"],
                                          whereExpr: whereExpr,
                                          orderBy:   orderBy,
                                          limit:     limit,
                                          offset:    offset,
                                          parameters:parameters,
                                          error:     error)
        if statement == nil {
            return nil
        }
        
        var rowIds = [RowId]()
        for step in statement!.query(error:error) {
            if step == nil {
                return nil
            }
            
            rowIds.append(statement!.int64ValueAtIndex(0) ?? 0)
        }
        return rowIds
    }

    // =================================================================================================================
    // MARK:- COUNT
    
    /// Counts rows in a table. This is a helper for executing a SELECT count(...) FROM statement and reading the
    /// result.
    ///
    /// :param: from        The name of the table to select from, including any JOIN clauses.
    /// :param: columns     The columns to count. If nil, then 'count(*)' is returned.
    /// :param: whereExpr   The WHERE clause. If nil, then all rows are returned.
    /// :param: parameters  An array of parameters to bind to the statement.
    /// :param: error       An error pointer.
    ///
    /// :returns:   The number of rows counted, or nil if an error occurs.
    ///
    public func countFrom(from:        String,
                          columns:     [String]? = nil,
                          whereExpr:   String? = nil,
                          parameters:  [Bindable?] = [],
                          error:       NSErrorPointer = nil) -> Int64? {

        let countExpr = "count(" + join(",", columns ?? ["*"]) + ")"
        if let statement = prepareSelectFrom(from,
                                             columns:   [countExpr],
                                             whereExpr: whereExpr,
                                             parameters:parameters,
                                             error:     error) {
            
            var count: Int64? = 0
            for step in statement.query(error:error) {
                count = step?.int64ValueAtIndex(0)
                break
            }
            return count
        } else {
            return nil
        }
    }
    
}