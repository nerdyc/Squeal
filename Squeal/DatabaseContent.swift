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