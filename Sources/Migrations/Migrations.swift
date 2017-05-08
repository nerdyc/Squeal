import Foundation

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}


public struct MigrationOptions : OptionSet {
    
    public let rawValue:Int
    public init(rawValue:Int) {
        self.rawValue = rawValue
    }
    
    /// Causes the database to be reset (via `reset`) if the database version is less than the first
    /// version in the schema. For example, if the database version is 5, but the first schema
    /// version is 10.
    ///
    /// This provides a way to "collapse" migrations when backwards-incompatible changes are made.
    /// Any old databases will be completely reset, and all data will be removed, before rebuilding
    /// the database from scratch.
    public static let ResetOldDatabaseVersions = MigrationOptions(rawValue:1)
    
}

public extension Schema {
    
    /// Migrates the given `Database`. If no version is specified, it is migrated to the latest version. If the
    /// `toVersion` is less than the current version, and error is thrown.
    ///
    /// - Parameters:
    ///   - db: The database to migrate.
    ///   - toVersion: The version to migrate to. Must be greater than the current version. If nil, the the database is
    ///                migrated to the latest version.
    ///   - options: Options for the migration.
    /// - Returns: `true` if the database was migrated. `false` if it was already at the latest version.
    /// - Throws:
    ///     An NSError if a database error occurs, or a `SquealMigrationError` if the database couldn't be migrated.
    public func migrate(_ db:Database, toVersion:Int? = nil, options:MigrationOptions = []) throws -> Bool {
        let foreignKeysEnabled = try db.selectBool("PRAGMA foreign_keys") ?? false
        if foreignKeysEnabled {
            try db.execute("PRAGMA foreign_keys = OFF")
        }

        var didMigrate = false
        try db.transaction {
            didMigrate = try migrateInTransaction(db, toVersion: toVersion, options:options)
        }
        
        if foreignKeysEnabled {
            try db.execute("PRAGMA foreign_keys = ON")
        }
        
        return didMigrate
    }
    
    /// Migrates the database, with the assumption that a transaction has already begun.
    fileprivate func migrateInTransaction(_ db:Database, toVersion:Int? = nil, options:MigrationOptions = []) throws -> Bool {
        let dbVersionNumber = try Int(db.queryUserVersionNumber())
        if toVersion == dbVersionNumber {
            return false
        }
        
        let fromIndex:Int?
        if dbVersionNumber == 0 {
            fromIndex = nil
        } else if let index = indexOfVersionNumber(dbVersionNumber) {
            fromIndex = index
        } else {
            let error = SquealMigrationError.unknownDatabaseVersion(
                dbVersion: dbVersionNumber
            )
            
            let firstVersion = versions.first?.number ?? 0
            if dbVersionNumber < firstVersion && options.contains(.ResetOldDatabaseVersions) {
                try resetInTransaction(db)
                fromIndex = nil
            } else {
                throw error
            }
        }
        
        // resolve `toVersion`
        let targetVersion = toVersion ?? latestVersion?.number ?? 0
        guard let toIndex = indexOfVersionNumber(targetVersion) else {
            throw SquealMigrationError.unknownDatabaseVersion(
                dbVersion: targetVersion
            )
        }
        
        // Ensure the target version follows the current version
        if toIndex < fromIndex {
            throw SquealMigrationError.unreachableDatabaseVersion(
                fromVersion: dbVersionNumber,
                toVersion: targetVersion
            )
        } else if toIndex == fromIndex {
            return false
        }
        
        // perform all following migrations
        for version in versions[((fromIndex ?? -1) + 1)...toIndex] {
            try version.migrateInTransaction(db)
        }
        
        return true
    }
    
    /// Drops all tables in the database, and sets the database version to 0. All data will be lost as a result.
    ///
    /// - Parameter db: The database to rest.
    /// - Throws: An NSError with a sqlite error code and message.
    public func reset(_ db:Database) throws {
        let foreignKeysEnabled = try db.selectBool("PRAGMA foreign_keys") ?? false
        if foreignKeysEnabled {
            try db.execute("PRAGMA foreign_keys = OFF")
        }
        
        try db.transaction {
            try resetInTransaction(db)
        }
        
        if foreignKeysEnabled {
            try db.execute("PRAGMA foreign_keys = ON")
        }
    }
    
    /// Resets the database, with the assumption that a transaction has already begun.
    fileprivate func resetInTransaction(_ db:Database) throws {
        let schemaInfo = db.schema
        for tableName in schemaInfo.tableNames {
            guard !tableName.hasPrefix("sqlite_") else {
                continue
            }
            
            try db.dropTable(tableName)
        }
        
        try db.updateUserVersionNumber(0)
    }
    
}
