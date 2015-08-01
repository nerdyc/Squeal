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
        let statement = try prepareStatement(sqlString)
        var rows = [[String:Bindable]]()
        while try statement.next() {
            rows.append(statement.dictionaryValue)
        }
        return rows
    }
    
}

