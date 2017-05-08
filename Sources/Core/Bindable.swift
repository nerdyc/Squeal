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
    
}


// =====================================================================================================================
// MARK:- Binable Implementations

extension String : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(stringValue:self, atIndex: index)
    }
    
}

extension Int : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(int64Value:Int64(self), atIndex: index)
    }
    
}

extension Int64 : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(int64Value:self, atIndex: index)
    }
    
}

extension Int32 : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(int32Value:self, atIndex: index)
    }
    
}

extension Int16 : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(int32Value:Int32(self), atIndex: index)
    }
    
}

extension Int8 : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(int32Value:Int32(self), atIndex: index)
    }
    
}

extension UInt64 : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(int64Value:Int64(self), atIndex: index)
    }
    
}

extension UInt32 : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(int64Value:Int64(self), atIndex: index)
    }
    
}

extension UInt16 : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(int32Value:Int32(self), atIndex: index)
    }
    
}

extension UInt8 : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(int32Value:Int32(self), atIndex: index)
    }
    
}

extension Bool : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(int32Value:Int32(self ? 1 : 0), atIndex: index)
    }
    
}

extension Double : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(doubleValue:self, atIndex: index)
    }
    
}

extension Float : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(doubleValue:Double(self), atIndex: index)
    }
    
}

extension Data : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bind(blobValue:self, atIndex: index)
    }
    
}

extension NSNull : Bindable {
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bindNullValue(atIndex: index)
    }
}
