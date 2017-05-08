# Squeal, a Swift interface to SQLite

Squeal provides access to [SQLite](http://www.sqlite.org/) databases in Swift. Its goal is to provide a
simple and straight-forward base API, allowing developers to build on top in ways that make sense for their apps. The
API provides direct SQL access, as well as a complete set of helpers to reduce SQL drudgery. It's not a goal of this
project to hide SQL from the developer, or to provide a generic object-mapping on top of SQLite.


### Features

* Small, straightforward Swift interface for accessing SQLite databases via SQL.
* Helper methods for most common types of SQL statements.
* Easy database schema versioning and migration DSL.
* Simple DatabasePool implementation for concurrent access to a database.


## Basic Usage

```swift
import Squeal

let db = Database()

// Create:
try db.createTable("contacts", definitions: [
    "id INTEGER PRIMARY KEY",
    "name TEXT",
    "email TEXT NOT NULL"
])

// Insert:
let contactId = try db.insertInto(
    "contacts",
    values: [
        "name": "Amelia Grey",
        "email": "amelia@gastrobot.xyz"
    ]
)

// Select:
struct Contact {
    let id:Int
    let name:String?
    let email:String
    
    init(row:Statement) throws {
        id = row.intValue("id") ?? 0
        name = row.stringValue("name")
        email = row.stringValue("email") ?? ""
    }
}

let contacts:[Contact] = try db.selectFrom(
    "contacts",
    whereExpr:"name IS NOT NULL",
    block: Contact.init
)

// Count:
let numberOfContacts = try db.countFrom("contacts")
```

The above example can be found in `Squeal.playground` to allow further exploration of Squeal's interface.


## Migrations

Any non-trivial app will need to change its database schema as features are added or updated. Unfortunately, SQLite
provides only minimal support for updating a database's schema. Things like removing a column or removing a `NON NULL`
require the entire database to be re-created with the new schema.

Squeal makes migrations easy by including a `Schema` class with a simple DSL for declaring your database migrations.
Once defined, the Schema can be used to migrate your database to the latest version.

Here's an example:

```swift
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

        // Add an index
        v1.createIndex(
            "contacts_email",
            on: "contacts",
            columns: [ "email" ]
        )
    }
    
    // Version 2:
    schema.version(2) { v2 in        
        // Arbitrary SQL:
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
```

The above example can be found in `Migrations.playground`.


## Installation

Squeal can be installed via [Carthage](https://github.com/Carthage/Carthage) or [CocoaPods](https://cocoapods.org).


### Carthage

To install using Carthage, simply add the following line to your `Cartfile`:

    github "nerdyc/Squeal"


### CocoaPods

To install using Carthage, simply add the following to the appropriate target in your `Podfile`:

    pod "Squeal"



## License

Squeal is released under the MIT License. Details are in the `LICENSE.txt` file in the project.

## Contributing

Contributions and suggestions are very welcome! No contribution is too small. Squeal (like Swift) is still evolving and feedback from the community is appreciated. Open an Issue, or submit a pull request!

The main requirement is for new code to be tested. Nobody appreciates bugs in their database.
