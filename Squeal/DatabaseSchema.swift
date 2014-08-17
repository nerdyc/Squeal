import Foundation

public func escapeIdentifier(identifier:String) -> String {
    var escapedString = identifier.stringByReplacingOccurrencesOfString("'",
                                                                        withString: "''",
                                                                        options:    .LiteralSearch,
                                                                        range:      nil)
    
    return "'\(escapedString)\'"
}

// =====================================================================================================================
// MARK:- Schema Extensions

public class Schema : NSObject {
    
    public convenience override init() {
        return self.init(schemaEntries: [SchemaEntry]())
    }
    
    public init(schemaEntries:[SchemaEntry]) {
        self.schemaEntries = schemaEntries
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Schema Items
    
    public let schemaEntries: [SchemaEntry]
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Tables
    
    public var tables: [SchemaEntry] {
        return schemaEntries.filter { $0.isTable }
    }

    public var tableNames: [String] {
        return tables.map { $0.name }
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Indexes
    
    public var indexes: [SchemaEntry] {
        return schemaEntries.filter { $0.isIndex }
    }
    
    public var indexNames: [String] {
        return indexes.map { $0.name }
    }
    
    public func indexesOnTable(tableName: String) -> [SchemaEntry] {
        return schemaEntries.filter { $0.isIndex && $0.tableName == tableName }
    }
    
    public func namesOfIndexesOnTable(tableName: String) -> [String] {
        return indexesOnTable(tableName).map { $0.name }
    }
    
}

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
    
    public let type: String
    
    public let TABLE_TYPE   = "table"
    public let INDEX_TYPE   = "index"
    public let VIEW_TYPE    = "view"
    public let TRIGGER_TYPE = "trigger"
    
    public var isTable : Bool {
        return self.type == TABLE_TYPE
    }
    
    public var isIndex : Bool {
        return self.type == INDEX_TYPE
    }

    public var isView : Bool {
        return self.type == VIEW_TYPE
    }

    public var isTrigger : Bool {
        return self.type == TRIGGER_TYPE
    }

    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Name
    
    public let name: String
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Table Name
    
    public let tableName: String
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Root Page
    
    public let rootPage: Int?
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  SQL
    
    public let sql: String?

}

public class TableInfo : NSObject {
    
    public init(name:String, columns:[ColumnInfo]) {
        self.name = name
        self.columns = columns
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Name
    
    public let name: String
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Columns

    public let columns: [ColumnInfo]

    public var columnNames : [String] {
        return columns.map { $0.name }
    }
    
}

public class ColumnInfo : NSObject {
    
    public init(index:Int, name:String, type:String?, notNull:Bool, defaultValue:String?, primaryKeyIndex:Int) {
        self.index              = index
        self.name               = name
        self.type               = type
        self.notNull            = notNull
        self.defaultValue       = defaultValue
        self.primaryKeyIndex    = primaryKeyIndex
    }
    
    public let index:           Int
    public let name:            String
    public let type:            String?
    public let notNull:         Bool
    public let defaultValue:    String?
    public let primaryKeyIndex: Int
    
}

extension Database {
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  Schema Introspection
    
    public var schema: Schema {
        var schemaEntries = [SchemaEntry]()
        
        if isOpen {
            var error: NSError?
            if let statement = prepareStatement("SELECT * FROM sqlite_master", error:&error) {
                rowLoop: while true {
                    switch statement.next(&error) {
                    case .Some(true):
                        let schemaEntry = SchemaEntry(type:     statement.stringValue("type"),
                                                      name:     statement.stringValue("name"),
                                                      tableName:statement.stringValue("tbl_name"),
                                                      rootPage: statement.intValue("rootpage"),
                                                      sql:      statement.stringValue("sql"))
                        
                        schemaEntries.append(schemaEntry)
                        
                    case .Some(false):
                        break rowLoop
                        
                    default:
                        NSLog("Error reading database schema: \(error)")
                        return Schema()
                    }
                }
                statement.close()
            } else {
                NSLog("Error preparing statement to read database schema: \(error)")
            }
        }
        
        return Schema(schemaEntries: schemaEntries)
    }
    
    public func tableInfoForTableNamed(tableName:String, error:NSErrorPointer = nil) -> TableInfo? {
        let selectSql = "PRAGMA table_info(" + escapeIdentifier(tableName) + ")"
        if let statement = prepareStatement(selectSql, error:error) {
            var columns = [ColumnInfo]()
            
            rowLoop: while true {
                switch statement.next(error) {
                case .Some(true):
                    let columnInfo = ColumnInfo(index:          statement.intValue("cid") ?? 0,
                                                name:           statement.stringValue("name") ?? "",
                                                type:           statement.stringValue("type"),
                                                notNull:        statement.boolValue("notnull") ?? false,
                                                defaultValue:   statement.stringValue("dflt_value"),
                                                primaryKeyIndex:statement.intValue("pk") ?? 0)
                    
                    columns.append(columnInfo)
                    
                case .Some(false):
                    break rowLoop
                default:
                    return nil
                }
            }
            statement.close()
            
            return TableInfo(name: tableName, columns: columns)
        } else {
            return nil
        }
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  CREATE TABLE
    
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
    
    public func renameTable(tableName:String, to:String, error:NSErrorPointer = nil) -> Bool {
        let renameTableSql = "ALTER TABLE " + escapeIdentifier(tableName)
                                + " RENAME TO " + escapeIdentifier(to)
        
        return execute(renameTableSql, error: error)
    }
    
    public func addColumnToTable(tableName:String, column:String, error:NSErrorPointer = nil) -> Bool {
        let addColumnSql = "ALTER TABLE " + escapeIdentifier(tableName)
                                + " ADD COLUMN " + column
        
        return execute(addColumnSql, error: error)
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // MARK:  CREATE INDEX
    
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
    
    public func dropIndex(indexName:String, ifExists:Bool = false, error:NSErrorPointer = nil) -> Bool {
        var dropIndexSql = "DROP INDEX "
        if ifExists {
            dropIndexSql += "IF EXISTS "
        }
        dropIndexSql += escapeIdentifier(indexName)
        
        return execute(dropIndexSql, error: error)
    }
}
