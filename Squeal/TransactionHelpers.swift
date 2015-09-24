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

public extension Database {
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Transactions
    
    /// Result type used to commit or rollback transactions and savepoints.
    public enum TransactionResult {
        case Commit
        case Rollback
    }

    /// Begins a database transaction by executing a BEGIN TRANSACTION statement. Transactions cannot be nested. If
    /// nested operations are needed, consider using savepoints instead.
    public func beginTransaction() throws {
        try execute("BEGIN TRANSACTION")
    }

    /// Ends the current transaction and discards changes since the transaction began. All savepoints are also rolled
    /// back. See sqlite docs for details on transaction support.
    public func rollback() throws {
        try execute("ROLLBACK")
    }

    /// Commits the current transaction and persists changes since the transaction began. All savepoints are also
    /// committed. See sqlite docs for details on transaction support.
    public func commit() throws {
        try execute("COMMIT")
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
    public func transaction(block:(db:Database) throws -> TransactionResult) throws -> TransactionResult {
        try beginTransaction()

        do {
            let result = try block(db: self)
            switch result {
            case .Commit:
                try commit()
                
            case .Rollback:
                try rollback()
            }
            return result
        } catch let error {
            do {
                try rollback()
            } catch {
                // ignore the rollback if it fails
            }
            
            throw error
        }
    }

    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Savepoints

    /// Begins a database savepoint by executing a SAVEPOINT statement. Savepoints are nearly identical to transactions,
    /// except that they are named, and can be nested. This is useful when factoring large database operations.
    public func beginSavepoint(savepointName:String) throws {
        try execute("SAVEPOINT " + escapeIdentifier(savepointName))
    }

    /// Rolls back the database to the point where a savepoint was begun. All changes since then are discarded. Nested
    /// savepoints are also rolled back.
    public func rollbackSavepoint(savepointName:String) throws {
        try execute("ROLLBACK TO SAVEPOINT " + escapeIdentifier(savepointName))
    }

    /// Commits a savepoint via a RELEASE statement, persisting its changes when the enclosing transaction completes.
    public func releaseSavepoint(savepointName:String) throws {
        try execute("RELEASE " + escapeIdentifier(savepointName))
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
    public func savepoint(name:String, block:(db:Database)throws->TransactionResult) throws -> TransactionResult {
        try beginSavepoint(name)

        do {
            let result = try block(db: self)
            switch result {
            case .Commit:
                try releaseSavepoint(name)
            case .Rollback:
                try rollbackSavepoint(name)
            }
            return result
        } catch let error {
            do {
                // Attempt a rollback but preserve the original error
                try rollbackSavepoint(name)
            } catch {
                // ignore the rollback error
            }
            throw error
        }
    }
    
}