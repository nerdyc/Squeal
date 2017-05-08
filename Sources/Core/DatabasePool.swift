import Foundation


/// Delegate
public protocol DatabasePoolDelegate : class {
    
    
    /// Notifies the delegate that a new `Database` was opened. This gives the delegate an opportunity to setup the
    /// database. For example, executing `PRAGMA` statements to turn on WAL-mode.
    ///
    /// - Parameter database: The database that was opened.
    /// - Throws: Any error that occurs while setting up the database.
    func databaseOpened(_ database:Database) throws
    
    
    /// Notifies the delegate that a previously opened Database will be closed.
    ///
    /// - Parameter database: The database that will be closed.
    func databaseClosed(_ database:Database)
    
}

///
/// Manages a pool of Database objects. The pool does not have a maximum size, and will not block. The pool can be
/// safely accessed from multiple threads concurrently.
///
open class DatabasePool {
    
    /// The path of the database being pooled.
    open let databasePath : String
    
    /// The pool's delegate.
    open weak var delegate : DatabasePoolDelegate?

    /// Dispatch queue used to synchronize access to the pool between threads.
    fileprivate let syncQueue : DispatchQueue
    
    
    /// Creates a new database pool that pools connections to the database at the given path. Since by definition a
    /// pool will create multiple connections to a database, only persistent databases are supported.
    ///
    /// - Parameters:
    ///   - databasePath: The path of the database to pool.
    ///   - delegate: An optional delegate to notify when connections are opened or closed.
    public init(databasePath:String, delegate:DatabasePoolDelegate? = nil) {
        self.databasePath = databasePath
        self.syncQueue = DispatchQueue(label: "DatabasePool-(\(databasePath))", attributes: [])
        self.delegate = delegate
    }
    
    // =================================================================================================================
    // MARK:- Databases
    
    fileprivate var inactiveDatabases   = [Database]()
    fileprivate var activeDatabases     = [Database]()
    
    /// The number of inactive database connections available.
    var inactiveDatabaseCount : Int {
        return inactiveDatabases.count
    }

    /// The number of active database connections being used.
    var activeDatabaseCount : Int {
        return activeDatabases.count
    }
    
    ///
    /// Creates or reuses a Database object. The database should be returned to the pool when it is no longer in use by
    /// calling `enqueueDatabase(database:)`.
    ///
    /// - Returns: An open Database.
    /// - Throws:
    ///     An NSError with the sqlite error code and message.
    ///
    open func dequeueDatabase() throws -> Database {
        var database:Database?
        var error:NSError?
        syncQueue.sync {
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
    
    /// Return a database to the pool, allowing it to be reused.
    ///
    /// - Parameter database: The Database to return to the pool.
    open func enqueueDatabase(_ database:Database) {
        deactivateDatabase(database, notifyDelegate: false)
        syncQueue.sync {
            self.inactiveDatabases.append(database)
        }
    }

    /// Removes the database from the pool. It will not be reused.
    ///
    /// - Parameter database: The database to remove.
    open func removeDatabase(_ database:Database) {
        deactivateDatabase(database, notifyDelegate: true)
    }
    
    ///
    /// Closes and removes all unused Database objects from the pool. Active databases are not affected.
    ///
    open func drain() {
        syncQueue.sync {
            self.inactiveDatabases.removeAll(keepingCapacity: false)
        }
    }
    
    fileprivate func openDatabase() throws -> Database {
        let database = try Database(path: databasePath)
        try delegate?.databaseOpened(database)
        return database
    }
    
    fileprivate func deactivateDatabase(_ database:Database, notifyDelegate:Bool) {
        syncQueue.sync {
            if let index = self.activeDatabases.index(where: { $0 === database }) {
                self.activeDatabases.remove(at: index)
            }
            
            if let index = self.inactiveDatabases.index(where: { $0 === database }) {
                self.inactiveDatabases.remove(at: index)
            }
            
            if (notifyDelegate) {
                self.delegate?.databaseClosed(database)
            }
        }
    }
    
    
}
