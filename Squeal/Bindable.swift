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
    func bindToStatement(statement:Statement, atIndex:Int, error:NSErrorPointer) -> Bool
    
}

// =====================================================================================================================
// MARK:- Statement Helpers

extension Statement {
    
    /// Binds an array of parameters to the statement.
    ///
    /// :param:     parameters  The array of parameters to bind.
    /// :param:     error       An error pointer.
    ///
    /// :returns:   `true` if all parameters were bound, `false` otherwise.
    public func bind(parameters:[Bindable?], error:NSErrorPointer = nil) -> Bool {
        for parameterIndex in (0..<parameters.count) {
            let bindIndex = parameterIndex + 1 // parameters are bound with 1-based indices
            
            if let parameter = parameters[parameterIndex] {
                var wasBound = parameter.bindToStatement(self, atIndex: bindIndex, error: error)
                if !wasBound {
                    return false
                }
            } else {
                if !bindNullParameter(atIndex:bindIndex, error: error) {
                    return false
                }
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
    public func bind(#namedParameters:[String:Bindable?], error:NSErrorPointer = nil) -> Bool {
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
    public func bindParameter(name:String, value:Bindable?, error:NSErrorPointer = nil) -> Bool {
        if let bindIndex = indexOfParameterNamed(name) {
            if value != nil {
                let bound = value!.bindToStatement(self, atIndex: bindIndex, error: error)
                if !bound {
                    return false
                }
            } else {
                if !bindNullParameter(atIndex:bindIndex, error: error) {
                    return false
                }
            }
        }
        
        return true
    }
    
}

// =====================================================================================================================
// MARK:- Binable Implementations

extension String : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer = nil) -> Bool {
        return statement.bindStringValue(self, atIndex: index, error: error)
    }
    
}

extension Int : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer = nil) -> Bool {
        return statement.bindIntValue(self, atIndex: index, error: error)
    }
    
}

extension Int64 : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer = nil) -> Bool {
        return statement.bindInt64Value(self, atIndex: index, error: error)
    }
    
}

extension Int32 : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer = nil) -> Bool {
        return statement.bindIntValue(Int(self), atIndex: index, error: error)
    }
    
}

extension Int16 : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer = nil) -> Bool {
        return statement.bindIntValue(Int(self), atIndex: index, error: error)
    }
    
}

extension Int8 : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer = nil) -> Bool {
        return statement.bindIntValue(Int(self), atIndex: index, error: error)
    }
    
}

extension UInt64 : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer = nil) -> Bool {
        return statement.bindInt64Value(Int64(self), atIndex: index, error: error)
    }
    
}

extension UInt32 : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer = nil) -> Bool {
        return statement.bindInt64Value(Int64(self), atIndex: index, error: error)
    }
    
}

extension UInt16 : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer = nil) -> Bool {
        return statement.bindIntValue(Int(self), atIndex: index, error: error)
    }
    
}

extension UInt8 : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer = nil) -> Bool {
        return statement.bindIntValue(Int(self), atIndex: index, error: error)
    }
    
}

extension Bool : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer = nil) -> Bool {
        return statement.bindBoolValue(self, atIndex: index, error: error)
    }
    
}

extension Double : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer = nil) -> Bool {
        return statement.bindDoubleValue(self, atIndex: index, error: error)
    }
    
}

extension Float : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer = nil) -> Bool {
        return statement.bindDoubleValue(Double(self), atIndex: index, error: error)
    }
    
}

extension NSData : Bindable {
    
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer = nil) -> Bool {
        return statement.bindBlobValue(self, atIndex: index, error: error)
    }
    
}

extension NSNull : Bindable {
    public func bindToStatement(statement:Statement, atIndex index:Int, error:NSErrorPointer = nil) -> Bool {
        return statement.bindNullParameter(atIndex: index, error: error)
    }
}