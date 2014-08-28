import Foundation
import sqlite3

// =====================================================================================================================
// MARK:- Database

extension Database {
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Insert
    
    public func prepareInsertInto(tableName:String, columns:[String], error:NSErrorPointer) -> Statement? {
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
    public func insertInto(tableName:String, columns:[String], values:[Bindable?], error:NSErrorPointer) -> Int64? {
        var rowId : Int64?
        if let statement = prepareInsertInto(tableName, columns:columns, error: error) {
            if statement.bind(values, error: error) {
                if statement.execute(error) {
                    rowId = lastInsertedRowId
                }
            }
            statement.close()
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
    public func insertInto(tableName:String, values valuesDictionary:[String:Bindable?], error:NSErrorPointer) -> Int64? {
        var columns = [String]()
        var values = [Bindable?]()
        for (columnName, value) in valuesDictionary {
            columns.append(columnName)
            values.append(value)
        }
        
        return insertInto(tableName, columns:columns, values:values, error:error)
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Select
    
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
            fragments.append("\(limit)")
            
            if offset != nil {
                fragments.append("OFFSET")
                fragments.append("\(offset!)")
            }
        }
        
        var statement = prepareStatement(join(" ", fragments), error: error)
        if statement != nil && parameters.count > 0 {
            if false == statement!.bind(parameters, error:error) {
                statement!.close()
                statement = nil
            }
        }
        
        return statement
    }
    
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
    public func selectFrom<T>(from:        String,
                              columns:     [String]? = nil,
                              whereExpr:   String? = nil,
                              groupBy:     String? = nil,
                              having:      String? = nil,
                              orderBy:     String? = nil,
                              limit:       Int? = nil,
                              offset:      Int? = nil,
                              parameters:  [Bindable?] = [],
                              error:       NSErrorPointer = nil,
                              collector:   (Statement)->(T)) -> [T]? {
        
        if let statement = prepareSelectFrom(from,
                                             columns:   columns,
                                             whereExpr: whereExpr,
                                             groupBy:   groupBy,
                                             having:    having,
                                             orderBy:   orderBy,
                                             limit:     limit,
                                             offset:    offset,
                                             parameters:parameters,
                                             error:     error) {
                
            var values = statement.collect(error, collector:collector)
            statement.close()
            return values
                
        } else {
            return nil
        }
    }

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
            
            var count : Int64?
            switch statement.next(error) {
            case .Some(true):
                count = statement.int64ValueAtIndex(0)
            case .Some(false):
                count = 0
            default:
                break
            }

            statement.close()
            return count
        } else {
            return nil
        }
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Update
    
    public func prepareUpdate(tableName:   String,
                              columns:     [String],
                              whereExpr:   String? = nil,
                              error:       NSErrorPointer) -> Statement? {
        
        var fragments = ["UPDATE", escapeIdentifier(tableName), "SET"]
        for columnName in columns {
            fragments.append(columnName)
            fragments.append("= ?")
        }
        
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
                       error:       NSErrorPointer) -> Int? {
        
        var numberOfChangedRows : Int?
        if let statement = prepareUpdate(tableName, columns: columns, whereExpr: whereExpr, error: error) {
            if statement.bind(values + parameters, error: error) {
                if statement.execute(error) {
                    numberOfChangedRows = self.numberOfChangedRows
                }
            }
            statement.close()
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
                       error:       NSErrorPointer) -> Int? {
        
        var columns = [String]()
        var values = [Bindable?]()
        for (columnName, value) in set {
            columns.append(columnName)
            values.append(value)
        }
        
        return update(tableName, columns:columns, values:values, whereExpr:whereExpr, parameters:parameters, error:error)
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Delete
    
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