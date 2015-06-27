import Foundation
import Squeal

public extension Database {
    
    public class func openTemporaryDatabase() -> Database {
        var error:NSError? = nil
        let db = Database.newTemporaryDatabase(error: &error)
        if db == nil {
            NSException(name:       NSInternalInconsistencyException,
                        reason:     "Error creating temporary database \(error)",
                        userInfo:   nil).raise()
        }
        
        return db!
    }
    
    public class func createTemporaryDirectory(prefix:String = "Squeal") -> String {
        let suffix = NSUUID().UUIDString
        let tempDirectoryPath = NSTemporaryDirectory().stringByAppendingPathComponent(prefix + "-" + suffix)
        
        do {
            try NSFileManager.defaultManager().createDirectoryAtPath(tempDirectoryPath,
                                                                     withIntermediateDirectories: true,
                                                                     attributes:                  nil)
        } catch {
            NSException(name:       NSInternalInconsistencyException,
                        reason:     "Error creating temporary directory \(error)",
                        userInfo:   nil).raise()
        }
        
        return tempDirectoryPath
    }
    
    public func executeOrFail(statement:String) {
        var error : NSError?
        let succeeded = execute(statement, error:&error)
        
        if !succeeded {
            NSException(name:       NSInternalInconsistencyException,
                        reason:     "Failed to execute statement (\(statement)): \(error?.localizedDescription)",
                        userInfo:   nil).raise()
        }
    }
    
    public func dropTable(tableName:String) {
        var error : NSError? = nil
        let result = dropTable(tableName, error:&error)
        if !result {
            NSException(name:       NSInternalInconsistencyException,
                        reason:     "Failed to drop table: \(error?.localizedDescription)",
                        userInfo:   nil).raise()
        }
    }
    
    public func insert(tableName:String, row:[String:Bindable?]) -> Int64 {
        var error : NSError?
        if let rowId = insertInto(tableName, values:row, error: &error) {
            return rowId
        } else {
            NSException(name:       NSInternalInconsistencyException,
                        reason:     "Failed to insert row (\(row)): \(error?.localizedDescription)",
                        userInfo:   nil).raise()
            return 0
        }
    }
    
    public func queryRows(sqlString:String, error:NSErrorPointer = nil) -> [[String:Bindable]]? {
        var rows = [[String:Bindable]]()
        for row in self.query(sqlString, error:error) {
            if row == nil {
                return nil
            }
            
            rows.append(row!.dictionaryValue)
        }
        return rows
    }
    
}

