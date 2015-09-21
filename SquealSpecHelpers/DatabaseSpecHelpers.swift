import Foundation
import Squeal

public extension Database {
    
    public class func createTemporaryDirectory(prefix:String = "Squeal") throws -> String {
        let suffix = NSUUID().UUIDString
        let globalTempDirectoryURL = NSURL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let tempDirectoryURL = globalTempDirectoryURL.URLByAppendingPathComponent(prefix + "-" + suffix)
        
        try NSFileManager.defaultManager().createDirectoryAtURL(tempDirectoryURL,
                                                                withIntermediateDirectories: true,
                                                                attributes:                  nil)
        
        return tempDirectoryURL.path!
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

