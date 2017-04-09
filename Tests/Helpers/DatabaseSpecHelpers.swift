import Foundation
import Squeal

public extension Database {
    
    public class func createTemporaryDirectoryURL(_ prefix:String = "Squeal") throws -> URL {
        let suffix = UUID().uuidString
        let globalTempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let tempDirectoryURL = globalTempDirectoryURL.appendingPathComponent(prefix + "-" + suffix)
        
        try FileManager.default.createDirectory(at: tempDirectoryURL,
                                                                withIntermediateDirectories: true,
                                                                attributes:                  nil)
        
        return tempDirectoryURL
    }

    public class func createTemporaryDirectory(_ prefix:String = "Squeal") throws -> String {
        return try createTemporaryDirectoryURL(prefix).path
    }
    
    public func queryRows(_ sqlString:String) throws -> [[String:Bindable]] {
        let statement = try prepareStatement(sqlString)
        var rows = [[String:Bindable]]()
        while try statement.next() {
            rows.append(statement.dictionaryValue)
        }
        return rows
    }
    
}

