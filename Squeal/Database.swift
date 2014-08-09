import Foundation
import sqlite3

let SQLiteErrorDomain = "sqlite3"
let SquealErrorDomain = "Squeal"

public enum SquealErrorCode: Int {
    
    case Success = 0
    case DatabaseNotOpen
    case DatabaseClosed
    case UnknownBindArgument
    
    public var localizedDescription : String {
        switch self {
            case .Success:
                return "Success"
            case .DatabaseNotOpen:
                return "Database must be open"
            case .DatabaseClosed:
                return "Database has been closed"
            case .UnknownBindArgument:
                return "Unknown argument to bind"
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

class WeakResultSet {
    
    private weak var resultSet : ResultSet?
    
    init(_ resultSet:ResultSet) {
        self.resultSet = resultSet
    }
    
}

public class Database: NSObject {

    public init(path:String) {
        self.path = path
    }
    
    deinit {
        if database != nil {
            sqlite3_close(database)
            database = nil
        }
    }
    
    // =================================================================================================================
    // MARK:- Path
    
    public let path : String
    
    // =================================================================================================================
    // MARK:- Open
    
    private var database : COpaquePointer = nil
    
    public var isOpen : Bool {
        return database != nil
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

            error.memory = errorObj
            
            sqlite3_close(sqliteDb)
            sqliteDb = nil
        }
        
        database = sqliteDb
        return result == SQLITE_OK
    }
    
    public func close(error:NSErrorPointer) -> Bool {
        if !isOpen {
            error.memory = SquealErrorCode.DatabaseClosed.asError()
            return false
        }
        
        // close all result sets
        for weakResultSet in resultSets {
            if let resultSet = weakResultSet.resultSet {
                if resultSet.isOpen {
                    resultSet.close()
                }
            }
        }
        
        resultSets.removeAll(keepCapacity: true)
        
        let result = sqlite3_close(database)
        if result != SQLITE_OK {
            error.memory = errorFromSqliteResultCode(database, result)
            return false
        }
        
        database = nil
        return true
    }
    
    // =================================================================================================================
    // MARK:- Execute
    
    private func prepareStatement(sqlString:String, error:NSErrorPointer) -> COpaquePointer {
        var cString = sqlString.cStringUsingEncoding(NSUTF8StringEncoding)
        var statement : COpaquePointer = nil
        
        var resultCode = sqlite3_prepare_v2(database,
                                            cString!,
                                            -1,
                                            &statement,
                                            nil)
        if resultCode != SQLITE_OK {
            error.memory = errorFromSqliteResultCode(database, resultCode)
        }
        
        return statement
    }
    
    public func execute(sqlString:String, error:NSErrorPointer) -> Bool {
        var statement = prepareStatement(sqlString, error:error)
        if statement == nil {
            return false
        }
        
        // execute the statement
        while true {
            var stepResult = sqlite3_step(statement)
            if stepResult == SQLITE_DONE || stepResult == SQLITE_OK {
                break
            }
            
            if stepResult != SQLITE_ROW {
                error.memory = errorFromSqliteResultCode(database, stepResult)
                sqlite3_finalize(statement)
                return false
            }
        }
        
        sqlite3_finalize(statement)
        return true
    }
    
    // =================================================================================================================
    // MARK:- Query
    
    private var resultSets = [WeakResultSet]()
    
    private func resultSetWillClose(resultSet:ResultSet) {
        resultSets = resultSets.filter {
            $0.resultSet != nil && $0.resultSet != resultSet
        }
    }
    
    public func query(sqlString:String, error:NSErrorPointer) -> ResultSet? {
        var statement = prepareStatement(sqlString, error:error)
        if statement == nil {
            return nil
        }
        
        var resultSet = ResultSet(database: self, statement: statement)
        resultSets.append(WeakResultSet(resultSet))
        
        return resultSet
    }
    
    public func query(sqlString:String, arguments:[Any?]?, error:NSErrorPointer) -> ResultSet? {
        let resultSet = query(sqlString, error:error)
        if resultSet == nil {
            return nil
        }
        
        if arguments?.count > 0 {
            var boundSuccessfully = resultSet!.bindArguments(arguments!, error:error)
            if !boundSuccessfully {
                resultSet!.close()
                return nil
            }
        }
        
        return resultSet;
    }
    
}

public enum Result {
    case Advanced
    case End
    case Error
}

public class ResultSet : NSObject {
    
    private weak var database : Database?
    private var statement : COpaquePointer
    
    private init(database:Database, statement:COpaquePointer) {
        self.database = database
        self.statement = statement
        
        var columnNames = [String]()
        var columnCount = sqlite3_column_count(statement)
        for columnIndex in 0..<columnCount {
            let columnName = sqlite3_column_name(statement, columnIndex)
            if columnName != nil {
                columnNames.append(NSString(UTF8String: columnName))
            } else {
                columnNames.append("")
            }
        }
        self.columnNames = columnNames
    }
    
    deinit {
        if statement != nil {
            sqlite3_finalize(statement)
        }
    }
    
    public var isOpen : Bool {
        return database != nil && statement != nil
    }
    
    public func close() {
        if database != nil {
            database?.resultSetWillClose(self)
            
            sqlite3_finalize(statement)
            statement = nil
            database = nil
        }
    }
    
    // =================================================================================================================
    // MARK:- Arguments
    
    func bindArguments(arguments:[Any?], error:NSErrorPointer) -> Bool {
        for argumentIndex in (0..<arguments.count) {
            let bindIndex = Int32(argumentIndex + 1) // parameters are bound with 1-based indices
            
            var resultCode = SQLITE_OK
            if let argument = arguments[argumentIndex] {
                switch argument {
                case let stringArgument as String:
                    let cString = stringArgument.cStringUsingEncoding(NSUTF8StringEncoding)
                    
                    var negativeOne = UnsafeMutablePointer<Int>(-1)
                    var opaquePointer = COpaquePointer(negativeOne)
                    var transient = CFunctionPointer<((UnsafeMutablePointer<()>) -> Void)>(opaquePointer)
                    resultCode = sqlite3_bind_text(statement, bindIndex, cString!, -1, transient)
                    
                case let intArgument as Int:
                    resultCode = sqlite3_bind_int64(statement, bindIndex, Int64(intArgument))
                    
                case let boolArgument as Bool:
                    resultCode = sqlite3_bind_int(statement, bindIndex, Int32(boolArgument ? 1 : 0))
                    
                case let int64Argument as Int64:
                    resultCode = sqlite3_bind_int64(statement, bindIndex, int64Argument)
                    
                case let doubleArgument as Double:
                    resultCode = sqlite3_bind_double(statement, bindIndex, doubleArgument)
                    
                case let floatArgument as Float:
                    resultCode = sqlite3_bind_double(statement, bindIndex, Double(floatArgument))
                    
                case let intArgument as Int32:
                    resultCode = sqlite3_bind_int(statement, bindIndex, intArgument)
                    
                case let intArgument as Int16:
                    resultCode = sqlite3_bind_int(statement, bindIndex, Int32(intArgument))
                    
                case let intArgument as Int8:
                    resultCode = sqlite3_bind_int(statement, bindIndex, Int32(intArgument))
                
                case let int64Argument as UInt64:
                    resultCode = sqlite3_bind_int64(statement, bindIndex, Int64(int64Argument))
                    
                case let intArgument as UInt32:
                    resultCode = sqlite3_bind_int64(statement, bindIndex, Int64(intArgument))
                
                case let intArgument as UInt16:
                    resultCode = sqlite3_bind_int(statement, bindIndex, Int32(intArgument))
                    
                case let intArgument as UInt8:
                    resultCode = sqlite3_bind_int(statement, bindIndex, Int32(intArgument))
                    
                default:
                    let localizedDescription = "Unsupported bind argument (\(argument)) at index \(argumentIndex)"
                    error.memory = NSError(domain:  SquealErrorDomain,
                                           code:    SquealErrorCode.UnknownBindArgument.toRaw(),
                                           userInfo:[ NSLocalizedDescriptionKey:localizedDescription])
                    return false
                }
            } else {
                resultCode = sqlite3_bind_null(statement, bindIndex)
            }
    
            if resultCode != SQLITE_OK {
                error.memory = errorFromSqliteResultCode(database!.database, resultCode)
                return false
            }
        }
        
        return true
    }
    
    // =================================================================================================================
    // MARK:- Iteration
    
    public private(set) var error : NSError?
    
    public func next(error:NSErrorPointer) -> Bool? {
        if statement == nil {
            // closed
            return false
        }
        
        var result = sqlite3_step(statement)
        if result == SQLITE_DONE {
            return false
        }
        
        if result == SQLITE_ROW {
            return true
        }
        
        error.memory = errorFromSqliteResultCode(database!.database, result)
        return false
    }
    
    // =================================================================================================================
    // MARK:- COLUMNS
    
    public let columnNames : [String]
    
    public var columnCount : Int {
        if statement == nil {
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
        if statement == nil {
            return nil
        }
        
        if sqlite3_column_type(statement, Int32(columnIndex)) == SQLITE_NULL {
            return nil
        }
        
        return sqlite3_column_int64(statement, Int32(columnIndex))
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
        if statement == nil {
            return nil
        }
        
        if sqlite3_column_type(statement, Int32(columnIndex)) == SQLITE_NULL {
            return nil
        }

        return sqlite3_column_double(statement, Int32(columnIndex))
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
        if statement == nil {
            return nil
        }
        
        let columnText = sqlite3_column_text(statement, Int32(columnIndex))
        if columnText == nil {
            return nil
        }
        
        let columnTextI = UnsafePointer<Int8>(columnText)
        return NSString.stringWithUTF8String(columnTextI)
    }
    
}
