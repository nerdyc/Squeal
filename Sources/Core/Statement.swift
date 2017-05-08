import Foundation
import Clibsqlite3

typealias SQLiteStatementPointer = OpaquePointer

let SQUEAL_STATIC = unsafeBitCast(0, to: sqlite3_destructor_type.self)
let SQUEAL_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

///
/// Enumeration of all SQLite column types.
///
public enum SQLiteColumnType: Int {
    case integer
    case float
    case text
    case blob
    case null
    
    static func fromSQLiteColumnType(_ columnType:Int32) -> SQLiteColumnType {
        switch columnType {
        case SQLITE_INTEGER:
            return .integer
        case SQLITE_TEXT:
            return .text
        case SQLITE_NULL:
            return .null
        case SQLITE_FLOAT:
            return .float
        case SQLITE_BLOB:
            return .blob
        default:
            return .text
        }
    }
}

///
/// Statements are used to update the database, query data, and read results. Statements are like methods and can accept
/// parameters. This makes it easy to escape SQL values, as well as reuse statements for optimal performance.
///
/// Statements are prepared from a Database object.
///
open class Statement {
    
    // A strong reference to the database to ensure it isn't closed before all statements have been finalized.
    fileprivate let database:Database
    fileprivate let sqliteStatement:SQLiteStatementPointer?
    
    init(database:Database, sqliteStatement:SQLiteStatementPointer) {
        self.database = database
        self.sqliteStatement = sqliteStatement
        
        parameterCount = Int(sqlite3_bind_parameter_count(sqliteStatement))
        
        var columnNames = [String]()
        let columnCount = sqlite3_column_count(sqliteStatement)
        for columnIndex in 0..<columnCount {
            let columnName = sqlite3_column_name(sqliteStatement, columnIndex)
            if columnName != nil {
                if let columnNameString = NSString(utf8String: columnName!) {
                    columnNames.append(columnNameString as String)
                    continue
                }
            }
            
            // add an empty string so the column indices stay the same
            columnNames.append("")
        }
        self.columnNames = columnNames
    }
    
    deinit {
        let result = sqlite3_finalize(sqliteStatement)
        if result != SQLITE_OK {
            NSLog("Error closing statement (resultCode: \(result)): \(database.sqliteError.localizedDescription)")
        }
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Parameters
    
    /// The number of parameters accepted by the statement.
    open let parameterCount : Int
    
    /// Clears all parameter values bound to the statement. All parameters will be NULL after this call.
    open func clearParameters() {
        if sqliteStatement != nil {
            sqlite3_clear_bindings(sqliteStatement)
        }
    }
    
    /// Determines the 1-based index for a given parameter name. In sqlite, named parameters are simply aliases to
    /// index-based parameters.
    ///
    /// - Parameter name: The parameter name.
    /// - Returns: The 1-based index of a named parameter, or `nil` if no parameter is found with the given name.
    open func indexOfParameterNamed(_ name:String) -> Int? {
        if let cString = name.cString(using: String.Encoding.utf8) {
            let index = sqlite3_bind_parameter_index(sqliteStatement, cString)
            if index > 0 {
                return Int(index)
            }
        }
        
        return nil
    }
    
    fileprivate func unknownBindParameterError(_ name:String) -> NSError {
        let localizedDescription = SquealErrorCode.unknownBindParameter.localizedDescription + ": " + name
        return NSError(domain:  SquealErrorDomain,
                       code:    SquealErrorCode.unknownBindParameter.rawValue,
                       userInfo:[ NSLocalizedDescriptionKey : localizedDescription ])
        
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  String Parameters
    
    /// Binds a string to the parameter at the 1-based index.
    ///
    /// - Parameters:
    ///   - stringValue: The value to bind.
    ///   - index: The index of the parameter to bind.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    open func bindStringValue(_ stringValue:String, atIndex index:Int) throws {
        let cString = stringValue.cString(using: String.Encoding.utf8)
        
        let resultCode = sqlite3_bind_text(sqliteStatement, Int32(index), cString!, -1, SQUEAL_TRANSIENT)
        if resultCode != SQLITE_OK {
            throw database.sqliteError
        }
    }
    
    /// Binds a string value to a named parameter.
    ///
    /// - Parameters:
    ///   - stringValue: The value to bind.
    ///   - name: The name of the parameter to bind.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    open func bindStringValue(_ stringValue:String, named name:String) throws {
        guard let parameterIndex = indexOfParameterNamed(name) else {
            throw unknownBindParameterError(name)
        }
        
        try bindStringValue(stringValue, atIndex: parameterIndex)
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Int Parameters
    
    /// Binds an Int to the parameter at the 1-based index.
    ///
    /// - Parameters:
    ///   - intValue: The value to bind.
    ///   - index: The index of the parameter to bind.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    open func bindIntValue(_ intValue:Int, atIndex index:Int) throws {
        try bindInt64Value(Int64(intValue), atIndex: index)
    }
    
