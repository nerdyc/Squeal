import Foundation

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
    func bindToStatement(statement:Statement, atIndex:Int) throws
    
}

// =====================================================================================================================
// MARK:- Statement Helpers

extension Statement {
    
    /// Binds an array of parameters to the statement.
    ///
    /// :param:     parameters  The array of parameters to bind.
    ///
    public func bind(parameters:[Bindable?]) throws {
        for parameterIndex in (0..<parameters.count) {
            let bindIndex = parameterIndex + 1 // parameters are bound with 1-based indices
            
            if let parameter = parameters[parameterIndex] {
                try parameter.bindToStatement(self, atIndex: bindIndex)
            } else {
                try bindNullParameter(atIndex:bindIndex)
            }
            
        }
    }

    /// Binds named parameters using the values from a dictionary.
    ///
    /// :param:     namedParameters  A dictionary of values to bind.
    ///
    public func bind(namedParameters namedParameters:[String:Bindable?]) throws {
        for (name, value) in namedParameters {
            try bindParameter(name, value: value)
        }
    }
    
    /// Binds a single named parameter.
    ///
    /// :param:     name    The name of the parameter to bind.
    /// :param:     value   The value to bind.
    ///
    public func bindParameter(name:String, value:Bindable?) throws {
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
    
    public func bindToStatement(statement:Statement, atIndex index:Int) throws {
        try statement.bindStringValue(self, atIndex: index)
    }
    
}

extension Int : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int) throws {
        try statement.bindIntValue(self, atIndex: index)
    }
    
}

extension Int64 : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int) throws {
        try statement.bindInt64Value(self, atIndex: index)
    }
    
}

extension Int32 : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int) throws {
        try statement.bindIntValue(Int(self), atIndex: index)
    }
    
}

extension Int16 : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int) throws {
        try statement.bindIntValue(Int(self), atIndex: index)
    }
    
}

extension Int8 : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int) throws {
        try statement.bindIntValue(Int(self), atIndex: index)
    }
    
}

extension UInt64 : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int) throws {
        try statement.bindInt64Value(Int64(self), atIndex: index)
    }
    
}

extension UInt32 : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int) throws {
        try statement.bindInt64Value(Int64(self), atIndex: index)
    }
    
}

extension UInt16 : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int) throws {
        try statement.bindIntValue(Int(self), atIndex: index)
    }
    
}

extension UInt8 : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int) throws {
        try statement.bindIntValue(Int(self), atIndex: index)
    }
    
}

extension Bool : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int) throws {
        try statement.bindBoolValue(self, atIndex: index)
    }
    
}

extension Double : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int) throws {
        try statement.bindDoubleValue(self, atIndex: index)
    }
    
}

extension Float : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int) throws {
        try statement.bindDoubleValue(Double(self), atIndex: index)
    }
    
}

extension NSData : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int) throws {
        try statement.bindBlobValue(self, atIndex: index)
    }
    
}

extension NSNull : Bindable {
    public func bindToStatement(statement:Statement, atIndex index:Int) throws {
        try statement.bindNullParameter(atIndex: index)
    }
}