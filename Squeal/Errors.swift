import Foundation

#if os(iOS)
    #if arch(i386) || arch(x86_64)
        import sqlite3_ios_simulator
    #else
        import sqlite3_ios
    #endif
#else
import sqlite3_osx
#endif

/// Error domain for sqlite errors
let SQLiteErrorDomain = "sqlite3"

/// Error domain for Squeal errors. Typically this implies a programming error, since Squeal simply wraps sqlite.
let SquealErrorDomain = "Squeal"

/// Enumeration of error codes that may be returned by Squeal methods.
public enum SquealErrorCode: Int {
    
    case Success = 0
    case UnknownBindParameter
    
    public var localizedDescription : String {
        switch self {
            case .Success:
                return "Success"
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