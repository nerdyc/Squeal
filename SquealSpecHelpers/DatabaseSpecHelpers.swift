import Foundation
import Squeal

public extension Database {
    
    public class func createTemporaryDirectory(prefix:String = "Squeal") -> String {
        let suffix = NSUUID().UUIDString
        let tempDirectoryPath = NSTemporaryDirectory().stringByAppendingPathComponent(prefix + "-" + suffix)
        
        var error : NSError?
        var success = NSFileManager.defaultManager().createDirectoryAtPath(tempDirectoryPath,
                                                                           withIntermediateDirectories: true,
                                                                           attributes:                  nil,
                                                                           error:                       &error)
        if !success {
            NSException(name:       NSInternalInconsistencyException,
                        reason:     "Error creating temporary directory \(error)",
                        userInfo:   nil).raise()
        }
        
        return tempDirectoryPath
    }
    
    public func open() {
        var error : NSError?
        if !open(&error) {
            NSException(name:       NSInternalInconsistencyException,
                        reason:     "Failed to open database: \(error?.localizedDescription)",
                        userInfo:   nil).raise()
        }
    }
    
    public func prepareStatement(sqlString:String) -> Statement {
        var error : NSError? = nil
        var statement = self.prepareStatement(sqlString, error:&error)
        if statement == nil {
            NSException(name:       NSInternalInconsistencyException,
                        reason:     "Failed to prepare statement (\(sqlString)): \(error?.localizedDescription)",
                        userInfo:   nil).raise()
        }
        return statement!
    }
    
    public func execute(statement:String) {
        var error : NSError?
        var succeeded = execute(statement, error:&error)
        
        if !succeeded {
            NSException(name:       NSInternalInconsistencyException,
                        reason:     "Failed to execute statement (\(statement)): \(error?.localizedDescription)",
                        userInfo:   nil).raise()
        }
    }
    
    public func query(selectSql:String) -> Statement {
        var error : NSError? = nil
        var statement = query(selectSql, error:&error)
        
        if statement == nil {
            NSException(name:       NSInternalInconsistencyException,
                        reason:     "Failed to query statement (\(selectSql)): \(error?.localizedDescription)",
                        userInfo:   nil).raise()
        }
        
        return statement!
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
    
}

