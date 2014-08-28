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
                       code:    toRaw(),
                       userInfo:[ NSLocalizedDescriptionKey:localizedDescription])
    }
}

private func errorFromSqliteResultCode(database:COpaquePointer, resultCode:Int32) -> NSError {
    var errorMsg = sqlite3_errmsg(database)
    return NSError(domain:  SQLiteErrorDomain,
                   code:    Int(resultCode),
                   userInfo:[ NSLocalizedDescriptionKey:NSString(UTF8String: errorMsg) ])
}

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
    
    private var sqliteDatabase : COpaquePointer = nil
    
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
        
        var sqliteDb : COpaquePointer = nil
        var result = sqlite3_open(path.cStringUsingEncoding(NSUTF8StringEncoding)!, &sqliteDb)
        if result != SQLITE_OK {
            var errorMsg = sqlite3_errmsg(sqliteDb)
            let errorObj = NSError(domain: SQLiteErrorDomain,
                                   code: Int(result),
                                   userInfo: [ NSLocalizedDescriptionKey:NSString(UTF8String: errorMsg) ])

            if error != nil {
                error.memory = errorObj
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
                error.memory = errorFromSqliteResultCode(sqliteDatabase, result)
            }
            return false
        }
        
        sqliteDatabase = nil
        return true
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Statements
    
    private var statements = [WeakStatement]()
    
    private func statementWillClose(statement:Statement) {
        statements = statements.filter {
            $0.statement != nil && $0.statement != statement
        }
    }

    private func prepareSqliteStatement(sqlString:String, error:NSErrorPointer) -> COpaquePointer {
        if sqliteDatabase == nil {
            if error != nil {
                error.memory = SquealErrorCode.DatabaseClosed.asError()
            }
            return nil
        }
        
        var cString = sqlString.cStringUsingEncoding(NSUTF8StringEncoding)
        var sqliteStatement : COpaquePointer = nil
        
        var resultCode = sqlite3_prepare_v2(sqliteDatabase,
                                            cString!,
                                            -1,
                                            &sqliteStatement,
                                            nil)
        if resultCode != SQLITE_OK {
            if error != nil {
                error.memory = errorFromSqliteResultCode(sqliteDatabase, resultCode)
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
        let sqliteStatement = prepareSqliteStatement(sqlString, error:error)
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
    public var lastInsertedRowId : Int64 {
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
    public func query(sqlString:String, parameters:[Bindable?]?, error:NSErrorPointer) -> Statement? {
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

    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Transactions
    
    /// Result type used to commit or rollback transactions and savepoints.
    public enum TransactionResult {
        case Commit
        case Rollback
        case Failed(NSError)
    }

    /// Begins a database transaction by executing a BEGIN TRANSACTION statement. Transactions cannot be nested. If
    /// nested operations are needed, consider using savepoints instead.
    ///
    /// :returns: `true` if the transaction began, `false` otherwise.
    public func beginTransaction(error:NSErrorPointer = nil) -> Bool {
        return execute("BEGIN TRANSACTION", error: error)
    }

    /// Ends the current transaction and discards changes since the transaction began. All savepoints are also rolled
    /// back. See sqlite docs for details on transaction support.
    ///
    /// :returns: `true` if the transaction was rolled back, `false` otherwise.
    public func rollback(error:NSErrorPointer = nil) -> Bool {
        return execute("ROLLBACK", error: error)
    }

    /// Commits the current transaction and persists changes since the transaction began. All savepoints are also
    /// committed. See sqlite docs for details on transaction support.
    ///
    /// :returns: `true` if the transaction was committed, `false` otherwise.
    public func commit(error:NSErrorPointer = nil) -> Bool {
        return execute("COMMIT", error: error)
    }

    ///
    /// Begins a transaction, invokes the provided closure, and uses its result to determine how to terminate the
    /// transaction. Using this method is more concise than creating and managing the transaction yourself. For example:
    /// 
    ///     let result = db.transaction {
    ///         var error : NSError?
    ///         if let rowId = $0.insertInto("people", values:["name":"Agnes Pigott"], error:&error) {
    ///             return .Failed(error)
    ///         }
    ///
    ///         // more SQL statements...
    ///
    ///         return .Commit
    ///     }
    ///
    /// :param: block   The operation to perform within the transaction. It should not close the transaction itself, but
    ///                 instead return a TransactionResult.
    /// :returns:       The result of the transaction. This should nearly always be the same value returned by the
    ///                 block, except when the BEGIN, ROLLBACK, or COMMIT statements fail.
    ///
    public func transaction(block:(db:Database)->TransactionResult) -> TransactionResult {
        var localError : NSError?
        var didBegin = beginTransaction(error: &localError)
        if !didBegin {
            return .Failed(localError!)
        }

        let result = block(db: self)
        switch result {
        case .Commit:
            var didCommit = commit(error: &localError)
            if !didCommit {
                return .Failed(localError!)
            }
        
        case .Rollback:
            var didRollback = rollback(error: &localError)
            if !didRollback {
                return .Failed(localError!)
            }
        case .Failed:
            // Attempt a rollback but preserve the original error
            rollback(error: nil)
            break
        }
        
        return result
    }

    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Savepoints

    /// Begins a database savepoint by executing a SAVEPOINT statement. Savepoints are nearly identical to transactions,
    /// except that they are named, and can be nested. This is useful when factoring large database operations.
    ///
    /// :returns: `true` if the savepoint began, `false` otherwise.
    public func beginSavepoint(savepointName:String, error:NSErrorPointer = nil) -> Bool {
        return execute("SAVEPOINT " + escapeIdentifier(savepointName), error: error)
    }

    /// Rolls back the database to the point where a savepoint was begun. All changes since then are discarded. Nested
    /// savepoints are also rolled back.
    ///
    /// :returns: `true` if the savepoint was rolled back, `false` otherwise.
    public func rollbackSavepoint(savepointName:String, error:NSErrorPointer = nil) -> Bool {
        return execute("ROLLBACK TO SAVEPOINT " + escapeIdentifier(savepointName),
                       error: error)
    }

    /// Commits a savepoint via a RELEASE statement, persisting its changes when the enclosing transaction completes.
    ///
    /// :returns: `true` if the savepoint was committed (released), `false` otherwise.
    public func releaseSavepoint(savepointName:String, error:NSErrorPointer = nil) -> Bool {
        return execute("RELEASE " + escapeIdentifier(savepointName),
                       error: error)
    }

    ///
    /// Begins a savepoint, invokes the provided closure, and uses its result to determine how to terminate the
    /// savepoint. Using this method is more concise than creating and managing the savepoint yourself. For example:
    ///
    ///     let result = db.savepoint("insert agnes") {
    ///         var error : NSError?
    ///         if let rowId = $0.insertInto("people", values:["name":"Agnes Pigott"], error:&error) {
    ///             return .Failed(error)
    ///         }
    ///
    ///         // more SQL statements...
    ///
    ///         return .Commit
    ///     }
    ///
    /// :param: block   The operation to perform within the savepoint. It should not close the savepoint itself, but
    ///                 instead return a TransactionResult.
    /// :returns:       The result of the savepoint. This should nearly always be the same value returned by the
    ///                 block, except when the SAVEPOINT, ROLLBACK TO SAVEPOINT, or RELEASE statements fail.
    ///
    public func savepoint(name:String, block:(db:Database)->TransactionResult) -> TransactionResult {
        var localError : NSError?
        var didBegin = beginSavepoint(name, error: &localError)
        if !didBegin {
            return .Failed(localError!)
        }

        let result = block(db: self)
        switch result {
        case .Commit:
            var didCommit = releaseSavepoint(name, error: &localError)
            if !didCommit {
                return .Failed(localError!)
            }
        case .Rollback:
            var didRollback = rollbackSavepoint(name, error: &localError)
            if !didRollback {
                return .Failed(localError!)
            }
        case .Failed:
            // Attempt a rollback but preserve the original error
            rollbackSavepoint(name, error: &localError)
            break
        }
        
        return result
    }
}

// =====================================================================================================================
// MARK:- Statement

private class WeakStatement {
    
    private weak var statement : Statement?
    
    init(_ statement:Statement) {
        self.statement = statement
    }
    
}

///
/// Statements are used to update the database, query data, and read results. Statements are like methods and can accept
/// parameters. This makes it easy to escape SQL values, as well as reuse statements for optimal performance.
///
/// Statements are prepared from a Database object.
///
public class Statement : NSObject {
    
    private weak var database : Database?
    private var sqliteStatement : COpaquePointer
    
    private init(database:Database, sqliteStatement:COpaquePointer) {
        self.database = database
        self.sqliteStatement = sqliteStatement
        
        parameterCount = Int(sqlite3_bind_parameter_count(sqliteStatement))
        
        var columnNames = [String]()
        var columnCount = sqlite3_column_count(sqliteStatement)
        for columnIndex in 0..<columnCount {
            let columnName = sqlite3_column_name(sqliteStatement, columnIndex)
            if columnName != nil {
                columnNames.append(NSString(UTF8String: columnName))
            } else {
                columnNames.append("")
            }
        }
        self.columnNames = columnNames
    }
    
    deinit {
        if sqliteStatement != nil {
            sqlite3_finalize(sqliteStatement)
        }
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  State
    
    private func ensureIsOpen(error:NSErrorPointer) -> Bool {
        if sqliteStatement == nil {
            if error != nil {
                error.memory = SquealErrorCode.StatementClosed.asError()
            }
            return false
        } else {
            return true
        }
    }
    
    /// :returns: `true` if the Statement can be executed, `false` if it has been closed and reclaimed.
    public var isOpen : Bool {
        return database != nil && sqliteStatement != nil
    }
    
    /// Closes a statement, releasing any resources it retained. Once a Statement is closed, it can no longer be used.
    public func close() {
        if database != nil {
            database?.statementWillClose(self)
            
            sqlite3_finalize(sqliteStatement)
            sqliteStatement = nil
            database = nil
        }
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Parameters
    
    /// The number of parameters accepted by the statement.
    public let parameterCount : Int
    
    /// Clears all parameter values bound to the statement. All parameters will be NULL after this call.
    public func clearParameters() {
        if sqliteStatement != nil {
            sqlite3_clear_bindings(sqliteStatement)
        }
    }
    
    /// :returns: The 1-based index of a named parameter, or `nil` if no parameter is found with the given name.
    public func indexOfParameterNamed(name:String) -> Int? {
        if let cString = name.cStringUsingEncoding(NSUTF8StringEncoding) {
            let index = sqlite3_bind_parameter_index(sqliteStatement, cString)
            if index > 0 {
                return Int(index)
            }
        }
        
        return nil
    }
    
    private func unknownBindParameterError(name:String) -> NSError {
        let localizedDescription = SquealErrorCode.UnknownBindParameter.localizedDescription + ": " + name
        return NSError(domain:  SquealErrorDomain,
            code:    SquealErrorCode.UnknownBindParameter.toRaw(),
            userInfo:[ NSLocalizedDescriptionKey : localizedDescription ])
        
    }
    
    /// Binds an array of parameters to the statement.
    ///
    /// :param:     parameters  The array of parameters to bind.
    /// :param:     error       An error pointer.
    ///
    /// :returns:   `true` if all parameters were bound, `false` otherwise.
    public func bind(parameters:[Bindable?], error:NSErrorPointer) -> Bool {
        for parameterIndex in (0..<parameters.count) {
            let bindIndex = parameterIndex + 1 // parameters are bound with 1-based indices
            
            if let parameter = parameters[parameterIndex] {
                var wasBound = parameter.bindToStatement(self, atIndex: bindIndex, error: error)
                if !wasBound {
                    return false
                }
            } else {
                return bindNullParameter(atIndex:bindIndex, error: error)
            }
            
        }
        
        return true
    }

    /// Binds named parameters using the values from a dictionary.
    ///
    /// :param:     namedParameters  A dictionary of values to bind.
    /// :param:     error            An error pointer.
    ///
    /// :returns:   `true` if all parameters were bound, `false` otherwise.
    public func bind(#namedParameters:[String:Bindable?], error:NSErrorPointer) -> Bool {
        for (name, value) in namedParameters {
            var success = bindParameter(name, value: value, error: error)
            if !success {
                return false
            }
        }
        
        return true
    }
    
    /// Binds a single named parameter.
    ///
    /// :param:     name    The name of the parameter to bind.
    /// :param:     value   The value to bind.
    /// :param:     error   An error pointer.
    ///
    /// :returns:   `true` if the parameter was bound, `false` otherwise.
    ///
    public func bindParameter(name:String, value:Bindable?, error:NSErrorPointer) -> Bool {
        if let bindIndex = indexOfParameterNamed(name) {
            if value != nil {
                let bound = value!.bindToStatement(self, atIndex: bindIndex, error: error)
                if !bound {
                    return false
                }
            } else {
                return bindNullParameter(atIndex:bindIndex, error: error)
            }
        }
        
        return true
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  String Parameters
    
    /// Binds a string value to the parameter at the 1-based index.
    ///
    /// :param:     stringValue     The value to bind.
    /// :param:     atIndex         The 1-based index of the parameter.
    /// :param:     error           An error pointer.
    ///
    /// :returns:   `true` if the parameter was bound, `false` otherwise.
    ///
    public func bindStringParameter(stringValue:String, atIndex index:Int, error:NSErrorPointer) -> Bool {
        let cString = stringValue.cStringUsingEncoding(NSUTF8StringEncoding)
        
        let negativeOne = UnsafeMutablePointer<Int>(bitPattern: -1)
        let opaquePointer = COpaquePointer(negativeOne)
        let transient = CFunctionPointer<((UnsafeMutablePointer<()>) -> Void)>(opaquePointer)
        
        let resultCode = sqlite3_bind_text(sqliteStatement, Int32(index), cString!, -1, transient)
        if resultCode != SQLITE_OK {
            if error != nil {
                error.memory = errorFromSqliteResultCode(database!.sqliteDatabase, resultCode)
            }
            return false
        }
        
        return true
    }
    
    /// Binds a string value to a named parameter.
    ///
    /// :param:     stringValue     The value to bind.
    /// :param:     named           The name of the parameter to bind.
    /// :param:     error           An error pointer.
    ///
    /// :returns:   `true` if the parameter was bound, `false` otherwise.
    ///
    public func bindStringParameter(stringValue:String, named name:String, error:NSErrorPointer) -> Bool {
        if let parameterIndex = indexOfParameterNamed(name) {
            return bindStringParameter(stringValue, atIndex: parameterIndex, error: error)
        } else {
            if error != nil {
                error.memory = unknownBindParameterError(name)
            }
            return false
        }
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Int Parameters
    
    /// Binds an Int value to the parameter at the 1-based index.
    ///
    /// :param:     intValue        The value to bind.
    /// :param:     atIndex         The 1-based index of the parameter.
    /// :param:     error           An error pointer.
    ///
    /// :returns:   `true` if the parameter was bound, `false` otherwise.
    ///
    public func bindIntValue(intValue:Int, atIndex index:Int, error:NSErrorPointer) -> Bool {
        return bindInt64Value(Int64(intValue), atIndex: index, error: error)
    }
    
    /// Binds an Int value to a named parameter.
    ///
    /// :param:     intValue        The value to bind.
    /// :param:     named           The name of the parameter to bind.
    /// :param:     error           An error pointer.
    ///
    /// :returns:   `true` if the parameter was bound, `false` otherwise.
    ///
    public func bindIntValue(intValue:Int, named name:String, error:NSErrorPointer) -> Bool {
        return bindInt64Value(Int64(intValue), named: name, error: error)
    }
    
    /// Binds an Int64 value to the parameter at the 1-based index.
    ///
    /// :param:     int64Value      The value to bind.
    /// :param:     atIndex         The 1-based index of the parameter.
    /// :param:     error           An error pointer.
    ///
    /// :returns:   `true` if the parameter was bound, `false` otherwise.
    ///
    public func bindInt64Value(int64Value:Int64, atIndex index:Int, error:NSErrorPointer) -> Bool {
        let resultCode = sqlite3_bind_int64(sqliteStatement, Int32(index), int64Value)
        if resultCode != SQLITE_OK {
            if error != nil {
                error.memory = errorFromSqliteResultCode(database!.sqliteDatabase, resultCode)
            }
            return false
        }
        
        return true
    }
    
    /// Binds an Int64 value to a named parameter.
    ///
    /// :param:     int64Value      The value to bind.
    /// :param:     named           The name of the parameter to bind.
    /// :param:     error           An error pointer.
    ///
    /// :returns:   `true` if the parameter was bound, `false` otherwise.
    ///
    public func bindInt64Value(int64Value:Int64, named name:String, error:NSErrorPointer) -> Bool {
        if let parameterIndex = indexOfParameterNamed(name) {
            return bindInt64Value(int64Value, atIndex: parameterIndex, error: error)
        } else {
            if error != nil {
                error.memory = unknownBindParameterError(name)
            }
            return false
        }
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Double Parameters
    
    
    /// Binds a Double value to the parameter at the 1-based index.
    ///
    /// :param:     doubleValue     The value to bind.
    /// :param:     atIndex         The 1-based index of the parameter.
    /// :param:     error           An error pointer.
    ///
    /// :returns:   `true` if the parameter was bound, `false` otherwise.
    ///
    public func bindDoubleValue(doubleValue:Double, atIndex index:Int, error:NSErrorPointer) -> Bool {
        let resultCode = sqlite3_bind_double(sqliteStatement, Int32(index), doubleValue)
        if resultCode != SQLITE_OK {
            if error != nil {
                error.memory = errorFromSqliteResultCode(database!.sqliteDatabase, resultCode)
            }
            return false
        }
        
        return true
    }

    /// Binds a Double value to a named parameter.
    ///
    /// :param:     doubleValue     The value to bind.
    /// :param:     named           The name of the parameter to bind.
    /// :param:     error           An error pointer.
    ///
    /// :returns:   `true` if the parameter was bound, `false` otherwise.
    ///
    public func bindDoubleValue(doubleValue:Double, named name:String, error:NSErrorPointer) -> Bool {
        if let parameterIndex = indexOfParameterNamed(name) {
            return bindDoubleValue(doubleValue, atIndex: parameterIndex, error: error)
        } else {
            if error != nil {
                error.memory = unknownBindParameterError(name)
            }
            return false
        }
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Bool Parameters
    
    /// Binds a Bool value to the parameter at the 1-based index.
    ///
    /// :param:     boolValue       The value to bind.
    /// :param:     atIndex         The 1-based index of the parameter.
    /// :param:     error           An error pointer.
    ///
    /// :returns:   `true` if the parameter was bound, `false` otherwise.
    ///
    public func bindBoolValue(boolValue:Bool, atIndex index:Int, error:NSErrorPointer) -> Bool {
        let resultCode = sqlite3_bind_int(sqliteStatement, Int32(index), Int32(boolValue ? 1 : 0))
        if resultCode != SQLITE_OK {
            if error != nil {
                error.memory = errorFromSqliteResultCode(database!.sqliteDatabase, resultCode)
            }
            return false
        }
        
        return true
    }
    
    /// Binds a Bool value to a named parameter.
    ///
    /// :param:     boolValue       The value to bind.
    /// :param:     named           The name of the parameter to bind.
    /// :param:     error           An error pointer.
    ///
    /// :returns:   `true` if the parameter was bound, `false` otherwise.
    ///
    public func bindBoolValue(boolValue:Bool, named name:String, error:NSErrorPointer) -> Bool {
        if let parameterIndex = indexOfParameterNamed(name) {
            return bindBoolValue(boolValue, atIndex: parameterIndex, error: error)
        } else {
            if error != nil {
                error.memory = unknownBindParameterError(name)
            }
            return false
        }
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Null Parameters
    
    /// Binds a NULL value to the parameter at the 1-based index.
    ///
    /// :param:     atIndex         The 1-based index of the parameter.
    /// :param:     error           An error pointer.
    ///
    /// :returns:   `true` if the parameter was bound, `false` otherwise.
    ///
    public func bindNullParameter(atIndex index:Int, error:NSErrorPointer) -> Bool {
        let resultCode = sqlite3_bind_null(sqliteStatement, Int32(index))
        if resultCode != SQLITE_OK {
            if error != nil {
                error.memory = errorFromSqliteResultCode(database!.sqliteDatabase, resultCode)
            }
            return false
        }
        
        return true
    }

    /// Binds a NULL value to a named parameter.
    ///
    /// :param:     named           The name of the parameter to bind.
    /// :param:     error           An error pointer.
    ///
    /// :returns:   `true` if the parameter was bound, `false` otherwise.
    ///
    public func bindNullParameter(name:String, error:NSErrorPointer) -> Bool {
        if let parameterIndex = indexOfParameterNamed(name) {
            return bindNullParameter(atIndex:parameterIndex, error: error)
        } else {
            if error != nil {
                error.memory = unknownBindParameterError(name)
            }
            return false
        }
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Execute
    
    /// Advances to the next row of results. Statements begin before the first row of data, and iterate through the
    /// results through this method.
    ///
    /// For statements that return no results (e.g. anything other than a `SELECT`), use the `execute(error:)` method.
    ///
    /// :param:     error           An error pointer.
    ///
    /// :returns:   `true` if a new result is available, `false` if the end of the result set is reached, or `nil` if
    ///             an error occurred.
    ///
    public func next(error:NSErrorPointer) -> Bool? {
        if !ensureIsOpen(error) {
            return nil
        }
        
        switch sqlite3_step(sqliteStatement) {
        case SQLITE_DONE:
            // no more steps
            return false
        case SQLITE_ROW:
            // more rows to process
            return true
        case let (stepResult):
            // error
            if error != nil {
                error.memory = errorFromSqliteResultCode(database!.sqliteDatabase, stepResult)
            }
            return nil
        }
    }
    
    /// Executes the statement. This is useful for statements like `INSERT` which return no results.
    ///
    /// :param:     error           An error pointer.
    ///
    /// :returns:   `true` if the statement succeeded, `false` if it failed.
    ///
    public func execute(error:NSErrorPointer) -> Bool {
        while true {
            switch next(error) {
            case .Some(true):
                // more steps
                continue
            case .Some(false):
                // no more steps
                return true
            default:
                // error!
                reset()
                return false
            }
        }
    }
    
    /// Resets the statement so it can be executed again. Paramters are NOT cleared. To clear them call
    /// `clearParameters()` after this method.
    ///
    /// :param:     error           An error pointer.
    ///
    /// :returns:   `true` if the statement was reset, `false` otherwise.
    ///
    public func reset(error:NSErrorPointer = nil) -> Bool {
        if !ensureIsOpen(error) {
            return false
        }
        
        var resultCode = sqlite3_reset(sqliteStatement)
        if resultCode != SQLITE_OK {
            if error != nil {
                error.memory = errorFromSqliteResultCode(database!.sqliteDatabase, resultCode)
            }
            return false
        }
        
        return true
    }
    
    /// Executes a query and collects all rows into an array, ignoring errors.
    ///
    /// :param:     collector       A block to process each row, and return a value. The block will be provided the
    ///                             Statement so it can extract the selected values for each row.
    ///
    /// :returns:   An array of the values collected, as returned by the provided block. `[]` will be returned if the
    ///             statement fails. This means that errors cannot be detected.
    ///
    public func collect<T>(collector:(Statement)->(T)) -> [T] {
        if let values = collect(nil, collector:collector) {
            return values
        } else {
            return []
        }
    }
    
    /// Executes a query and collects all rows into an array. Each row of the result set is processed by invoking the
    /// provided block.
    ///
    /// :param:     error           An error pointer.
    /// :param:     collector       A block to process each row, and return a value. The block will be provided the
    ///                             Statement so it can extract the selected values for each row.
    ///
    /// :returns:   An array of the values collected, as returned by the provided block. `nil` will be returned if the
    ///             statement fails.
    ///
    public func collect<T>(error:NSErrorPointer, collector:(Statement)->(T)) -> [T]? {
        var values = [T]()
        while true {
            switch next(error) {
            case .Some(true):
                // more steps
                var value = collector(self)
                values.append(value)
            case .Some(false):
                // no more steps
                return values
            default:
                // error!
                reset()
                return nil
            }
        }
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Columns
    
    /// The names of each column selected by this statement, or an empty array if the statement is not a SELECT.
    public let columnNames : [String]
    
    /// The number of columns in each row selected by this statement.
    public var columnCount : Int {
        if sqliteStatement == nil {
            return 0
        }
        
        return columnNames.count
    }
    
    /// Looks up the index of a column from its name.
    ///
    /// :param:     columnName  The name of the column to search for.
    /// :returns:   The index of the column, or nil if it wasn't found.
    ///
    public func indexOfColumnNamed(columnName:String) -> Int? {
        return find(columnNames, columnName)
    }
    
    /// Gets the name of the column at an index.
    ///
    /// :param:     columnIndex The index of a column
    /// :returns:   The name of the column at the index
    ///
    public func nameOfColumnAtIndex(columnIndex:Int) -> String {
        return columnNames[columnIndex]
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Integer
    
    /// Reads the value of a named column in the current row, as an Int.
    ///
    /// :param:     columnName The name of the column to read.
    /// :returns:   The value of the column, or `nil` if is NULL or the column name is unknown.
    public func intValue(columnName:String) -> Int? {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return intValueAtIndex(columnIndex)
        } else {
            return nil
        }
    }

    /// Reads the value of a column in the current row, as an Int.
    ///
    /// :param:     columnIndex The 0-based index of the column to read.
    /// :returns:   The value of the column, or `nil` if is NULL or the column name is unknown.
    public func intValueAtIndex(columnIndex:Int) -> Int? {
        if sqliteStatement == nil {
            return nil
        }
        
        if sqlite3_column_type(sqliteStatement, Int32(columnIndex)) == SQLITE_NULL {
            return nil
        }
        
        return Int(sqlite3_column_int64(sqliteStatement, Int32(columnIndex)))
    }

    /// Reads the value of a named column in the current row, as a 64-bit integer.
    ///
    /// :param:     columnName The name of the column to read.
    /// :returns:   The value of the column, or `nil` if is NULL or the column name is unknown.
    public func int64Value(columnName:String) -> Int64? {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return int64ValueAtIndex(columnIndex)
        } else {
            return nil
        }
    }
    
    /// Reads the value of a column in the current row, as a 64-bit integer.
    ///
    /// :param:     columnIndex The 0-based index of the column to read.
    /// :returns:   The value of the column, or `nil` if is NULL or the column name is unknown.
    public func int64ValueAtIndex(columnIndex:Int) -> Int64? {
        if sqliteStatement == nil {
            return nil
        }
        
        if sqlite3_column_type(sqliteStatement, Int32(columnIndex)) == SQLITE_NULL {
            return nil
        }
        
        return sqlite3_column_int64(sqliteStatement, Int32(columnIndex))
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Real

    /// Alias for doubleValue(columnName)
    public func realValue(columnName:String) -> Double? {
        return doubleValue(columnName)
    }

    /// Alias for realValueAtIndex(columnIndex)
    public func realValueAtIndex(columnIndex:Int) -> Double? {
        return doubleValueAtIndex(columnIndex)
    }

    /// Reads the value of a named column in the current row, as a Double
    ///
    /// :param:     columnName The name of the column to read.
    /// :returns:   The value of the column, or `nil` if is NULL or the column name is unknown.
    public func doubleValue(columnName:String) -> Double? {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return realValueAtIndex(columnIndex)
        } else {
            return nil
        }
    }

    /// Reads the value of a column in the current row, as a Double.
    ///
    /// :param:     columnIndex The 0-based index of the column to read.
    /// :returns:   The value of the column, or `nil` if is NULL or the column name is unknown.
    public func doubleValueAtIndex(columnIndex:Int) -> Double? {
        if sqliteStatement == nil {
            return nil
        }
        
        if sqlite3_column_type(sqliteStatement, Int32(columnIndex)) == SQLITE_NULL {
            return nil
        }

        return sqlite3_column_double(sqliteStatement, Int32(columnIndex))
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  String
    
    /// Reads the value of a named column in the current row, as a String
    ///
    /// :param:     columnName The name of the column to read.
    /// :returns:   The value of the column, or `nil` if is NULL or the column name is unknown.
    public func stringValue(columnName:String) -> String? {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return stringValueAtIndex(columnIndex)
        } else {
            return nil
        }
    }
    
    /// Reads the value of a column in the current row, as a String.
    ///
    /// :param:     columnIndex The 0-based index of the column to read.
    /// :returns:   The value of the column, or `nil` if is NULL or the column name is unknown.
    public func stringValueAtIndex(columnIndex:Int) -> String? {
        if sqliteStatement == nil {
            return nil
        }
        
        let columnText = sqlite3_column_text(sqliteStatement, Int32(columnIndex))
        if columnText == nil {
            return nil
        }
        
        let columnTextI = UnsafePointer<Int8>(columnText)
        return NSString.stringWithUTF8String(columnTextI)
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Boolean
    
    /// Reads the value of a named column in the current row, as a Bool
    ///
    /// :param:     columnName The name of the column to read.
    /// :returns:   The value of the column, or `nil` if is NULL or the column name is unknown.
    public func boolValue(columnName:String) -> Bool? {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return boolValueAtIndex(columnIndex)
        } else {
            return nil
        }
    }
    
    /// Reads the value of a column in the current row, as a Bool.
    ///
    /// :param:     columnIndex The 0-based index of the column to read.
    /// :returns:   The value of the column, or `nil` if is NULL or the column name is unknown.
    public func boolValueAtIndex(columnIndex:Int) -> Bool? {
        if let intValue = intValueAtIndex(columnIndex) {
            return intValue != 0
        } else {
            return nil
        }
    }
    
}

// -----------------------------------------------------------------------------------------------------------------
// MARK:  SequenceType

extension Statement : SequenceType {
    
    public func generate() -> StatementGenerator {
        var error : NSError?
        if reset(error:&error) {
            return StatementGenerator(statement:self)
        } else {
            return StatementGenerator(statement:self, error:error!)
        }
    }
    
}

public enum Step {
    case Row
    case Error(NSError)
}

public struct StatementGenerator : GeneratorType {
    
    private weak var statement: Statement?
    private var isComplete: Bool = false
    private var error:NSError?
    
    init(statement:Statement) {
        self.statement = statement
    }
    
    init(statement:Statement, error:NSError) {
        self.statement = statement
        self.error = error
    }
    
    public mutating func next() -> Step? {
        if isComplete {
            return nil
        }
        
        if let error = self.error {
            self.isComplete = true
            return Step.Error(error)
        }
        
        if let statement = self.statement {
            var error : NSError?
            switch statement.next(&error) {
            case .Some(true):
                return Step.Row
            case .Some(false):
                self.isComplete = true
                return nil
            default: // nil
                self.isComplete = true
                return Step.Error(error!)
            }
        } else {
            self.isComplete = true
            return nil
        }
    }
}

// =====================================================================================================================
// MARK:- Bindable

/// Protocol for types that can be bound to a Statement parameter.
///
/// Squeal extends types like Int and String to implement this protocol, and you shouldn't need to implement this
/// yourself. However, it may prove convenient to add this to other types, like dates.
public protocol Bindable {

    /// Invoked to bind to a Statement. Implementations should use typed methods like
    /// Statement.bindIntValue(atIndex:error:) to perform the binding.
    ///
    /// This method is called by Statement.bindParameters(parameters:error:), and other methods that bind collections of
    /// parameters en masse.
    func bindToStatement(statement:Statement, atIndex:Int, error:NSErrorPointer) -> Bool
}

extension String : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer) -> Bool {
        return statement.bindStringParameter(self, atIndex: index, error: error)
    }
    
}

extension Int : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer) -> Bool {
        return statement.bindIntValue(self, atIndex: index, error: error)
    }
    
}

extension Int64 : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer) -> Bool {
        return statement.bindInt64Value(self, atIndex: index, error: error)
    }
    
}

extension Int32 : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer) -> Bool {
        return statement.bindIntValue(Int(self), atIndex: index, error: error)
    }
    
}

extension Int16 : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer) -> Bool {
        return statement.bindIntValue(Int(self), atIndex: index, error: error)
    }
    
}

extension Int8 : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer) -> Bool {
        return statement.bindIntValue(Int(self), atIndex: index, error: error)
    }
    
}

extension UInt64 : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer) -> Bool {
        return statement.bindInt64Value(Int64(self), atIndex: index, error: error)
    }
    
}

extension UInt32 : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer) -> Bool {
        return statement.bindInt64Value(Int64(self), atIndex: index, error: error)
    }
    
}

extension UInt16 : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer) -> Bool {
        return statement.bindIntValue(Int(self), atIndex: index, error: error)
    }
    
}

extension UInt8 : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer) -> Bool {
        return statement.bindIntValue(Int(self), atIndex: index, error: error)
    }
    
}

extension Bool : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer) -> Bool {
        return statement.bindBoolValue(self, atIndex: index, error: error)
    }
    
}

extension Double : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer) -> Bool {
        return statement.bindDoubleValue(self, atIndex: index, error: error)
    }
    
}

extension Float : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer) -> Bool {
        return statement.bindDoubleValue(Double(self), atIndex: index, error: error)
    }
    
}