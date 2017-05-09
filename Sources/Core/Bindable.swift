import Foundation

// =====================================================================================================================
// MARK:- Bindable

/// Protocol for types that can be bound to a Statement parameter.
///
/// Squeal extends types like Int and String to implement this protocol, and you shouldn't need to implement this
/// yourself. However, it may prove convenient to add this to other types, like dates.
public protocol Bindable {

    /// Invoked to bind the value to a Statement. Implementations should use typed methods like
    /// `Statement.bindIntValue(atIndex:error:)` to perform the binding.
    ///
    /// - Parameters:
    ///   - statement: The Statement to bind to.
    ///   - atIndex: The index at which to bind the value.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    func bindToStatement(_ statement:Statement, atIndex:Int) throws
    
    
    /// Invoked to read a column value from a row. Implementations should use the type-specific methods of `Statement`
    /// to get the appropriate data from the row, and then convert it if necessary.
    ///
    /// - Parameters:
    ///   - statement: The Statement to read the value from.
    ///   - columnIndex: The index of the column to convert.
    /// - Returns: The value of the column at the index.
    static func readColumnValue(_ statement:Statement, atIndex columnIndex:Int) -> Self?
    
}


// =====================================================================================================================
// MARK:- Binable Implementations

extension String : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(stringValue:self, atIndex: index)
    }
    
    public static func readColumnValue(_ statement: Statement, atIndex columnIndex: Int) -> String? {
        return statement.stringValue(atIndex:columnIndex)
    }
    
}

extension Int : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(int64Value:Int64(self), atIndex: index)
    }
    
    public static func readColumnValue(_ statement: Statement, atIndex columnIndex: Int) -> Int? {
        if let intValue = statement.int64Value(atIndex:columnIndex) {
            return Int(intValue)
        } else {
            return nil
        }
    }
    
}

extension Int64 : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(int64Value:self, atIndex: index)
    }
    
    public static func readColumnValue(_ statement: Statement, atIndex columnIndex: Int) -> Int64? {
        return statement.int64Value(atIndex:columnIndex)
    }
    
}

extension Int32 : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(int32Value:self, atIndex: index)
    }
    
    public static func readColumnValue(_ statement: Statement, atIndex columnIndex: Int) -> Int32? {
        return statement.int32Value(atIndex:columnIndex)
    }
    
}

extension Int16 : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(int32Value:Int32(self), atIndex: index)
    }
    
    public static func readColumnValue(_ statement: Statement, atIndex columnIndex: Int) -> Int16? {
        if let intValue = statement.int32Value(atIndex:columnIndex) {
            return Int16(intValue)
        } else {
            return nil
        }
    }

}

extension Int8 : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(int32Value:Int32(self), atIndex: index)
    }

    public static func readColumnValue(_ statement: Statement, atIndex columnIndex: Int) -> Int8? {
        if let intValue = statement.int32Value(atIndex:columnIndex) {
            return Int8(intValue)
        } else {
            return nil
        }
    }
    
}

extension UInt64 : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(int64Value:Int64(self), atIndex: index)
    }
    
    public static func readColumnValue(_ statement: Statement, atIndex columnIndex: Int) -> UInt64? {
        if let intValue = statement.int64Value(atIndex:columnIndex) {
            return UInt64(intValue)
        } else {
            return nil
        }
    }
    
}

extension UInt32 : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(int64Value:Int64(self), atIndex: index)
    }
    
    public static func readColumnValue(_ statement: Statement, atIndex columnIndex: Int) -> UInt32? {
        if let intValue = statement.int64Value(atIndex:columnIndex) {
            return UInt32(intValue)
        } else {
            return nil
        }
    }
    
}

extension UInt16 : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(int32Value:Int32(self), atIndex: index)
    }
    
    public static func readColumnValue(_ statement: Statement, atIndex columnIndex: Int) -> UInt16? {
        if let intValue = statement.int32Value(atIndex:columnIndex) {
            return UInt16(intValue)
        } else {
            return nil
        }
    }
    
}

extension UInt8 : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(int32Value:Int32(self), atIndex: index)
    }
    
    public static func readColumnValue(_ statement: Statement, atIndex columnIndex: Int) -> UInt8? {
        if let intValue = statement.int32Value(atIndex:columnIndex) {
            return UInt8(intValue)
        } else {
            return nil
        }
    }
    
}

extension Bool : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(int32Value:Int32(self ? 1 : 0), atIndex: index)
    }
    
    public static func readColumnValue(_ statement: Statement, atIndex columnIndex: Int) -> Bool? {
        if let intValue = statement.int32Value(atIndex:columnIndex) {
            return intValue != 0 ? true : false
        } else {
            return nil
        }
    }
    
}

extension Double : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(doubleValue:self, atIndex: index)
    }
    
    public static func readColumnValue(_ statement: Statement, atIndex columnIndex: Int) -> Double? {
        return statement.doubleValue(atIndex:columnIndex)
    }
    
}

extension Float : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(doubleValue:Double(self), atIndex: index)
    }
    
    public static func readColumnValue(_ statement: Statement, atIndex columnIndex: Int) -> Float? {
        if let doubleValue = statement.doubleValue(atIndex:columnIndex) {
            return Float(doubleValue)
        } else {
            return nil;
        }
    }
    
}

extension Data : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(blobValue:self, atIndex: index)
    }
    
    public static func readColumnValue(_ statement: Statement, atIndex columnIndex: Int) -> Data? {
        return statement.blobValue(atIndex:columnIndex)
    }
    
}

extension NSNull : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bindNullValue(atIndex: index)
    }
    
    public static func readColumnValue(_ statement: Statement, atIndex columnIndex: Int) -> Self? {
        // Always return nil since the difference between nil/NSNull is meaningless here.
        return nil
    }
    
}
