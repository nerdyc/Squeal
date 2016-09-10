import Foundation
import Squeal

public extension Database {
    
    public class func createTemporaryDirectoryURL(prefix:String = "Squeal") throws -> NSURL {
        let suffix = NSUUID().UUIDString
        let globalTempDirectoryURL = NSURL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        guard let tempDirectoryURL = globalTempDirectoryURL.URLByAppendingPathComponent(prefix + "-" + suffix) else {
            fatalError("unable to construct temp tempDirectoryURL")
        }
        
        try NSFileManager.defaultManager().createDirectoryAtURL(tempDirectoryURL,
                                                                withIntermediateDirectories: true,
                                                                attributes:                  nil)
        
        return tempDirectoryURL
    }

    public class func createTemporaryDirectory(prefix:String = "Squeal") throws -> String {
        return try createTemporaryDirectoryURL(prefix).path!
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

