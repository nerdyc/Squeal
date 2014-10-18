import Foundation
import sqlite3

public typealias RowId = Int64
typealias SQLiteDBPointer = COpaquePointer

// =====================================================================================================================
// MARK:- Database

///
/// Provides access to a sqlite database. Databases must be opened before use, and closed to release retained resources.
/// SQL can be compiled into reusable Statement objects, or executed directly.
///
/// A Database object can be passed between threads, but should not be used concurrently from multiple threads.
/// Otherwise SQL exectured from one thread may affect the other's. For example, one thread might close a transaction
/// opened by another.
///
public class Database: NSObject {
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Initialization
    
    /// :returns: A Database whose contents are stored in-memory, and discarded when the Database is released.
    public class func newInMemoryDatabase() -> Database {
        return Database()
    }
        
    /// :returns: A Database whose contents are stored in a temporary location on disk, and discarded when the Database
    ///           is closed.
    public class func newTemporaryDatabase() -> Database {
        return Database(path:"")
    }
    
    /// :returns: An in-memory Database.
    public convenience override init() {
        self.init(path:":memory:")
    }
    
    /// :param: path    The location of the database on disk. The empty string will create a temporary Database, and
    ///                 the special path ':memory:' creates an in-memory database.
    ///
    /// :returns: A Database whose contents are stored at the given path on disk.
    public init(path:String) {
        self.path = path
    }
    
    deinit {
        if sqliteDatabase != nil {
            NSLog("Database object not closed before deinitialization!")
            
            sqlite3_close(sqliteDatabase)
            sqliteDatabase = nil
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
    // MARK:  Open
    
    var sqliteDatabase : SQLiteDBPointer = nil
    
    /// :returns: true if the database has been opened via '.open(error:)'
    public var isOpen : Bool {
        return sqliteDatabase != nil
    }
    
    /// Opens the database, allowing statements and queries to be executed against it.
    ///
    /// :param:     error   An error pointer to set if an error occurs. May be `nil`.
    /// :returns:           true if the database was opened, false otherwise. On error, an NSError object will be
    ///                     provided via the `error` parameter.
    ///
    public func open(error:NSErrorPointer) -> Bool {
        if isOpen {
            NSException(name: NSInternalInconsistencyException,
                        reason: "Database '\(path)' is already open",
                        userInfo: nil).raise()
        }
        
        var sqliteDb : SQLiteDBPointer = nil
        var result = sqlite3_open(path.cStringUsingEncoding(NSUTF8StringEncoding)!, &sqliteDb)
        if result != SQLITE_OK {
            if error != nil {
                error.memory = errorFromSQLiteResultCode(result)
            }
            
            sqlite3_close(sqliteDb)
            sqliteDb = nil
        }
        
        sqliteDatabase = sqliteDb
        return result == SQLITE_OK
    }
    

    /// Closes the database and any open Statement objects. Databases should always be closed, otherwise memory leaks
    /// may occur.
    ///
    /// :param:     error   An error pointer to set if an error occurs. May be `nil`.
    /// :returns:           true if the database was closed, false otherwise. On error, an NSError object will be
    ///                     provided via the `error` parameter.
    public func close(error:NSErrorPointer) -> Bool {
        if !isOpen {
            if error != nil {
                error.memory = SquealErrorCode.DatabaseClosed.asError()
            }
            return false
        }
        
        // close all prepared statements
        for weakStatement in statements {
            if let statement = weakStatement.statement {
                if statement.isOpen {
                    statement.close()
                }
            }
        }
        
        statements.removeAll(keepCapacity: true)
        
        let result = sqlite3_close(sqliteDatabase)
        if result != SQLITE_OK {
            if error != nil {
                error.memory = errorFromSQLiteResultCode(result)
            }
            return false
        }
        
        sqliteDatabase = nil
        return true
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Statements
    
    private class WeakStatement {
        
        private weak var statement : Statement?
        
        init(_ statement:Statement) {
            self.statement = statement
        }
        
    }
    
    private var statements = [WeakStatement]()
    
    func statementWillClose(statement:Statement) {
        statements = statements.filter {
            $0.statement != nil && $0.statement != statement
        }
    }

    private func prepareSQLiteStatement(sqlString:String, error:NSErrorPointer) -> SQLiteStatementPointer {
        if sqliteDatabase == nil {
            if error != nil {
                error.memory = SquealErrorCode.DatabaseClosed.asError()
            }
            return nil
        }
        
        var cString = sqlString.cStringUsingEncoding(NSUTF8StringEncoding)
        var sqliteStatement : SQLiteStatementPointer = nil
        
        var resultCode = sqlite3_prepare_v2(sqliteDatabase,
                                            cString!,
                                            -1,
                                            &sqliteStatement,
                                            nil)
        if resultCode != SQLITE_OK {
            if error != nil {
                error.memory = errorFromSQLiteResultCode(resultCode)
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
    /// :returns:               The compiled SQL as a Statement. This Statement must be closed when it is no longer
    ///                         needed. On error, `nil` will be returned and an NSError object will be provided via the
    ///                         `error` parameter.
    ///
    public func prepareStatement(sqlString:String, error:NSErrorPointer) -> Statement? {
        let sqliteStatement = prepareSQLiteStatement(sqlString, error:error)
        if sqliteStatement == nil {
            return nil
        }
        
        let statement = Statement(database: self, sqliteStatement: sqliteStatement)
        statements.append(WeakStatement(statement))
        return statement
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
    public func execute(sqlString:String, error:NSErrorPointer) -> Bool {
        if let statement = prepareStatement(sqlString, error:error) {
            let result = statement.execute(error)
            statement.close()
            return result
        } else {
            return false
        }
    }
    
    /// Returns the id of the last row inserted into the database via this Database object. This is useful after
    /// executing an INSERT statement, but undefined at other times.
    public var lastInsertedRowId : RowId {
        if !isOpen {
            return 0
        }
            
        return sqlite3_last_insert_rowid(self.sqliteDatabase)
    }
    
    /// Returns the number of rows changed by the last statement executed via this Database object. This is useful after
    /// executing an UPDATE or DELETE statement, but undefined at other times.
    public var numberOfChangedRows : Int {
        if !isOpen {
            return 0
        }
        
        return Int(sqlite3_changes(self.sqliteDatabase))
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Query
    
    ///
    /// Prepares a SQL statement and binds the given parameters to it.
    ///
    /// :param:     sqlString   The SQL query to prepare.
    /// :param:     parameters  Parameters to bind to the statement.
    /// :param:     error       An error pointer to set if an error occurs. May be `nil`.
    /// :returns:               The prepared statement, `nil` otherwise. On error, an NSError object will be
    ///                         provided via the `error` parameter.
    ///
    public func query(sqlString:String, parameters:[Bindable?]? = nil, error:NSErrorPointer) -> Statement? {
        if let statement = prepareStatement(sqlString, error:error) {
            if parameters?.count > 0 {
                var boundSuccessfully = statement.bind(parameters!, error:error)
                if !boundSuccessfully {
                    statement.close()
                    return nil
                }
            }
            
            return statement;
        } else {
            return nil
        }
    }

}
