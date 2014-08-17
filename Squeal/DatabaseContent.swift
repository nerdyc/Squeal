import Foundation
import sqlite3

// =====================================================================================================================
// MARK:- Database

extension Database {
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Insert
    
    public func insertRow(tableName:String, columns:[String], values:[Bindable?], error:NSErrorPointer) -> Int64? {
        var sqlFragments = ["INSERT INTO"]
        sqlFragments.append(escapeIdentifier(tableName))
        sqlFragments.append("(")
        sqlFragments.append(join(", ", columns.map { escapeIdentifier($0) }))
        sqlFragments.append(")")
        sqlFragments.append("VALUES")
        sqlFragments.append("(")
        sqlFragments.append(join(",", columns.map { _ in "?" }))
        sqlFragments.append(")")
        
        var rowId : Int64?
        if let statement = prepareStatement(join(" ", sqlFragments), error: error) {
            if statement.bind(values, error: error) {
                if statement.execute(error) {
                    rowId = lastInsertedRowId
                }
            }
            statement.close()
        }
        return rowId
    }
    
    public func insertRow(tableName:String, values valuesDictionary:[String:Bindable?], error:NSErrorPointer) -> Int64? {
        var columns = [String]()
        var values = [Bindable?]()
        for (columnName, value) in valuesDictionary {
            columns.append(columnName)
            values.append(value)
        }
        
        return insertRow(tableName, columns:columns, values:values, error:error)
    }
    
}