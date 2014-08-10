import Foundation
import Squeal

func createTemporaryDirectory(prefix:String = "Squeal") -> String {
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

extension Database {
    
    func open() {
        var error : NSError?
        if !open(&error) {
            NSException(name:       NSInternalInconsistencyException,
                        reason:     "Failed to open database: \(error?.localizedDescription)",
                        userInfo:   nil).raise()
        }
    }
    
    func prepareStatement(sqlString:String) -> Statement {
        var error : NSError? = nil
        var statement = self.prepareStatement(sqlString, error:&error)
        if statement == nil {
            NSException(name:       NSInternalInconsistencyException,
                        reason:     "Failed to prepare statement (\(sqlString)): \(error?.localizedDescription)",
                        userInfo:   nil).raise()
        }
        return statement!
    }
    
    func execute(statement:String) {
        var error : NSError?
        var succeeded = execute(statement, error:&error)
        
        if !succeeded {
            NSException(name:       NSInternalInconsistencyException,
                        reason:     "Failed to execute statement (\(statement)): \(error?.localizedDescription)",
                        userInfo:   nil).raise()
        }
    }
    
    func query(selectSql:String) -> Statement {
        var error : NSError? = nil
        var statement = query(selectSql, error:&error)
        
        if statement == nil {
            NSException(name:       NSInternalInconsistencyException,
                        reason:     "Failed to query statement (\(selectSql)): \(error?.localizedDescription)",
                        userInfo:   nil).raise()
        }
        
        return statement!
    }
    
}

extension Statement {
    
    func next() -> Bool {
        var error : NSError? = nil
        if let result = self.next(&error) {
            return result
        } else {
            NSException(name:       NSInternalInconsistencyException,
                        reason:     "Failed to advance statement: \(error?.localizedDescription)",
                        userInfo:   nil).raise()
            
            return false
        }
    }
    
    func reset() {
        var error : NSError? = nil
        var succeeded = reset(&error)
        if !succeeded {
            NSException(name:       NSInternalInconsistencyException,
                        reason:     "Failed to reset statement: \(error?.localizedDescription)",
                        userInfo:   nil).raise()
        }
    }
    
    func bind(parameters:Any?...) {
        var error : NSError? = nil
        let result = self.bind(parameters, error: &error)
        if result == false {
            NSException(name:       NSInternalInconsistencyException,
                        reason:     "Failed to bind parameters (\(parameters)): \(error?.localizedDescription)",
                        userInfo:   nil).raise()
        }
    }
    
}