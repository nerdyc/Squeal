import Foundation


///
/// Defines a database's schema, which describes the different versions of a database. A `Schema` contains multiple
/// `Version`s, each of which defines the state of the database at that version.
///
public final class Schema {
    
    /// Creates a new Schema with the given identifier. The block is used to define the versions of the schema.
    ///
    /// - Parameters:
    ///   - identifier: The schema's identifier.
    ///   - block: A block used to build the schema.
    public init(identifier:String? = nil,  block: (SchemaBuilder)->Void) {
        let builder = SchemaBuilder()
        block(builder)
        
        self.identifier = identifier
        self.versions = builder.versions
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK: Identifier
    
    /// An string identifying the Schema. It's useful for distinguishing two schemas, but not used
    /// internally.
    public let identifier:String?
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK: Versions
    
    /// Each version of the schema. Versions describe the changes made between each version of the Schema.
    let versions:[Version]
    
    func version(_ number:Int) -> Version? {
        return versionWithNumber(number)
    }
    
    /// The latest version of the schema.
    var latestVersion:Version? {
        return versions.last
    }
    
    /// Returns the `Version` with the given `number`.
    ///
    /// - Parameter number: The version number to return.
    /// - Returns: The `Version`, or `nil` if it not found.
    func versionWithNumber(_ number:Int) -> Version? {
        guard let index = versions.index(where: { $0.number == number }) else {
            return nil
        }
        
        return versions[index]
    }
    
    func indexOfVersionNumber(_ number:Int) -> Int? {
        return versions.index(where: { $0.number == number })
    }
    
    // ---------------------------------------------------------------------------------------------
    // MARK: Table Helpers
    
    func tableNamed(_ name:String) -> Table? {
        return latestVersion?.tableNamed(name)
    }
    
    subscript(tableName:String) -> Table? {
        return tableNamed(tableName)
    }
    
}

// =================================================================================================
// MARK:- Builder

/// Builder class that defines the DSL used to build a `Schema`.
public final class SchemaBuilder {
    
    fileprivate var versions = [Version]()
    
    fileprivate init() {
        // prevent instantiation
    }
    
    
    /// Defines a new version of a database `Schema`.
    ///
    /// - Parameters:
    ///   - number: The version number.
    ///   - block: A block used to define the changes made in the version.
    public func version(_ number:Int, block:(VersionBuilder)->Void) {
        let builder = VersionBuilder(number:number, previousVersion: versions.last)
        block(builder)
        
        let version = builder.build()
        versions.append(version)
    }
    
}

