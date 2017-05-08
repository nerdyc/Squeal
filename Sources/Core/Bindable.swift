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
// MARK:- Statement Helpers

extension Statement {
    
    /// Binds an array of parameters to the statement.
    ///
    /// - Parameters:
    ///     - parameters: The array of parameters to bind.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func bind<S:Sequence>(_ parameters:S) throws where S.Iterator.Element == Optional<Bindable> {
        var bindIndex = 1 // parameters are 1-based
        for parameter in parameters {
            if let parameter = parameter {
                try parameter.bindToStatement(self, atIndex: bindIndex)
            } else {
                try bindNullParameter(atIndex:bindIndex)
            }
            bindIndex += 1
        }
    }

    /// Binds named parameters using the values from a dictionary.
    ///
    /// - Parameters:
    ///     - namedParameters: A dictionary of values to bind.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func bind(namedParameters:[String:Bindable?]) throws {
        for (name, value) in namedParameters {
            try bindParameter(name, value: value)
        }
    }
    
    /// Binds a single named parameter to the statement.
    ///
    /// - Parameters:
    ///   - name: The parameter name.
    ///   - value: The value to bind.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    public func bindParameter(_ name:String, value:Bindable?) throws {
        if let bindIndex = indexOfParameterNamed(name) {
            if value != nil {
                try value!.bindToStatement(self, atIndex: bindIndex)
            } else {
                try bindNullParameter(atIndex:bindIndex)
            }
        }
    }
    
}

// =====================================================================================================================
// MARK:- Binable Implementations

extension String : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bindStringValue(self, atIndex: index)
    }
    
}

extension Int : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bindIntValue(self, atIndex: index)
    }
    
}

extension Int64 : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bindInt64Value(self, atIndex: index)
    }
    
}

extension Int32 : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bindIntValue(Int(self), atIndex: index)
    }
    
}

extension Int16 : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bindIntValue(Int(self), atIndex: index)
    }
    
}

extension Int8 : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bindIntValue(Int(self), atIndex: index)
    }
    
}

extension UInt64 : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bindInt64Value(Int64(self), atIndex: index)
    }
    
}

extension UInt32 : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bindInt64Value(Int64(self), atIndex: index)
    }
    
}

extension UInt16 : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bindIntValue(Int(self), atIndex: index)
    }
    
}

extension UInt8 : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bindIntValue(Int(self), atIndex: index)
    }
    
}

extension Bool : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bindBoolValue(self, atIndex: index)
    }
    
}

extension Double : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bindDoubleValue(self, atIndex: index)
    }
    
}

extension Float : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bindDoubleValue(Double(self), atIndex: index)
    }
    
}

extension Data : Bindable {
    
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bindBlobValue(self, atIndex: index)
    }
    
}

extension NSNull : Bindable {
    public func bindToStatement(_ statement:Statement, atIndex index:Int) throws {
        try statement.bindNullParameter(atIndex: index)
    }
}
