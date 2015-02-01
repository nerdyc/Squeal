import Foundation

/// Escapes a SQL string. For example, escaping `it's it` will produce `'it''s it'`.
public func escapeIdentifier(identifier:String) -> String {
    var escapedString = identifier.stringByReplacingOccurrencesOfString("'",
                                                                        withString: "''",
                                                                        options:    .LiteralSearch,
                                                                        range:      nil)
    
    return "'\(escapedString)\'"
}

// =====================================================================================================================
// MARK:- Schema

/// Describes a database's schema -- its tables, indexes, and other structures. The schema can be accessed through the
/// `schema` property of a Database object.
///
/// Schema objects are immutable, and will not change when the database is updated.
public class Schema : NSObject {
    
    public convenience override init() {
        self.init(schemaEntries: [SchemaEntry]())
    }
    
    public init(schemaEntries:[SchemaEntry]) {
        self.schemaEntries = schemaEntries
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Schema Items
    
    /// The entries in the Schema, each describing a table, index, or other structure.
    public let schemaEntries: [SchemaEntry]
    
    public subscript(entryName:String) -> SchemaEntry? {
        return entryNamed(entryName)
    }
    
    /// Returns the entry with the given name -- table, index, or trigger.
    public func entryNamed(entryName:String) -> SchemaEntry? {
        for entry in schemaEntries {
            if entry.name == entryName {
                return entry
            }
        }
        return nil
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Tables
    
    /// All database tables.
    public var tables: [SchemaEntry] {
        return schemaEntries.filter { $0.isTable }
    }

    /// The names of all tables in the database.
    public var tableNames: [String] {
        return tables.map { $0.name }
    }
    
    /// Returns the entry for a particular table.
    public func tableNamed(tableName:String) -> SchemaEntry? {
        for entry in schemaEntries {
            if entry.isTable && entry.name == tableName {
                return entry
            }
        }
        return nil
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Indexes
    
    /// All database indexes.
    public var indexes: [SchemaEntry] {
        return schemaEntries.filter { $0.isIndex }
    }
    
    /// The names of all database indexes.
    public var indexNames: [String] {
        return indexes.map { $0.name }
    }
    
    /// :param:   tableName The name of a table
    /// :returns: Descriptions of each index for the given table.
    public func indexesOnTable(tableName: String) -> [SchemaEntry] {
        return schemaEntries.filter { $0.isIndex && $0.tableName == tableName }
    }
    
    /// :param:   tableName The name of a table
    /// :returns: The name of each index on for a table.
    public func namesOfIndexesOnTable(tableName: String) -> [String] {
        return indexesOnTable(tableName).map { $0.name }
    }
    
}

/// Describes a table, index, or other database structure.
///
/// SchemaEntry objects are immutable and will not change when the database is updated.
public class SchemaEntry : NSObject {
    
    public init(type: String?, name: String?, tableName: String?, rootPage: Int?, sql:String?) {
        self.type       = type      ?? ""
        self.name       = name      ?? ""
        self.tableName  = tableName ?? ""
        self.rootPage   = rootPage
        self.sql        = sql
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Type
    
    /// The type of structure represented by this entry.
    public let type: String
    
    /// `type` for tables.
    public let TABLE_TYPE   = "table"
    /// `type` for indexes.
    public let INDEX_TYPE   = "index"
    /// `type` for views.
    public let VIEW_TYPE    = "view"
    /// `type` for triggers.
    public let TRIGGER_TYPE = "trigger"
    
    /// `true` if this entry describes a table, false otherwise.
    public var isTable : Bool {
        return self.type == TABLE_TYPE
    }
    
    /// `true` if this entry describes an index, false otherwise.
    public var isIndex : Bool {
        return self.type == INDEX_TYPE
    }

    /// `true` if this entry describes a view, false otherwise.
    public var isView : Bool {
        return self.type == VIEW_TYPE
    }

    /// `true` if this entry describes a trigger, false otherwise.
    public var isTrigger : Bool {
        return self.type == TRIGGER_TYPE
    }

    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Name
    
    /// The name of the table, index, view, or trigger described by this object.
    public let name: String
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Table Name
    
    /// If this entry describes a table or a view, this is identical to the `name` property. For an index, this is the
    /// name of the table that is indexed by the index. For triggers, this is the name of the table or view that causes
    /// the trigger to fire.
    public let tableName: String
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Root Page
    
    public let rootPage: Int?
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  SQL
    
    /// The SQL string used to create the table, index, view, or trigger. It will be nil for automatically created
    /// objects, like a unique index created in a CREATE TABLE statement (e.g. "emailAddress TEXT UNIQUE NOT NULL")
    public let sql: String?

}

// =====================================================================================================================
// MARK:- Table

/// Describes the structure of a table -- it's columns.
public class TableInfo : NSObject {
    
    public init(name:String, columns:[ColumnInfo]) {
        self.name = name
        self.columns = columns
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Name
    
    /// The table name.
    public let name: String
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Columns

    /// Details about the table's columns.
    public let columns: [ColumnInfo]

    /// The names of all columns in the table.
    public var columnNames : [String] {
        return columns.map { $0.name }
    }
    
    public subscript(columnName:String) -> ColumnInfo? {
        for column in columns {
            if column.name == columnName {
                return column
            }
        }
        return nil
    }
    
}

/// Describes a column in a database table.
public class ColumnInfo : NSObject {
    
    public init(index:Int, name:String, type:String?, notNull:Bool, defaultValue:String?, primaryKeyIndex:Int) {
        self.index              = index
        self.name               = name
        self.type               = type
        self.notNull            = notNull
        self.defaultValue       = defaultValue
        self.primaryKeyIndex    = primaryKeyIndex
    }
    
    /// The order of the column in the table.
    public let index:           Int

    /// The column's name
    public let name:            String

    /// The type of the column. Since sqlite is dynamically typed, this value is not well defined. But it will often be
    /// 'INTEGER', 'TEXT', 'REAL', or 'BLOB'. However, it can also be missing, or an arbitrary user type.
    public let type:            String?

    /// Whether the column was created with 'NOT NULL'. `true` means the values of the column cannot be nil, `false`
    /// means that NULL is an allowable value.
    public let notNull:         Bool

    /// The default value for the column.
    public let defaultValue:    String?

    /// 0 if the column is not part of the primary key, otherwise the 1-based index within the primary key.
    ///
    /// For example, if a table had a compound key of (name, email_address), then the 'name' column would have a
    /// `primaryKeyIndex` of 1, and the 'email_address' column would be 2.
    public let primaryKeyIndex: Int
    
}

// =====================================================================================================================
// MARK:- Database

public extension Database {
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Schema Introspection
    
    /// The database schema. If an error occurs, an empty Schema object is returned.
    public var schema: Schema {
        var schemaEntries = [SchemaEntry]()
        
        var error: NSError?
        if let statement = prepareStatement("SELECT * FROM sqlite_master", error:&error) {
            for row in statement.query(error:&error) {
                if row == nil {
                    NSLog("Error reading database schema: \(error)")
                    return Schema()
                }
                
                let schemaEntry = SchemaEntry(type:     row!.stringValue("type"),
                                              name:     row!.stringValue("name"),
                                              tableName:row!.stringValue("tbl_name"),
                                              rootPage: row!.intValue("rootpage"),
                                              sql:      row!.stringValue("sql"))
                
                schemaEntries.append(schemaEntry)
                
            }
        } else {
            NSLog("Error preparing statement to read database schema: \(error)")
        }
        
        return Schema(schemaEntries: schemaEntries)
    }
    
    /// Fetches details about a table in the database.
    ///
    /// :param: tableName   A table name
    /// :param: error       An error pointer
    /// :returns: A TableInfo object describing the table and its columns. `nil` if an error occurs.
    ///
    public func tableInfoForTableNamed(tableName:String, error:NSErrorPointer = nil) -> TableInfo? {
        let selectSql = "PRAGMA table_info(" + escapeIdentifier(tableName) + ")"
        if let statement = prepareStatement(selectSql, error:error) {
            var columns = [ColumnInfo]()
            
            for row in statement.query(error:error) {
                if row == nil {
                    return nil
                }
                
                let columnInfo = ColumnInfo(index:          row!.intValue("cid") ?? 0,
                                            name:           row!.stringValue("name") ?? "",
                                            type:           row!.stringValue("type"),
                                            notNull:        row!.boolValue("notnull") ?? false,
                                            defaultValue:   row!.stringValue("dflt_value"),
                                            primaryKeyIndex:row!.intValue("pk") ?? 0)
                
                columns.append(columnInfo)
            }
            
            return TableInfo(name: tableName, columns: columns)
        } else {
            return nil
        }
    }
    
    /// Fetches the 'user_version' value, a user-defined version number for the database. This is useful for managing
    /// migrations.
    ///
    /// :param: error       An error pointer
    /// :returns: The user version, or `nil` if an error occurs.
    ///
    public func queryUserVersionNumber(error:NSErrorPointer = nil) -> Int32? {
        let userViewSql = "PRAGMA user_version"
        if let statement = prepareStatement(userViewSql, error:error) {
            var userVersionNumber:Int32 = 0
            for row in statement.query(error:error) {
                if row == nil {
                    return nil
                }
                
                userVersionNumber = Int32(row!.intValueAtIndex(0) ?? 0)
            }
            return userVersionNumber
        } else {
            return nil
        }
    }

    /// Sets the 'user_version' value, a user-defined version number for the database. This is useful for managing
    /// migrations.
    ///
    /// :param: number      The version number to set
    /// :param: error       An error pointer
    /// :returns: `true` if the version was set, `false` if an error occurs.
    ///
    public func updateUserVersionNumber(number:Int32, error:NSErrorPointer = nil) -> Bool {
        return execute("PRAGMA user_version=\(number)", error: error)
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  CREATE TABLE
    
    /// Creates a table. This is a helper for executing a CREATE TABLE statement.
    ///
    /// :param: tableName   The name of the table.
    /// :param: definitions Column and constraint definitions. For example, "name TEXT NOT NULL".
    /// :param: ifNotExists If `true`, don't create the table if it already exists. If `false`, then this method will
    ///                     return an error if the table exists already. Defaults to false.
    /// :param: error       An error pointer.
    ///
    /// :returns: true if the table was created, false if an error occurs.
    ///
    public func createTable(tableName:String,
                            definitions:[String],
                            ifNotExists:Bool = false,
                            error:NSErrorPointer = nil) -> Bool {
        var createTableSql = [ "CREATE TABLE" ]
        if ifNotExists {
            createTableSql.append("IF NOT EXISTS")
        }
        createTableSql.append(escapeIdentifier(tableName))
        createTableSql.append("(")
        createTableSql.append(join(",", definitions))
        createTableSql.append(")")
                                
        return execute(join(" ", createTableSql),
                       error: error)
    }

    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  DROP TABLE
    
    /// Removes a table. This is a helper for executing a DROP TABLE statement.
    ///
    /// :param: tableName   The name of the table.
    /// :param: ifExists    If `true`, only drop the table if it exists. If `false`, then this method will return an
    ///                     error if the table doesn't exist. Defaults to false.
    /// :param: error       An error pointer.
    ///
    /// :returns: true if the table was dropped, false if an error occurs.
    ///
    public func dropTable(tableName:String, ifExists:Bool = false, error:NSErrorPointer = nil) -> Bool {
        var dropTableSql = "DROP TABLE "
        if ifExists {
            dropTableSql += "IF EXISTS "
        }
        dropTableSql += escapeIdentifier(tableName)
        
        return execute(dropTableSql, error: error)
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  ALTER TABLE
    
    /// Renames a table. This is a helper for executing a ALTER TABLE ... RENAME TO statement.
    ///
    /// :param: tableName   The current name of the table.
    /// :param: to          The new name of the table.
    /// :param: error       An error pointer.
    ///
    /// :returns: true if the table was renamed, false if an error occurs.
    ///
    public func renameTable(tableName:String, to:String, error:NSErrorPointer = nil) -> Bool {
        let renameTableSql = "ALTER TABLE " + escapeIdentifier(tableName)
                                + " RENAME TO " + escapeIdentifier(to)
        
        return execute(renameTableSql, error: error)
    }
    
    /// Adds a column to a table. This is a helper for executing a ALTER TABLE ... ADD COLUMN statement.
    ///
    /// :param: tableName   The name of the table.
    /// :param: column      The column definition, such as "name TEXT NOT NULL DEFAULT ''"
    /// :param: error       An error pointer.
    ///
    /// :returns: true if the column was added, false if an error occurs.
    ///
    public func addColumnToTable(tableName:String, column:String, error:NSErrorPointer = nil) -> Bool {
        let addColumnSql = "ALTER TABLE " + escapeIdentifier(tableName)
                                + " ADD COLUMN " + column
        
        return execute(addColumnSql, error: error)
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  CREATE INDEX
    
    /// Creates a table index. This is a helper for executing a CREATE INDEX statement.
    ///
    /// :param: name        The name of the index.
    /// :param: tableName   The name of the table to index.
    /// :param: columns     The columns to index.
    /// :param: unique      Whether to create a unique index of not. Defaults to false.
    /// :param: ifNotExists If `true`, don't create the index if it already exists. If `false`, then this method will
    ///                     return an error if the index already exists. Defaults to false.
    /// :param: error       An error pointer.
    ///
    /// :returns: true if the table was created, false if an error occurs.
    ///
    public func createIndex(name:String,
                            tableName:String,
                            columns:[String],
                            unique:Bool = false,
                            ifNotExists:Bool = false,
                            error:NSErrorPointer = nil) -> Bool {
                                
        var createIndexSql = [ "CREATE" ]
        if unique {
            createIndexSql.append("UNIQUE")
        }
        createIndexSql.append("INDEX")
        if ifNotExists {
            createIndexSql.append("IF NOT EXISTS")
        }
        
        createIndexSql.append(escapeIdentifier(name))
        createIndexSql.append("ON")
        createIndexSql.append(escapeIdentifier(tableName))
        createIndexSql.append("(")
        createIndexSql.append(join(", ", columns))
        createIndexSql.append(")")
        
        return execute(join(" ", createIndexSql), error: error)
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  DROP INDEX
    
    /// Removes a table index. This is a helper for executing a DROP INDEX statement.
    ///
    /// :param: name        The name of the index.
    /// :param: ifExists    If `true`, only remove the index if it exists. If `false`, then this method will return an
    ///                     error if the index doesn't exist. Defaults to false.
    /// :param: error       An error pointer.
    ///
    /// :returns: true if the index was removed, false if an error occurs.
    ///
    public func dropIndex(indexName:String, ifExists:Bool = false, error:NSErrorPointer = nil) -> Bool {
        var dropIndexSql = "DROP INDEX "
        if ifExists {
            dropIndexSql += "IF EXISTS "
        }
        dropIndexSql += escapeIdentifier(indexName)
        
        return execute(dropIndexSql, error: error)
    }
}
