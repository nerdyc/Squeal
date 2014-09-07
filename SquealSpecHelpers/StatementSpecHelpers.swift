import Foundation
import Squeal

public extension Statement {
    
    public func next() -> Bool {
        var error : NSError? = nil
        if let result = self.next(&error) {
            return result
        } else {
            NSException(name:       NSInternalInconsistencyException,
                reason:     "Failed to advance statement: \(error?.localizedDescription)",
                userInfo:   nil).raise()
            
            return false
        }
    }
    
    public func bind(parameters:Bindable?...) {
        var error : NSError? = nil
        let result = self.bind(parameters, error: &error)
        if result == false {
            NSException(name:       NSInternalInconsistencyException,
                reason:     "Failed to bind parameters (\(parameters)): \(error?.localizedDescription)",
                userInfo:   nil).raise()
        }
    }
    
}