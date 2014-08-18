import Foundation
import sqlite3

let SQLiteErrorDomain = "sqlite3"
let SquealErrorDomain = "Squeal"

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

public class Database: NSObject {
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Initialization
    
    public class func newInMemoryDatabase() -> Database {
        return Database()
    }
    
    public class func newTemporaryDatabase() -> Database {
        return Database(path:"")
    }
    
    public convenience override init() {
        self.init(path:":memory:")
    }
    
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
    
    public var isInMemoryDatabase : Bool {
        return path == ":memory:"
    }

    public var isTemporaryDatabase : Bool {
        return path == ""
    }
    
    public var isPersistentDatabase : Bool {
        return !(isInMemoryDatabase || isTemporaryDatabase)
    }
    
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
    
    public var lastInsertedRowId : Int64 {
        if !isOpen {
            return 0
        }
            
        return sqlite3_last_insert_rowid(self.sqliteDatabase)
    }
    
    public var numberOfChangedRows : Int {
        if !isOpen {
            return 0
        }
        
        return Int(sqlite3_changes(self.sqliteDatabase))
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
    
    public func query(sqlString:String, parameters:[Bindable?]?, error:NSErrorPointer) -> Statement? {
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

// =====================================================================================================================
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
    
    public func clearParameters() {
        if sqliteStatement != nil {
            sqlite3_clear_bindings(sqliteStatement)
        }
    }
    
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

    public func bind(#namedParameters:[String:Bindable?], error:NSErrorPointer) -> Bool {
        for (name, value) in namedParameters {
            var success = bindParameter(name, value: value, error: error)
            if !success {
                return false
            }
        }
        
        return true
    }
    
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
    
    public func bindStringParameter(stringValue:String, atIndex index:Int, error:NSErrorPointer) -> Bool {
        let cString = stringValue.cStringUsingEncoding(NSUTF8StringEncoding)
        
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
    
    public func bindIntValue(intValue:Int, atIndex index:Int, error:NSErrorPointer) -> Bool {
        return bindInt64Value(Int64(intValue), atIndex: index, error: error)
    }
    
    public func bindIntValue(intValue:Int, named name:String, error:NSErrorPointer) -> Bool {
        return bindInt64Value(Int64(intValue), named: name, error: error)
    }

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
    
    public func collect<T>(collector:(Statement)->(T)) -> [T] {
        if let values = collect(nil, collector:collector) {
            return values
        } else {
            return []
        }
    }
    
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
    
    public func intValue(columnName:String) -> Int? {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return intValueAtIndex(columnIndex)
        } else {
            return nil
        }
    }
    
    public func intValueAtIndex(columnIndex:Int) -> Int? {
        if sqliteStatement == nil {
            return nil
        }
        
        if sqlite3_column_type(sqliteStatement, Int32(columnIndex)) == SQLITE_NULL {
            return nil
        }
        
        return Int(sqlite3_column_int64(sqliteStatement, Int32(columnIndex)))
    }

    
    public func int64Value(columnName:String) -> Int64? {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return int64ValueAtIndex(columnIndex)
        } else {
            return nil
        }
    }
    
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
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Boolean
    
    public func boolValue(columnName:String) -> Bool? {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return boolValueAtIndex(columnIndex)
        } else {
            return nil
        }
    }
    
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

public protocol Bindable {
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