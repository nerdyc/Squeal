import Foundation

/// Migration-specific errors.
public enum SquealMigrationError : Error, CustomStringConvertible {
    
    public typealias RawValue = Int
    
    /// A feature hasn't been implemented yet.
    case unimplemented(feature:String)
    
    /// The database version is not defined in the Schema.
    case unknownDatabaseVersion(dbVersion:Int)
    
    /// Unable to migrate to the given target version.
    case unreachableDatabaseVersion(fromVersion:Int, toVersion:Int)
    
    case foreignKeysViolated(violations:[ForeignKeyViolation])
    
    public var description: String {
        switch self {
        case let .unimplemented(feature):
            return  "\(feature) hasn't been implemented yet."
        case let .unknownDatabaseVersion(dbVersion):
            return  "The database version (\(dbVersion)) isn't defined in the schema."
        case let .unreachableDatabaseVersion(dbVersion, targetVersion):
            return  "Unable to migrate from \(dbVersion) to \(targetVersion)"
        case let .foreignKeysViolated(violations):
            var violatedTables:Set<String> = []
            for violation in violations {
                violatedTables.insert(violation.fromTable + " REFERENCES " + violation.toTable)
            }
            
            return "Migration violated foreign keys: \(violatedTables)"
        }
    }
    
}