    /// Binds an Int value to a named parameter.
    ///
    /// - Parameters:
    ///   - intValue: The value to bind.
    ///   - name: The name of the parameter to bind.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    open func bindIntValue(_ intValue:Int, named name:String) throws {
        try bindInt64Value(Int64(intValue), named: name)
    }
    
    /// Binds an Int64 value to the parameter at the 1-based index.
    ///
    /// - Parameters:
    ///   - int64Value: The value to bind.
    ///   - index: The index of the parameter to bind.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    open func bindInt64Value(_ int64Value:Int64, atIndex index:Int) throws {
        let resultCode = sqlite3_bind_int64(sqliteStatement, Int32(index), int64Value)
        if resultCode != SQLITE_OK {
            throw database.sqliteError
        }
    }
    
    /// Binds an Int64 value to a named parameter.
    ///
    /// - Parameters:
    ///   - int64Value: The value to bind.
    ///   - name: The name of the parameter to bind.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    open func bindInt64Value(_ int64Value:Int64, named name:String) throws {
        guard let parameterIndex = indexOfParameterNamed(name) else {
            throw unknownBindParameterError(name)
        }
        
        try bindInt64Value(int64Value, atIndex: parameterIndex)
    }
    
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Double Parameters
    
    /// Binds a Double value to the parameter at the 1-based index.
    ///
    /// - Parameters:
    ///   - doubleValue: The value to bind.
    ///   - index: The index of the parameter to bind.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    open func bindDoubleValue(_ doubleValue:Double, atIndex index:Int) throws {
        let resultCode = sqlite3_bind_double(sqliteStatement, Int32(index), doubleValue)
        if resultCode != SQLITE_OK {
            throw database.sqliteError
        }
    }

    /// Binds a Double value to a named parameter.
    ///
    /// - Parameters:
    ///   - doubleValue: The value to bind.
    ///   - name: The name of the parameter to bind.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    open func bindDoubleValue(_ doubleValue:Double, named name:String) throws {
        guard let parameterIndex = indexOfParameterNamed(name) else {
            throw unknownBindParameterError(name)
        }
        
        try bindDoubleValue(doubleValue, atIndex: parameterIndex)
    }
    
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Bool Parameters
    
    /// Binds a Bool value to the parameter at the 1-based index.
    ///
    /// - Parameters:
    ///   - boolValue: The value to bind.
    ///   - index: The index of the parameter to bind.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    open func bindBoolValue(_ boolValue:Bool, atIndex index:Int) throws {
        let resultCode = sqlite3_bind_int(sqliteStatement, Int32(index), Int32(boolValue ? 1 : 0))
        if resultCode != SQLITE_OK {
            throw database.sqliteError
        }
    }
    
    /// Binds a Bool value to a named parameter.
    ///
    /// - Parameters:
    ///   - boolValue: The value to bind.
    ///   - name: The name of the parameter to bind.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    open func bindBoolValue(_ boolValue:Bool, named name:String) throws {
        guard let parameterIndex = indexOfParameterNamed(name) else {
            throw unknownBindParameterError(name)
        }
        
        try bindBoolValue(boolValue, atIndex: parameterIndex)
    }
    
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  BLOB Parameters
    
    /// Binds a BLOB value to the parameter at the 1-based index.
    ///
    /// - Parameters:
    ///   - blobValue: The value to bind.
    ///   - index: The index of the parameter to bind.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    open func bindBlobValue(_ blobValue:Data, atIndex index:Int) throws {
        let dataValue = blobValue as NSData
        var resultCode: Int32
        if dataValue.length > 0 {
            resultCode = sqlite3_bind_blob(sqliteStatement, Int32(index), dataValue.bytes, Int32(dataValue.length), SQUEAL_TRANSIENT)
        } else {
            resultCode = sqlite3_bind_zeroblob(sqliteStatement, Int32(index), 0);
        }
        
        if resultCode != SQLITE_OK {
            throw database.sqliteError
        }
    }
    
    /// Binds a BLOB value to a named parameter.
    ///
    /// - Parameters:
    ///   - blobValue: The value to bind.
    ///   - name: The name of the parameter to bind.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    open func bindBlobValue(_ blobValue:Data, named name:String) throws {
        guard let parameterIndex = indexOfParameterNamed(name) else {
            throw unknownBindParameterError(name)
        }
        
        try bindBlobValue(blobValue, atIndex: parameterIndex)
    }
    
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Null Parameters
    
    /// Binds a NULL value to the parameter at the 1-based index.
    ///
    /// - Parameters:
    ///   - index: The index of the parameter to bind.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    open func bindNullParameter(atIndex index:Int) throws {
        let resultCode = sqlite3_bind_null(sqliteStatement, Int32(index))
        if resultCode != SQLITE_OK {
            throw database.sqliteError
        }
    }

    /// Binds a NULL value to a named parameter.
    ///
    /// - Parameters:
    ///   - name: The name of the parameter to bind.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    open func bindNullParameter(_ name:String) throws {
        guard let parameterIndex = indexOfParameterNamed(name) else {
            throw unknownBindParameterError(name)
        }
        
        try bindNullParameter(atIndex:parameterIndex)
    }
    
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Execute
    
    /// Advances to the next row of results. Statements begin before the first row of data, and iterate through the
    /// results through this method.
    ///
    /// For statements that return no results (e.g. anything other than a `SELECT`), use the `execute()` method.
    ///
    /// - Returns: `true` if a new result is available, `false` if the end of the result set is reached.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    open func next() throws -> Bool {
        switch sqlite3_step(sqliteStatement) {
        case SQLITE_DONE:
            // no more steps
            return false
        case SQLITE_ROW:
            // more rows to process
            return true
        default:
            throw database.sqliteError
        }
    }
    
    public typealias StatementBlock = (Statement) throws -> Void
    
    /// Executes the statement, optionally calling a block after each step.
    ///
    /// - Parameters:
    ///     - block: A block to call after each execution step.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    open func execute(_ block:StatementBlock = { _ in }) throws {
        while try next() {
            try block(self)
        }
    }
    
    /// Resets the statement so it can be executed again. Parameters are NOT cleared. To clear them call
    /// `clearParameters()` after this method.
    ///
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    open func reset() throws {
        let resultCode = sqlite3_reset(sqliteStatement)
        if resultCode != SQLITE_OK {
            throw errorFromSQLiteErrorCode(resultCode, message: "Failed to reset statement (resultCode: \(resultCode))")
        }
    }
    
    
    /// Advances to the next row calls the given block, and returns the result. Useful for processing a single row at a
    /// time.
    ///
    /// - Parameters:
    ///     - block: A block to filter the row.
    /// - Returns: The result of the block, or `nil` if the end of the result set is reached.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    open func selectNextRow<T>(_ block: (Statement)->T) throws -> T? {
        guard try next() else {
            return nil
        }
        
        return block(self)
    }
    
    /// Iterates through all remaining rows, filters them through the given block, and returns all rows in an array.
    ///
    /// - Parameters:
    ///     - block: A block to filter the row.
    /// - Returns: The result of processing the rows, or an empty array if now rows are left.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    open func selectRows<T>(_ block: (Statement)->T) throws -> [T] {
        var results = [T]()
        while try next() {
            let value = block(self)
            results.append(value)
        }
        return results
    }
    
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Columns
    
    /// The names of each column selected by this statement, or an empty array if the statement is not a SELECT.
    open let columnNames : [String]
    
    /// The number of columns in each row selected by this statement.
    open var columnCount : Int {
        if sqliteStatement == nil {
            return 0
        }
        
        return columnNames.count
    }
    
    /// Returns the 0-based index of a column from its name.
    ///
    /// - Parameter columnName: The name of the column
    /// - Returns: The 0-based index of the column in each row, or nil if not found.
    open func indexOfColumnNamed(_ columnName:String) -> Int? {
        return columnNames.index(of: columnName)
    }
    
    /// Returns the name of the column at the given 0-based index.
    ///
    /// - Parameter columnIndex: The column index.
    /// - Returns: The column name.
    open func nameOfColumnAtIndex(_ columnIndex:Int) -> String {
        return columnNames[columnIndex]
    }
    
    /// Returns the name of the column at the given 0-based index.
    ///
    /// - Parameter columnIndex: The column index.
    /// - Returns: The column name.
    open func columnNameAtIndex(_ columnIndex:Int) -> String {
        return columnNames[columnIndex]
    }
    
    /// Returns the type of the column at the given 0-based index.
    ///
    /// - Parameter columnIndex: A column index.
    /// - Returns: The column type.
    open func typeOfColumnAtIndex(_ columnIndex:Int) -> SQLiteColumnType {
        let columnType = sqlite3_column_type(sqliteStatement, Int32(columnIndex))
        return SQLiteColumnType.fromSQLiteColumnType(columnType)
    }
    
    /// Returns the type of the column with the given name.
    ///
    /// - Parameter columnName: The column name
    /// - Returns: The column type.
    open func typeOfColumnNamed(_ columnName:String) -> SQLiteColumnType {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return typeOfColumnAtIndex(columnIndex)
        } else {
            fatalError("Column named '\(columnName)' not found")
        }
    }
    
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK: Current Row
    
    /// All values of the current row, as a Dictionary.
    open var dictionaryValue: [String:Bindable] {
        var currentRow = [String:Bindable]()
        for columnIndex in 0..<(columnCount) {
            let columnName = nameOfColumnAtIndex(columnIndex)
            currentRow[columnName] = valueAtIndex(columnIndex)
        }
        return currentRow
    }
    
    /// All values of the current row in an array.
    open var values: [Bindable?] {
        var currentRowValues = [Bindable?]()
        for columnIndex in 0..<(columnCount) {
            currentRowValues.append(valueAtIndex(columnIndex))
        }
        return currentRowValues
    }

    /// Returns the value of a column by name. The SQLite column type is used to determine how to read the value.
    ///
    /// - Parameter columnName: The name of the column whose value is returned.
    /// - Returns: The value of the column (as determined by SQLite).
    open func valueOf(_ columnName:String) -> Bindable? {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return valueAtIndex(columnIndex)
        } else {
            return nil;
        }
    }
    
    
    /// Returns the value of the column with the given name.
    ///
    /// - Parameter columnName: A column name.
    open subscript(columnName:String) -> Bindable? {
        return valueOf(columnName)
    }
    
    /// Return the value of the column at the given 0-based index.
    ///
    /// - Parameter columnIndex: The column's 0-based index.
    /// - Returns: The value of the column, based on the type determined by sqlite.
    open func valueAtIndex(_ columnIndex:Int) -> Bindable? {
        switch typeOfColumnAtIndex(columnIndex) {
        case .integer:
            return int64ValueAtIndex(columnIndex)
        case .text:
            return stringValueAtIndex(columnIndex)
        case .float:
            return doubleValueAtIndex(columnIndex)
        case .blob:
            return blobValueAtIndex(columnIndex) as Bindable?
        case .null:
            return nil
        }
    }
    
    /// The value of the column at the given 0-based index.
    ///
    /// - Parameter columnIndex: The column's 0-based index.
    open subscript(columnIndex:Int) -> Bindable? {
        return valueAtIndex(columnIndex)
    }
    
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Integer
    
    /// Returns the Int value of a column by name.
    ///
    /// - Parameter columnName: A column name.
    /// - Returns: The Int value of the column, or `nil` if the column is NULL or doesn't exist.
    open func intValue(_ columnName:String) -> Int? {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return intValueAtIndex(columnIndex)
        } else {
            return nil
        }
    }

    /// Returns the Int value of the column at the given 0-based index.
    ///
    /// - Parameter columnIndex: A 0-based column index.
    /// - Returns: The Int value of the column, or `nil` if the column is NULL or doesn't exist.
    open func intValueAtIndex(_ columnIndex:Int) -> Int? {
        if sqliteStatement == nil {
            return nil
        }
        
        if sqlite3_column_type(sqliteStatement, Int32(columnIndex)) == SQLITE_NULL {
            return nil
        }
        
        return Int(sqlite3_column_int64(sqliteStatement, Int32(columnIndex)))
    }

    /// Returns the Int64 value of a column by name.
    ///
    /// - Parameter columnName: A column name.
    /// - Returns: The Int64 value of the column, or `nil` if the column is NULL or doesn't exist.
    open func int64Value(_ columnName:String) -> Int64? {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return int64ValueAtIndex(columnIndex)
        } else {
            return nil
        }
    }
    
    /// Returns the Int64 value of the column at the given 0-based index.
    ///
    /// - Parameter columnIndex: A 0-based column index.
    /// - Returns: The Int64 value of the column, or `nil` if the column is NULL or doesn't exist.
    open func int64ValueAtIndex(_ columnIndex:Int) -> Int64? {
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
    
    /// Returns the Double value of a column by name.
    ///
    /// - Parameter columnName: A column name.
    /// - Returns: The Double value of the column, or `nil` if the column is NULL or doesn't exist.
    open func doubleValue(_ columnName:String) -> Double? {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return realValueAtIndex(columnIndex)
        } else {
            return nil
        }
    }

    /// Returns the Double value of the column at the given 0-based index.
    ///
    /// - Parameter columnIndex: A 0-based column index.
    /// - Returns: The Double value of the column, or `nil` if the column is NULL or doesn't exist.
    open func doubleValueAtIndex(_ columnIndex:Int) -> Double? {
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
    
    /// Returns the String value of a column by name.
    ///
    /// - Parameter columnName: A column name.
    /// - Returns: The String value of the column, or `nil` if the column is NULL or doesn't exist.
    open func stringValue(_ columnName:String) -> String? {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return stringValueAtIndex(columnIndex)
        } else {
            return nil
        }
    }
    
    /// Returns the String value of the column at the given 0-based index.
    ///
    /// - Parameter columnIndex: A 0-based column index.
    /// - Returns: The String value of the column, or `nil` if the column is NULL or doesn't exist.
    open func stringValueAtIndex(_ columnIndex:Int) -> String? {
        if sqliteStatement == nil {
            return nil
        }
        
        guard let columnText = sqlite3_column_text(sqliteStatement, Int32(columnIndex)) else {
            return nil
        }
        
        let columnTextI = UnsafeRawPointer(columnText).assumingMemoryBound(to: Int8.self)
        return NSString(utf8String:columnTextI) as String?
    }
    
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Boolean
    
    /// Returns the Bool value of a column by name.
    ///
    /// - Parameter columnName: A column name.
    /// - Returns: The Bool value of the column, or `nil` if the column is NULL or doesn't exist.
    open func boolValue(_ columnName:String) -> Bool? {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return boolValueAtIndex(columnIndex)
        } else {
            return nil
        }
    }
    
    /// Returns the Bool value of the column at the given 0-based index.
    ///
    /// - Parameter columnIndex: A 0-based column index.
    /// - Returns: The Bool value of the column, or `nil` if the column is NULL or doesn't exist.
    open func boolValueAtIndex(_ columnIndex:Int) -> Bool? {
        if let intValue = intValueAtIndex(columnIndex) {
            return intValue != 0
        } else {
            return nil
        }
    }
    
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK: BLOB Parameters

    /// Returns the BLOB value of a column by name.
    ///
    /// - Parameter columnName: A column name.
    /// - Returns: The BLOB value of the column, or `nil` if the column is NULL or doesn't exist.
    open func blobValue(_ columnName:String) -> Data? {
        if let columnIndex = indexOfColumnNamed(columnName) {
            return blobValueAtIndex(columnIndex)
        } else {
            return nil
        }
    }
    
    /// Returns the BLOB value of the column at the given 0-based index.
    ///
    /// - Parameter columnIndex: A 0-based column index.
    /// - Returns: The BLOB value of the column, or `nil` if the column is NULL or doesn't exist.
    open func blobValueAtIndex(_ columnIndex:Int) -> Data? {
        if sqliteStatement == nil {
            return nil
        }
        
        // sqlite3_column_blob returns NULL for zero-length blobs. This means its not possible to detect NULL BLOB
        // columns except by type.
        let columnType = sqlite3_column_type(sqliteStatement, Int32(columnIndex))
        if columnType == SQLITE_NULL {
            return nil
        }
        
        guard let columnBlob = sqlite3_column_blob(sqliteStatement, Int32(columnIndex)) else {
            return Data()
        }
        
        let columnBytes = sqlite3_column_bytes(sqliteStatement, Int32(columnIndex))
        return Data(bytes: columnBlob, count: Int(columnBytes))
    }
    
    
}

