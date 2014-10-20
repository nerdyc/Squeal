import Foundation
#if os(iOS)
    #if arch(i386) || arch(x86_64)
        import sqlite3_ios_simulator
    #else
        import sqlite3_ios
    #endif
#else
import sqlite3_osx
#endif

extension Database {
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Transactions
    
    /// Result type used to commit or rollback transactions and savepoints.
    public enum TransactionResult {
        case Commit
        case Rollback
        case Failed(NSError)
    }

    /// Begins a database transaction by executing a BEGIN TRANSACTION statement. Transactions cannot be nested. If
    /// nested operations are needed, consider using savepoints instead.
    ///
    /// :returns: `true` if the transaction began, `false` otherwise.
    public func beginTransaction(error:NSErrorPointer = nil) -> Bool {
        return execute("BEGIN TRANSACTION", error: error)
    }

    /// Ends the current transaction and discards changes since the transaction began. All savepoints are also rolled
    /// back. See sqlite docs for details on transaction support.
    ///
    /// :returns: `true` if the transaction was rolled back, `false` otherwise.
    public func rollback(error:NSErrorPointer = nil) -> Bool {
        return execute("ROLLBACK", error: error)
    }

    /// Commits the current transaction and persists changes since the transaction began. All savepoints are also
    /// committed. See sqlite docs for details on transaction support.
    ///
    /// :returns: `true` if the transaction was committed, `false` otherwise.
    public func commit(error:NSErrorPointer = nil) -> Bool {
        return execute("COMMIT", error: error)
    }

    ///
    /// Begins a transaction, invokes the provided closure, and uses its result to determine how to terminate the
    /// transaction. Using this method is more concise than creating and managing the transaction yourself. For example:
    /// 
    ///     let result = db.transaction {
    ///         var error : NSError?
    ///         if let rowId = $0.insertInto("people", values:["name":"Agnes Pigott"], error:&error) {
    ///             return .Failed(error)
    ///         }
    ///
    ///         // more SQL statements...
    ///
    ///         return .Commit
    ///     }
    ///
    /// :param: block   The operation to perform within the transaction. It should not close the transaction itself, but
    ///                 instead return a TransactionResult.
    /// :returns:       The result of the transaction. This should nearly always be the same value returned by the
    ///                 block, except when the BEGIN, ROLLBACK, or COMMIT statements fail.
    ///
    public func transaction(block:(db:Database)->TransactionResult) -> TransactionResult {
        var localError : NSError?
        var didBegin = beginTransaction(error: &localError)
        if !didBegin {
            return .Failed(localError!)
        }

        let result = block(db: self)
        switch result {
        case .Commit:
            var didCommit = commit(error: &localError)
            if !didCommit {
                return .Failed(localError!)
            }
        
        case .Rollback:
            var didRollback = rollback(error: &localError)
            if !didRollback {
                return .Failed(localError!)
            }
        case .Failed:
            // Attempt a rollback but preserve the original error
            rollback(error: nil)
            break
        }
        
        return result
    }

    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Savepoints

    /// Begins a database savepoint by executing a SAVEPOINT statement. Savepoints are nearly identical to transactions,
    /// except that they are named, and can be nested. This is useful when factoring large database operations.
    ///
    /// :returns: `true` if the savepoint began, `false` otherwise.
    public func beginSavepoint(savepointName:String, error:NSErrorPointer = nil) -> Bool {
        return execute("SAVEPOINT " + escapeIdentifier(savepointName), error: error)
    }

    /// Rolls back the database to the point where a savepoint was begun. All changes since then are discarded. Nested
    /// savepoints are also rolled back.
    ///
    /// :returns: `true` if the savepoint was rolled back, `false` otherwise.
    public func rollbackSavepoint(savepointName:String, error:NSErrorPointer = nil) -> Bool {
        return execute("ROLLBACK TO SAVEPOINT " + escapeIdentifier(savepointName),
                       error: error)
    }

    /// Commits a savepoint via a RELEASE statement, persisting its changes when the enclosing transaction completes.
    ///
    /// :returns: `true` if the savepoint was committed (released), `false` otherwise.
    public func releaseSavepoint(savepointName:String, error:NSErrorPointer = nil) -> Bool {
        return execute("RELEASE " + escapeIdentifier(savepointName),
                       error: error)
    }

    ///
    /// Begins a savepoint, invokes the provided closure, and uses its result to determine how to terminate the
    /// savepoint. Using this method is more concise than creating and managing the savepoint yourself. For example:
    ///
    ///     let result = db.savepoint("insert agnes") {
    ///         var error : NSError?
    ///         if let rowId = $0.insertInto("people", values:["name":"Agnes Pigott"], error:&error) {
    ///             return .Failed(error)
    ///         }
    ///
    ///         // more SQL statements...
    ///
    ///         return .Commit
    ///     }
    ///
    /// :param: block   The operation to perform within the savepoint. It should not close the savepoint itself, but
    ///                 instead return a TransactionResult.
    /// :returns:       The result of the savepoint. This should nearly always be the same value returned by the
    ///                 block, except when the SAVEPOINT, ROLLBACK TO SAVEPOINT, or RELEASE statements fail.
    ///
    public func savepoint(name:String, block:(db:Database)->TransactionResult) -> TransactionResult {
        var localError : NSError?
        var didBegin = beginSavepoint(name, error: &localError)
        if !didBegin {
            return .Failed(localError!)
        }

        let result = block(db: self)
        switch result {
        case .Commit:
            var didCommit = releaseSavepoint(name, error: &localError)
            if !didCommit {
                return .Failed(localError!)
            }
        case .Rollback:
            var didRollback = rollbackSavepoint(name, error: &localError)
            if !didRollback {
                return .Failed(localError!)
            }
        case .Failed:
            // Attempt a rollback but preserve the original error
            rollbackSavepoint(name, error: &localError)
            break
        }
        
        return result
    }
    
}