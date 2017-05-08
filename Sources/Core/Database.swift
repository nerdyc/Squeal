import Foundation
import Clibsqlite3
    
public typealias RowId = Int64
typealias SQLiteDBPointer = OpaquePointer


/// Generates an NSError from the current sqlite error code and message.
private func errorFromSQLiteResultCode(_ database:SQLiteDBPointer) -> NSError {
    var userInfo: [String:AnyObject]?
    
    let resultCode = sqlite3_errcode(database)
    let errorMsg = sqlite3_errmsg(database)
    if errorMsg != nil {
        if let errorString = NSString(utf8String: errorMsg!) {
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
open class Database {
    
    fileprivate let sqliteDatabase : SQLiteDBPointer

    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Initialization
    
    /// Creates a new, memory-only database.
    ///
    /// - Returns: The created database.
    open class func newInMemoryDatabase() -> Database {
        return Database()
    }
    
    /// Creates a new database in a temporary directory on disk.
    ///
    /// - Returns: The created database.
    open class func newTemporaryDatabase() -> Database {
        return try! Database(path:"")
    }
    
    /// Creates a new, in-memory database.
    public convenience init() {
        try! self.init(path:":memory:")
    }
    
    /// Creates a new database with the given path.
    ///
    /// - Parameters:
    ///     - path: The path to the database. An empty path will create a temporary Database, and the special path
    ///             ':memory:' creates an in-memory database.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public init(path:String) throws {
        self.path = path
        
        var sqliteDatabase : SQLiteDBPointer? = nil
        let result = sqlite3_open_v2(path.cString(using: String.Encoding.utf8)!,
                                     &sqliteDatabase,
                                     SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE,
                                     nil)
        if result != SQLITE_OK {
            throw errorFromSQLiteResultCode(sqliteDatabase!)
        }
        
        self.sqliteDatabase = sqliteDatabase!
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
    open let path : String
    
    /// Whether the database is stored in memory or not.
    open var isInMemoryDatabase : Bool {
        return path == ":memory:"
    }

    /// Whether the database is a temporary database (on-disk).
    open var isTemporaryDatabase : Bool {
        return path == ""
    }
    
    /// Whether the database will persist or not. E.g. Not stored in memory or in a temporary location.
    open var isPersistentDatabase : Bool {
        return !(isInMemoryDatabase || isTemporaryDatabase)
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Statements
    
    fileprivate func prepareSQLiteStatement(_ sqlString:String) throws -> SQLiteStatementPointer {
        let cString = sqlString.cString(using: String.Encoding.utf8)
        var sqliteStatement : SQLiteStatementPointer? = nil
        
        let resultCode = sqlite3_prepare_v2(sqliteDatabase,
                                            cString!,
                                            -1,
                                            &sqliteStatement,
                                            nil)
        if resultCode != SQLITE_OK {
            throw errorFromSQLiteResultCode(sqliteDatabase)
        }
        
        return sqliteStatement!
    }
    
    ///
    /// Compiles a SQL string into a Statement, which can then be used to execute the SQL against the database.
    /// Statement objects can be executed multiple times, and are more efficient when executing the same query or update
    /// multiple times. See the Statement object for details, including providing parameters.
    ///
    /// - Parameters:
    ///     - sqlString:    A SQL statement to compile.
    ///     - parameters:   Any parameters to bind to the prepared statement.
    /// - Returns:
    ///     The compiled SQL as a Statement.
    /// - Throws:
    ///     An NSError with the sqlite3 error code and message.
    ///
    open func prepareStatement(_ sqlString:String, parameters:[Bindable?] = []) throws -> Statement {
        let sqliteStatement = try prepareSQLiteStatement(sqlString)
        let statement = Statement(database:self, sqliteStatement: sqliteStatement)
        if parameters.count > 0 {
            try statement.bind(parameters)
        }
        return statement
    }
    
    ///
    /// Compiles and executes a SQL statement. This method is useful for statements that return no
    /// data. For example, a `CREATE TABLE` statement. For `SELECT` statements, prepare the statement
    /// using `prepareStatement` and iterate through rows using the `next` method on the Statement.
    ///
    /// - Parameters:
    ///     - sqlString:    The SQL statement to execute.
    ///     - parameters:   Any parameters to bind to the SQL statement.
    /// - Throws:
    ///     An NSError with the sqlite3 error code and message.
    ///
    open func execute(_ sqlString:String, parameters:[Bindable?] = []) throws {
        let statement = try prepareStatement(sqlString, parameters:parameters)
        try statement.execute()
    }

    /// The id of the last row inserted into the database via this Database object. This is useful after executing an
    /// INSERT statement, but undefined at other times.
    open var lastInsertedRowId : RowId {
        return sqlite3_last_insert_rowid(self.sqliteDatabase)
    }
    
    /// The number of rows changed by the last statement executed via this Database object. This is useful after
    /// executing an UPDATE or DELETE statement, but undefined at other times.
    open var numberOfChangedRows : Int {
        return Int(sqlite3_changes(self.sqliteDatabase))
    }
    
    var sqliteError:NSError {
        return errorFromSQLiteResultCode(sqliteDatabase)
    }
    
}
