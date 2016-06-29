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
    /// Begins a new transaction, executes the block, and commits the transaction if no errors
    /// are thrown. The transaction is rolled back if any error is thrown.
    ///
    /// :param: block The operation to perform within the transaction.
    ///
    public func transaction(@noescape block:() throws -> ()) throws {
        try beginTransaction()
        do {
            try block()
        } catch {
            do {
                try rollback()
            } catch {
                // ignore the rollback if it fails
            }
            throw error
        }
        try commit()
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
    /// Executes the provided block within a savepoint, and commits the results if no errors are
    /// thrown. The savepoint is automatically released if any error is thrown.
    ///
    /// :param: block The operation to perform within the savepoint.
    ///
    public func savepoint(name:String, @noescape block:()throws->()) throws -> () {
        try beginSavepoint(name)
        do {
            try block()
        } catch {
            do {
                // Attempt a rollback but preserve the original error
                try rollbackSavepoint(name)
            } catch {
                // ignore the rollback error
            }
            throw error
        }
        try releaseSavepoint(name)
    }
    
}