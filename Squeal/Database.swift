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
    public class func newInMemoryDatabase() -> Database {
        return Database()
    }
        
    /// :returns: A Database whose contents are stored in a temporary location on disk, and discarded when the Database
    ///           is no longer used.
    public class func newTemporaryDatabase() -> Database {
        return try! Database(path:"")
    }
    
    /// :returns: An in-memory Database.
    public convenience override init() {
        try! self.init(path:":memory:")
    }
    
    /// :param: path    The location of the database on disk. The empty string will create a temporary Database, and
    ///                 the special path ':memory:' creates an in-memory database.
    ///
    /// :returns: A Database whose contents are stored at the given path on disk.
    public init(path:String) throws {
        self.path = path
        
        var sqliteDatabase : SQLiteDBPointer = nil
        let result = sqlite3_open_v2(path.cStringUsingEncoding(NSUTF8StringEncoding)!,
                                     &sqliteDatabase,
                                     SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE,
                                     nil)
        self.sqliteDatabase = sqliteDatabase
        
        super.init()
        
        if result != SQLITE_OK {
            throw errorFromSQLiteResultCode(sqliteDatabase)
        }
    }
    
    deinit {
        let result = sqlite3_close(sqliteDatabase)
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
    
    private func prepareSQLiteStatement(sqlString:String) throws -> SQLiteStatementPointer {
        let cString = sqlString.cStringUsingEncoding(NSUTF8StringEncoding)
        var sqliteStatement : SQLiteStatementPointer = nil
        
        let resultCode = sqlite3_prepare_v2(sqliteDatabase,
                                            cString!,
                                            -1,
                                            &sqliteStatement,
                                            nil)
        if resultCode != SQLITE_OK {
            throw errorFromSQLiteResultCode(sqliteDatabase)
        }
        
        return sqliteStatement
    }
    
    ///
    /// Compiles a SQL string into a Statement, which can then be used to execute the SQL against the database.
    /// Statement objects can be executed multiple times, and are more efficient when executing the same query or update
    /// multiple times. See the Statement object for details, including providing parameters.
    ///
    /// :param:     sqlString   A SQL statement to compile.
    /// :returns:               The compiled SQL as a Statement.
    ///
    public func prepareStatement(sqlString:String, parameters:[Bindable?] = []) throws -> Statement {
        let sqliteStatement = try prepareSQLiteStatement(sqlString)
        let statement = Statement(database:self, sqliteStatement: sqliteStatement)
        if parameters.count > 0 {
            try statement.bind(parameters)
        }
        return statement
    }
    
    ///
    /// Compiles and executes a SQL statement. This method is useful for statements that return no
    /// data. For example, a `CREATE TABLE` statement. For SELECT statements, prepare the statement
    /// using `prepareStatement` and iterate through rows using the `next` method on the Statement.
    ///
    /// :param:     sqlString   A SQL statement to execute.
    /// :param:     parameters  An optional array of parameters to pass to the statement.
    ///
    public func execute(sqlString:String, parameters:[Bindable?] = []) throws {
        let statement = try prepareStatement(sqlString, parameters:parameters)
        try statement.execute()
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
    
}
