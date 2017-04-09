import Foundation
import Clibsqlite3

/// Error domain for sqlite errors
let SQLiteErrorDomain = "sqlite3"

func errorFromSQLiteErrorCode(_ errorCode:Int32, message:String?) -> NSError {
    var userInfo: [String:AnyObject]?
    if message != nil {
        userInfo = [ NSLocalizedDescriptionKey:message! as AnyObject ]
    }
    
    return NSError(domain:  SQLiteErrorDomain,
                   code:    Int(errorCode),
                   userInfo:userInfo)
}

/// Error domain for Squeal errors. Typically this implies a programming error, since Squeal simply wraps sqlite.
let SquealErrorDomain = "Squeal"

/// Enumeration of error codes that may be returned by Squeal methods.
public enum SquealErrorCode: Int {
    
    case success = 0
    case unknownBindParameter
    
    public var localizedDescription : String {
        switch self {
            case .success:
                return "Success"
            case .unknownBindParameter:
                return "Unknown parameter to bind"
        }
    }
    
    public func asError() -> NSError {
        return NSError(domain:  SquealErrorDomain,
                       code:    rawValue,
                       userInfo:[ NSLocalizedDescriptionKey:localizedDescription])
    }
}
