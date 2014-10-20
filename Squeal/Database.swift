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
    
public typealias RowId = Int64
typealias SQLiteDBPointer = COpaquePointer

private func errorFromSQLiteResultCode(database:SQLiteDBPointer) -> NSError {
    var userInfo: [String:AnyObject]?
    
    let resultCode = sqlite3_errcode(database)
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

// =====================================================================================================================
// MARK:- Database

///
/// Provides access to a SQLite database. SQL can be compiled into reusable Statement objects, or executed directly.
///
/// A Database object can be passed between threads, but should not be used concurrently from multiple threads.
/// Otherwise SQL exectured from one thread may affect the other's. For example, one thread might close a transaction
/// opened by another.
///
public class Database : NSObject {
    
    private let sqliteDatabase : SQLiteDBPointer

    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Initialization
    
    /// :returns: A Database whose contents are stored in-memory, and discarded when the Database is released.
    public class func newInMemoryDatabase(error:NSErrorPointer = nil) -> Database? {
        return Database(error:error)
    }
        
    /// :returns: A Database whose contents are stored in a temporary location on disk, and discarded when the Database
    ///           is no longer used.
    public class func newTemporaryDatabase(error:NSErrorPointer = nil) -> Database? {
        return Database(path:"", error:error)
    }
    
    /// :returns: An in-memory Database.
    public convenience init?(error:NSErrorPointer = nil) {
        self.init(path:":memory:", error:error)
    }
    
    /// :param: path    The location of the database on disk. The empty string will create a temporary Database, and
    ///                 the special path ':memory:' creates an in-memory database.
    ///
    /// :returns: A Database whose contents are stored at the given path on disk.
    public init?(path:String, error:NSErrorPointer = nil) {
        self.path = path
        
        var sqliteDatabase : SQLiteDBPointer = nil
        var result = sqlite3_open_v2(path.cStringUsingEncoding(NSUTF8StringEncoding)!,
                                     &sqliteDatabase,
                                     SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE,
                                     nil)
        self.sqliteDatabase = sqliteDatabase
        
        super.init()
        
        if result != SQLITE_OK {
            if error != nil {
                error.memory = errorFromSQLiteResultCode(sqliteDatabase)
            }
            
            return nil
        }
    }
    
    deinit {
        var result = sqlite3_close(sqliteDatabase)
        if result != SQLITE_OK {
            NSLog("Error closing database (resultCode: \(result)): \(sqliteError.localizedDescription)")
        }
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Path
    
    /// The location of the database on disk. Temporary databases will return an empty string, and in-memory databases
    /// return ':memory:'
    public let path : String
    
    /// :returns: `true` if the Database is stored in memory; `false` otherwise.
    public var isInMemoryDatabase : Bool {
        return path == ":memory:"
    }

    /// :returns: true if the Database is stored in a temporary location; false otherwise.
    public var isTemporaryDatabase : Bool {
        return path == ""
    }
    
    /// :returns: true if the Database is persistent -- not stored in memory or in a temporary location.
    public var isPersistentDatabase : Bool {
        return !(isInMemoryDatabase || isTemporaryDatabase)
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Statements
    
    private func prepareSQLiteStatement(sqlString:String, error:NSErrorPointer) -> SQLiteStatementPointer {
        var cString = sqlString.cStringUsingEncoding(NSUTF8StringEncoding)
        var sqliteStatement : SQLiteStatementPointer = nil
        
        var resultCode = sqlite3_prepare_v2(sqliteDatabase,
                                            cString!,
                                            -1,
                                            &sqliteStatement,
                                            nil)
        if resultCode != SQLITE_OK {
            if error != nil {
                error.memory = errorFromSQLiteResultCode(sqliteDatabase)
            }
            return nil
        }
        
        return sqliteStatement
    }
    
    ///
    /// Compiles a SQL string into a Statement, which can then be used to execute the SQL against the database.
    /// Statement objects can be executed multiple times, and are more efficient when executing the same query or update
    /// multiple times. See the Statement object for details, including providing parameters.
    ///
    /// :param:     sqlString   A SQL statement to compile.
    /// :param:     error       An error pointer to set if an error occurs. May be `nil`.
    /// :returns:               The compiled SQL as a Statement. On error, `nil` will be returned and an NSError object
    //                          will be provided via the `error` parameter.
    ///
    public func prepareStatement(sqlString:String, error:NSErrorPointer = nil) -> Statement? {
        let sqliteStatement = prepareSQLiteStatement(sqlString, error:error)
        if sqliteStatement == nil {
            return nil
        }
        
        return Statement(database:self, sqliteStatement: sqliteStatement)
    }
    
    ///
    /// Compiles and executes a SQL statement. Since this method simply returns `true` or `false`, it is useful for
    /// statements that return no data. For example, a `CREATE TABLE` statement. For other statements, consider the
    /// `prepareStatement` or `query` methods, or one of the SQL convenience methods like `select(...)`.
    ///
    /// :param:     sqlString   A SQL statement to execute.
    /// :param:     error       An error pointer to set if an error occurs. May be `nil`.
    /// :returns:               `true` if the statment was executed, `false` otherwise. On error, an NSError object will be
    ///                         provided via the `error` parameter.
    ///
    public func execute(sqlString:String, error:NSErrorPointer = nil) -> Bool {
        if let statement = prepareStatement(sqlString, error:error) {
            return statement.execute(error: error)
        } else {
            return false
        }
    }
    
    /// Returns the id of the last row inserted into the database via this Database object. This is useful after
    /// executing an INSERT statement, but undefined at other times.
    public var lastInsertedRowId : RowId {
        return sqlite3_last_insert_rowid(self.sqliteDatabase)
    }
    
    /// Returns the number of rows changed by the last statement executed via this Database object. This is useful after
    /// executing an UPDATE or DELETE statement, but undefined at other times.
    public var numberOfChangedRows : Int {
        return Int(sqlite3_changes(self.sqliteDatabase))
    }
    
    var sqliteError:NSError {
        return errorFromSQLiteResultCode(sqliteDatabase)
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Query
    
    public func query(sqlString:String, error:NSErrorPointer = nil) -> StepSequence {
        return query(sqlString, parameters:[], error:error)
    }
    
    public func query(sqlString:String, parameters:[Bindable?], error:NSErrorPointer = nil) -> StepSequence {
        if let statement = prepareStatement(sqlString, error:error) {
            return statement.query(parameters:parameters, error:error)
        } else {
            return StepSequence(statement:nil, errorPointer:error, hasError:true)
        }
    }

    public func query(sqlString:String, namedParameters:[String:Bindable?], error:NSErrorPointer = nil) -> StepSequence {
        if let statement = prepareStatement(sqlString, error:error) {
            return statement.query(namedParameters:namedParameters, error:error)
        } else {
            return StepSequence(statement:nil, errorPointer:error, hasError:true)
        }
    }
    
}
