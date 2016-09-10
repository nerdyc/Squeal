import Foundation

public protocol DatabasePoolDelegate : class {
    
    func databaseOpened(_ database:Database) throws
    func databaseClosed(_ database:Database)
    
}

///
/// Manages a pool of Database objects. The pool does not have a maximum size, and will not block. The pool can be
/// safely accessed from multiple threads concurrently.
///
open class DatabasePool : NSObject {
    
    open let databasePath : String
    open weak var delegate : DatabasePoolDelegate?
    fileprivate let syncQueue : DispatchQueue
    
    public init(databasePath:String, delegate:DatabasePoolDelegate? = nil) {
        self.databasePath = databasePath
        self.syncQueue = DispatchQueue(label: "DatabasePool-(\(databasePath))", attributes: [])
        self.delegate = delegate
    }
    
    // =================================================================================================================
    // MARK:- Databases
    
    fileprivate var inactiveDatabases   = [Database]()
    fileprivate var activeDatabases     = [Database]()
    
    open var inactiveDatabaseCount : Int {
        return inactiveDatabases.count
    }

    open var activeDatabaseCount : Int {
        return activeDatabases.count
    }
    
    ///
    /// Creates or reuses a Database object. The database should be returned to the pool when it is no longer in use by
    /// calling `enqueueDatabase(database:)`.
    ///
    /// :returns: An open Database.
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
    
    ///
    /// Returns a Database to the pool.
    ///
    /// :param: database   The Database to return to the pool.
    ///
    open func enqueueDatabase(_ database:Database) {
        deactivateDatabase(database)
        syncQueue.sync {
            self.inactiveDatabases.append(database)
        }
    }

    ///
    /// Removes a Database from the pool.
    ///
    /// :param: database   The Database to remove.
    ///
    open func removeDatabase(_ database:Database) {
        deactivateDatabase(database)
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
    
    fileprivate func deactivateDatabase(_ database:Database) {
        syncQueue.sync {
            if let index = self.activeDatabases.index(of: database) {
                self.activeDatabases.remove(at: index)
            }
            
            if let index = self.inactiveDatabases.index(of: database) {
                self.inactiveDatabases.remove(at: index)
            }
            
            self.delegate?.databaseClosed(database)
        }
    }
    
    
}
