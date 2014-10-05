import Foundation
import sqlite3

typealias SQLiteStatementPointer = COpaquePointer

///
/// Statements are used to update the database, query data, and read results. Statements are like methods and can accept
/// parameters. This makes it easy to escape SQL values, as well as reuse statements for optimal performance.
///
/// Statements are prepared from a Database object.
///
public class Statement : NSObject {
    
    private weak var database : Database?
    private var sqliteStatement : SQLiteStatementPointer
    
    init(database:Database, sqliteStatement:SQLiteStatementPointer) {
        self.database = database
        self.sqliteStatement = sqliteStatement
        
        parameterCount = Int(sqlite3_bind_parameter_count(sqliteStatement))
        
        var columnNames = [String]()
        var columnCount = sqlite3_column_count(sqliteStatement)
        for columnIndex in 0..<columnCount {
            let columnName = sqlite3_column_name(sqliteStatement, columnIndex)
            if columnName != nil {
                if let columnNameString = NSString(UTF8String: columnName) {
                    columnNames.append(columnNameString)
                    continue
                }
            }
            
            // add an empty string so the column indices stay the same
            columnNames.append("")
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
                       code:    SquealErrorCode.UnknownBindParameter.rawValue,
                       userInfo:[ NSLocalizedDescriptionKey : localizedDescription ])
        
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
    public func bindStringValue(stringValue:String, atIndex index:Int, error:NSErrorPointer) -> Bool {
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
    public func bindStringValue(stringValue:String, named name:String, error:NSErrorPointer) -> Bool {
        if let parameterIndex = indexOfParameterNamed(name) {
            return bindStringValue(stringValue, atIndex: parameterIndex, error: error)
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
    // MARK:  BLOB Parameters
    
    /// Binds an NSData value to the parameter at the 1-based index.
    ///
    /// :param:     blobValue       The value to bind.
    /// :param:     atIndex         The 1-based index of the parameter.
    /// :param:     error           An error pointer.
    ///
    /// :returns:   `true` if the parameter was bound, `false` otherwise.
    ///
    public func bindBlobValue(blobValue:NSData, atIndex index:Int, error:NSErrorPointer) -> Bool {
        let negativeOne = UnsafeMutablePointer<Int>(bitPattern: -1)
        let opaquePointer = COpaquePointer(negativeOne)
        let transient = CFunctionPointer<((UnsafeMutablePointer<()>) -> Void)>(opaquePointer)
        
        var resultCode: Int32
        if blobValue.bytes != nil {
            resultCode = sqlite3_bind_blob(sqliteStatement, Int32(index), blobValue.bytes, Int32(blobValue.length), transient)
        } else {
            resultCode = sqlite3_bind_zeroblob(sqliteStatement, Int32(index), 0);
        }
        
        if resultCode != SQLITE_OK {
            if error != nil {
                error.memory = errorFromSqliteResultCode(database!.sqliteDatabase, resultCode)
            }
            return false
        }
        
        return true
    }
    
    /// Binds a BLOB value to a named parameter.
    ///
    /// :param:     blobValue       The value to bind.
    /// :param:     named           The name of the parameter to bind.
    /// :param:     error           An error pointer.
    ///
    /// :returns:   `true` if the parameter was bound, `false` otherwise.
    ///
    public func bindBlobValue(blobValue:NSData, named name:String, error:NSErrorPointer) -> Bool {
        if let parameterIndex = indexOfParameterNamed(name) {
            return bindBlobValue(blobValue, atIndex: parameterIndex, error: error)
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
        return NSString(UTF8String:columnTextI)
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
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK: BLOB Parameters

    public func blobValue(columnName:String) -> NSData? {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return blobValueAtIndex(columnIndex)
        } else {
            return nil
        }
    }
    
    public func blobValueAtIndex(columnIndex:Int) -> NSData? {
        if sqliteStatement == nil {
            return nil
        }
        
        // sqlite3_column_blob returns NULL for zero-length blobs. This means its not possible to detect NULL BLOB
        // columns except by type.
        let columnType = sqlite3_column_type(sqliteStatement, Int32(columnIndex))
        if columnType == SQLITE_NULL {
            return nil
        }
        
        let columnBlob = sqlite3_column_blob(sqliteStatement, Int32(columnIndex))
        if columnBlob == nil {
            return NSData()
        }
        
        let columnBytes = sqlite3_column_bytes(sqliteStatement, Int32(columnIndex))
        return NSData(bytes: columnBlob, length: Int(columnBytes))
    }
    
}

// =====================================================================================================================
// MARK:-  SequenceType

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