import Squeal

// Define a Schema:
let AppSchema = Schema(identifier:"contacts") { schema in
    
    // Version 1:
    schema.version(1) { v1 in
        
        // Create a Table:
        v1.createTable("contacts") { contacts in
            
            contacts.primaryKey("id")
            contacts.column("name", type:.Text)
            contacts.column("email", type:.Text, constraints:["NOT NULL"])
            
        }

        // Add Indexes
        v1.createIndex(
            "contacts_email",
            on: "contacts",
            columns: [ "email" ]
        )

    }
    
    // Version 2:
    schema.version(2) { v2 in
        
        // Arbitrary SQL code can be executed.
        v2.execute { db in
            try db.deleteFrom("contacts", whereExpr: "name IS NULL")
        }
        
        // Tables can be altered in many ways.
        v2.alterTable("contacts") { contacts in
            
            contacts.alterColumn(
                "name",
                setConstraints: [ "NOT NULL" ]
            )
            
            contacts.addColumn("url", type: .Text)
            
        }
        
    }
    
}

let db = Database()

// Migrate to the latest version:
let didMigrate = try AppSchema.migrate(db)

// Get the database version:
let migratedVersion = try db.queryUserVersionNumber()

// Reset the database:
try AppSchema.migrate(db, toVersion: 0)


