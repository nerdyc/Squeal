import Foundation

///
/// Manages a pool of Database objects. The pool does not have a maximum size, and will not block. The pool can be
/// safely accessed from multiple threads concurrently.
///
public class DatabasePool : NSObject {
    
    public let databasePath : String
    private let syncQueue : dispatch_queue_t
    
    public init(databasePath:String) {
        self.databasePath = databasePath
        self.syncQueue = dispatch_queue_create("DatabasePool-(\(databasePath))", DISPATCH_QUEUE_SERIAL)
    }
    
    deinit {
        // ensure unused databases get closed
        drain()
    }
    
    // =================================================================================================================
    // MARK:- Databases
    
    private var inactiveDatabases   = [Database]()
    private var activeDatabases     = [Database]()
    
    public var inactiveDatabaseCount : Int {
        return inactiveDatabases.count
    }

    public var activeDatabaseCount : Int {
        return activeDatabases.count
    }
    
    ///
    /// Creates or reuses a Database object. The database should be returned to the pool when it is no longer in use by
    /// calling `enqueueDatabase(database:)`.
    ///
    ///
    ///
    /// :param: error   An error pointer.
    /// :returns: An open Database, or nil if the database could not be opened.
    ///
    public func dequeueDatabase(error:NSErrorPointer) -> Database? {
        var database : Database? = nil
        dispatch_sync(syncQueue) {
            if self.inactiveDatabases.isEmpty {
                database = self.openDatabase(error)
                if database != nil {
                    self.activeDatabases.append(database!)
                }
            } else {
                database = self.inactiveDatabases.removeLast()
                self.activeDatabases.append(database!)
            }
        }
        return database
    }
    
    ///
    /// Returns a Database to the pool. If the database has been closed, it is removed from the pool.
    ///
    /// :param: database   The Database to return to the pool.
    ///
    public func enqueueDatabase(database:Database) {
        deactivateDatabase(database)
        if database.isOpen {
            dispatch_sync(syncQueue) {
                self.inactiveDatabases.append(database)
            }
        }
    }

    ///
    /// Removes a Database from the pool, and closes the Database.
    ///
    /// :param: database   The Database to close and remove.
    ///
    public func removeDatabase(database:Database) {
        deactivateDatabase(database)
        if database.isOpen {
            var error : NSError?
            if !database.close(&error) {
                NSLog("Error closing database: \(error?.localizedDescription)")
            }
        }
    }
    
    ///
    /// Closes and removes all unused Database objects from the pool. Active databases are not affected.
    ///
    public func drain() {
        dispatch_sync(syncQueue) {
            while self.inactiveDatabases.count > 0 {
                var database = self.inactiveDatabases.removeLast()
                self.closeDatabase(database)
            }
        }
    }
    
    private func openDatabase(error:NSErrorPointer) -> Database? {
        var database = Database(path: databasePath)
        if database.open(error) {
            return database
        } else {
            return nil
        }
    }

    private func closeDatabase(database:Database) {
        var error : NSError?
        if !database.close(&error) {
            NSLog("Error closing database: \(error?.localizedDescription)")
        }
    }
    
    private func deactivateDatabase(database:Database) {
        dispatch_sync(syncQueue) {
            if let index = find(self.activeDatabases, database) {
                self.activeDatabases.removeAtIndex(index)
            }
            
            if let index = find(self.inactiveDatabases, database) {
                self.inactiveDatabases.removeAtIndex(index)
            }
        }
    }
    
    
}