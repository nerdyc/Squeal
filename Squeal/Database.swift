import Foundation
import sqlite3

let SQLiteErrorDomain = "sqlite3"
let SquealErrorDomain = "Squeal"

public enum SquealErrorCode: Int {
    
    case Success = 0
    case DatabaseNotOpen
    case DatabaseClosed
    case StatementClosed
    case UnknownBindParameter
    
    public var localizedDescription : String {
        switch self {
            case .Success:
                return "Success"
            case .DatabaseNotOpen:
                return "Database must be open"
            case .DatabaseClosed:
                return "Database has been closed"
            case .UnknownBindParameter:
                return "Unknown parameter to bind"
            case .StatementClosed:
                return "Statement has been closed"
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

// =================================================================================================================
// MARK:- Database

public class Database: NSObject {

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
    
    public let path : String
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Open
    
    private var sqliteDatabase : COpaquePointer = nil
    
    public var isOpen : Bool {
        return sqliteDatabase != nil
    }
    
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
    
    public func prepareStatement(sqlString:String, error:NSErrorPointer) -> Statement? {
        let sqliteStatement = prepareSqliteStatement(sqlString, error:error)
        if sqliteStatement == nil {
            return nil
        }
        
        let statement = Statement(database: self, sqliteStatement: sqliteStatement)
        statements.append(WeakStatement(statement))
        return statement
    }
    
    public func execute(sqlString:String, error:NSErrorPointer) -> Bool {
        if let statement = prepareStatement(sqlString, error:error) {
            let result = statement.execute(error)
            statement.close()
            return result
        } else {
            return false
        }
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Query
    
    public func query(sqlString:String, error:NSErrorPointer) -> Statement? {
        let sqliteStatement = prepareSqliteStatement(sqlString, error:error)
        if sqliteStatement == nil {
            return nil
        }
        
        var statement = Statement(database: self, sqliteStatement: sqliteStatement)
        statements.append(WeakStatement(statement))
        return statement
    }
    
    public func query(sqlString:String, parameters:[Any?]?, error:NSErrorPointer) -> Statement? {
        if let statement = query(sqlString, error:error) {
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

// =================================================================================================================
// MARK:- Statement

private class WeakStatement {
    
    private weak var statement : Statement?
    
    init(_ statement:Statement) {
        self.statement = statement
    }
    
}

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
    
    public var isOpen : Bool {
        return database != nil && sqliteStatement != nil
    }
    
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
    
    public let parameterCount : Int
    
    public func bind(parameters:[Any?], error:NSErrorPointer) -> Bool {
        for parameterIndex in (0..<parameters.count) {
            let bindIndex = parameterIndex + 1 // parameters are bound with 1-based indices
            
            if let parameter = parameters[parameterIndex] {
                switch parameter {
                case let stringParameter as String:
                    return bindStringAtIndex(stringParameter, index: bindIndex, error: error)
                    
                case let intParameter as Int:
                    return bindInt64AtIndex(Int64(intParameter), index: bindIndex, error: error)
                    
                case let boolParameter as Bool:
                    return bindBoolAtIndex(boolParameter, index: bindIndex, error: error)
                    
                case let int64Parameter as Int64:
                    return bindInt64AtIndex(int64Parameter, index: bindIndex, error: error)
                    
                case let doubleParameter as Double:
                    return bindDoubleAtIndex(doubleParameter, index: bindIndex, error: error)
                    
                case let floatParameter as Float:
                    return bindDoubleAtIndex(Double(floatParameter), index: bindIndex, error: error)
                    
                case let int32Parameter as Int32:
                    return bindIntAtIndex(Int(int32Parameter), index: bindIndex, error: error)
                    
                case let int16Parameter as Int16:
                    return bindIntAtIndex(Int(int16Parameter), index: bindIndex, error: error)
                    
                case let int8Parameter as Int8:
                    return bindIntAtIndex(Int(int8Parameter), index: bindIndex, error: error)
                    
                case let uint64Parameter as UInt64:
                    return bindInt64AtIndex(Int64(uint64Parameter), index: bindIndex, error: error)
                    
                case let uint32Parameter as UInt32:
                    return bindInt64AtIndex(Int64(uint32Parameter), index: bindIndex, error: error)
                    
                case let uint16Parameter as UInt16:
                    return bindIntAtIndex(Int(uint16Parameter), index: bindIndex, error: error)
                    
                case let uint8Parameter as UInt8:
                    return bindIntAtIndex(Int(uint8Parameter), index: bindIndex, error: error)
                    
                default:
                    if error != nil {
                        let localizedDescription = "Unsupported parameter (\(parameter)) at index \(parameterIndex)"
                        error.memory = NSError(domain:  SquealErrorDomain,
                                               code:    SquealErrorCode.UnknownBindParameter.toRaw(),
                                               userInfo:[ NSLocalizedDescriptionKey:localizedDescription])
                    }
                    return false
                }
            } else {
                return bindNullAtIndex(bindIndex, error: error)
            }
            
        }
        
        return true
    }

    public func bindStringAtIndex(parameter:String, index:Int, error:NSErrorPointer) -> Bool {
        let cString = parameter.cStringUsingEncoding(NSUTF8StringEncoding)
        
        let negativeOne = UnsafeMutablePointer<Int>(-1)
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
    
    public func bindInt64AtIndex(parameter:Int64, index:Int, error:NSErrorPointer) -> Bool {
        let resultCode = sqlite3_bind_int64(sqliteStatement, Int32(index), parameter)
        if resultCode != SQLITE_OK {
            if error != nil {
                error.memory = errorFromSqliteResultCode(database!.sqliteDatabase, resultCode)
            }
            return false
        }
        
        return true
    }
    
    public func bindIntAtIndex(parameter:Int, index:Int, error:NSErrorPointer) -> Bool {
        let resultCode = sqlite3_bind_int64(sqliteStatement, Int32(index), Int64(parameter))
        if resultCode != SQLITE_OK {
            if error != nil {
                error.memory = errorFromSqliteResultCode(database!.sqliteDatabase, resultCode)
            }
            return false
        }
        
        return true
    }
    
    public func bindDoubleAtIndex(parameter:Double, index:Int, error:NSErrorPointer) -> Bool {
        let resultCode = sqlite3_bind_double(sqliteStatement, Int32(index), parameter)
        if resultCode != SQLITE_OK {
            if error != nil {
                error.memory = errorFromSqliteResultCode(database!.sqliteDatabase, resultCode)
            }
            return false
        }
        
        return true
    }
    
    public func bindBoolAtIndex(parameter:Bool, index:Int, error:NSErrorPointer) -> Bool {
        let resultCode = sqlite3_bind_int(sqliteStatement, Int32(index), Int32(parameter ? 1 : 0))
        if resultCode != SQLITE_OK {
            if error != nil {
                error.memory = errorFromSqliteResultCode(database!.sqliteDatabase, resultCode)
            }
            return false
        }
        
        return true
    }
    
    public func bindNullAtIndex(index:Int, error:NSErrorPointer) -> Bool {
        let resultCode = sqlite3_bind_null(sqliteStatement, Int32(index))
        if resultCode != SQLITE_OK {
            if error != nil {
                error.memory = errorFromSqliteResultCode(database!.sqliteDatabase, resultCode)
            }
            return false
        }
        
        return true
    }
    
    public func clearParameters() {
        if sqliteStatement != nil {
            sqlite3_clear_bindings(sqliteStatement)
        }
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Execute
    
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
    
    public func execute(error:NSErrorPointer) -> Bool {
        if !ensureIsOpen(error) {
            return false
        }
        
        // continue stepping until statement completes or encounters an error
        while true {
            if let hasMore = next(error) {
                if !hasMore {
                    return true;
                }
            } else {
                reset(nil)
                sqlite3_reset(sqliteStatement)
                return false
            }
        }
    }
    
    public func reset(error:NSErrorPointer) -> Bool {
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
        
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Columns
    
    public let columnNames : [String]
    
    public var columnCount : Int {
        if sqliteStatement == nil {
            return 0
        }
        
        return columnNames.count
    }
    
    public func indexOfColumnNamed(columnName:String) -> Int? {
        return find(columnNames, columnName)
    }
    
    public func nameOfColumnAtIndex(columnIndex:Int) -> String? {
        return columnNames[columnIndex]
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Integer
    
    public func integerValue(columnName:String) -> Int64? {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return integerValueAtIndex(columnIndex)
        } else {
            return nil
        }
    }
    
    public func integerValueAtIndex(columnIndex:Int) -> Int64? {
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
    
    public func realValue(columnName:String) -> Double? {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return realValueAtIndex(columnIndex)
        } else {
            return nil
        }
    }

    public func realValueAtIndex(columnIndex:Int) -> Double? {
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
    
    public func stringValue(columnName:String) -> String? {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return stringValueAtIndex(columnIndex)
        } else {
            return nil
        }
    }
    
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
    
}
