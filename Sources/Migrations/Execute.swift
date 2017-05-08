import Foundation

public typealias ExecuteBlock = ((Database) throws -> Void)

public extension VersionBuilder {
    
    /// Executes the given block during a migration, allowing arbitrary updates to values in a database. Since Squeal
    /// has no visibility to changes made by this block, changes must be kept solely to changing the data in the
    /// database. Any change to the database structure (adding a column, removing an index, etc.) may cause later
    /// migrations to lose data.
    ///
    /// Migrations are performed within a transaction, so any failures will rollback the entire migration.
    ///
    /// - Parameter block: A block defining change to the database to make.
    public func execute(_ block:@escaping ExecuteBlock) {
        transformers.append(ExecuteTransformer(block:block))
    }
    
}

final class ExecuteTransformer : Transformer {
    
    let block:ExecuteBlock
    
    init(block:@escaping ExecuteBlock) {
        self.block = block
    }
    
    func transform(_ db: Database) throws {
        try block(db)
    }
    
}
