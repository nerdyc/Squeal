import Foundation
import sqlite3

/// Error domain for sqlite errors
let SQLiteErrorDomain = "sqlite3"

/// Error domain for Squeal errors. Typically this implies a programming error, since Squeal simply wraps sqlite.
let SquealErrorDomain = "Squeal"

/// Enumeration of error codes that may be returned by Squeal methods.
public enum SquealErrorCode: Int {
    
    case Success = 0
    case DatabaseClosed
    case StatementClosed
    case UnknownBindParameter
    
    public var localizedDescription : String {
        switch self {
            case .Success:
                return "Success"
            case .DatabaseClosed:
                return "Database has been closed"
            case .StatementClosed:
                return "Statement has been closed"
            case .UnknownBindParameter:
                return "Unknown parameter to bind"
        }
    }
    
    public func asError() -> NSError {
        return NSError(domain:  SquealErrorDomain,
                       code:    rawValue,
                       userInfo:[ NSLocalizedDescriptionKey:localizedDescription])
    }
}

func errorFromSqliteResultCode(database:COpaquePointer, resultCode:Int32) -> NSError {
    var userInfo: [String:AnyObject]?
    let errorMsg = sqlite3_errmsg(database)
    if errorMsg != nil {
        if let errorString = NSString(UTF8String: errorMsg) {
            userInfo = [ NSLocalizedDescriptionKey:errorString ]
        }
    }
    
    return NSError(domain:  SQLiteErrorDomain,
                   code:    Int(resultCode),
                   userInfo:userInfo)
}