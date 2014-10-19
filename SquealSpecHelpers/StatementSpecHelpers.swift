import Foundation
import Squeal

public extension Statement {
    
    public func bindOrFail(parameters:Bindable?...) {
        var error : NSError? = nil
        let result = self.bind(parameters, error: &error)
        if result == false {
            NSException(name:       NSInternalInconsistencyException,
                reason:     "Failed to bind parameters (\(parameters)): \(error?.localizedDescription)",
                userInfo:   nil).raise()
        }
    }
    
}