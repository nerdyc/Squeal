import Foundation
import Squeal

public extension Database {
    
    public class func createTemporaryDirectory(prefix:String = "Squeal") throws -> String {
        let suffix = NSUUID().UUIDString
        let tempDirectoryPath = NSTemporaryDirectory().stringByAppendingPathComponent(prefix + "-" + suffix)
        
        try NSFileManager.defaultManager().createDirectoryAtPath(tempDirectoryPath,
                                                                 withIntermediateDirectories: true,
                                                                 attributes:                  nil)
        
        return tempDirectoryPath
    }
    
    public func queryRows(sqlString:String) throws -> [[String:Bindable]] {
        var rows = [[String:Bindable]]()
        var error:NSError?
        for row in self.query(sqlString, error:&error) {
            if row == nil {
                throw error!
            }
            
            rows.append(row!.dictionaryValue)
        }
        return rows
    }
    
}

