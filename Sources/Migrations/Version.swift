import Foundation

public final class Version : TableSet, TableIndexSet {
    
    init(number:Int, tables:[Table], transformers:[Transformer]) {
        self.number = number
        self.tables = tables
        self.indexes = tables.flatMap { $0.indexes }
        self.transformers = transformers
    }
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Number
    
    /// The number of the version.
    public let number:Int

    // ---------------------------------------------------------------------------------------------
    // MARK: Tables
    
    
    /// All tables in the database at this version. This includes tables created in previous versions.
    public let tables:[Table]
    
    
    /// Returns the `Table` with the given name.
    ///
    /// - Parameter tableName: The name of a table.
    public subscript(tableName:String) -> Table? {
        return tableNamed(tableName)
    }
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Indexes
    
    /// Indexes in the database at this version. This includes indexes defined in previous versions.
    public let indexes:[TableIndex]
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Migrate
    
    let transformers:[Transformer]
    
    func migrateInTransaction(_ db:Database) throws {
        for transformer in transformers {
            try transformer.transform(db)
        }
        try db.updateUserVersionNumber(Int32(number))
    }
    
}


/// DSL used to define changes to a database made in a Version.
public final class VersionBuilder : TableSet, TableIndexSet {
    
    /// The version number.
    public let number:Int
    
    /// All tables in the version.
    public internal(set) var tables:[Table]
    
    /// All indexes in the version.
    public var indexes: [TableIndex] {
        return tables.flatMap { $0.indexes }
    }
    
    var transformers = [Transformer]()
    
    init(number:Int, previousVersion:Version?) {
        self.number = number
        self.tables = previousVersion?.tables ?? []
    }
    
    func build() -> Version {
        return Version(
            number: number,
            tables: tables,
            transformers: transformers
        )
    }
    
}

// =================================================================================================
// MARK:- Transformer

protocol Transformer {
    
    func transform(_ db:Database) throws
    
}
