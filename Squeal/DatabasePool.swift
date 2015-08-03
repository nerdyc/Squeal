import Foundation

public protocol DatabasePoolDelegate : class {
    
    func databaseOpened(database:Database) throws
    func databaseClosed(database:Database)
    
}

///
/// Manages a pool of Database objects. The pool does not have a maximum size, and will not block. The pool can be
/// safely accessed from multiple threads concurrently.
///
public class DatabasePool : NSObject {
    
    public let databasePath : String
    public weak var delegate : DatabasePoolDelegate?
    private let syncQueue : dispatch_queue_t
    
    public init(databasePath:String, delegate:DatabasePoolDelegate? = nil) {
        self.databasePath = databasePath
        self.syncQueue = dispatch_queue_create("DatabasePool-(\(databasePath))", DISPATCH_QUEUE_SERIAL)
        self.delegate = delegate
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
    public func dequeueDatabase() throws -> Database {
        var database:Database?
        var error:NSError?
        dispatch_sync(syncQueue) {
            if self.inactiveDatabases.isEmpty {
                do {
                    database = try self.openDatabase()
                    self.activeDatabases.append(database!)
                } catch let openError as NSError {
                    error = openError
                    return
                } catch let e {
                    fatalError("Unexpected error thrown opening a database \(e)")
                }
            } else {
                database = self.inactiveDatabases.removeLast()
                self.activeDatabases.append(database!)
            }
        }
        
        guard let dequeuedDatabase = database else {
            throw error!
        }
        
        return dequeuedDatabase
    }
    
    ///
    /// Returns a Database to the pool.
    ///
    /// :param: database   The Database to return to the pool.
    ///
    public func enqueueDatabase(database:Database) {
        deactivateDatabase(database)
        dispatch_sync(syncQueue) {
            self.inactiveDatabases.append(database)
        }
    }

    ///
    /// Removes a Database from the pool.
    ///
    /// :param: database   The Database to remove.
    ///
    public func removeDatabase(database:Database) {
        deactivateDatabase(database)
    }
    
    ///
    /// Closes and removes all unused Database objects from the pool. Active databases are not affected.
    ///
    public func drain() {
        dispatch_sync(syncQueue) {
            self.inactiveDatabases.removeAll(keepCapacity: false)
        }
    }
    
    private func openDatabase() throws -> Database {
        let database = try Database(path: databasePath)
        try delegate?.databaseOpened(database)
        return database
    }
    
    private func deactivateDatabase(database:Database) {
        dispatch_sync(syncQueue) {
            if let index = self.activeDatabases.indexOf(database) {
                self.activeDatabases.removeAtIndex(index)
            }
            
            if let index = self.inactiveDatabases.indexOf(database) {
                self.inactiveDatabases.removeAtIndex(index)
            }
            
            self.delegate?.databaseClosed(database)
        }
    }
    
    
}