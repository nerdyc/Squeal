# Squeal, a Swift interface to SQLite

Squeal allows [SQLite](http://www.sqlite.org/) databases to be created and accessed from 
[Swift](https://developer.apple.com/swift/) code. Squeal's goal is to make the most common SQLite tasks easy in Swift, 
while still providing complete access to SQLite's advanced features.

### Features

* Access any SQLite database, or multiple databases at a time.
* Easy interface to select rows from a database.
* Helper methods for most common types of SQL statements.
* Compile and reuse SQL for optimal performance.
* Simple DatabasePool implementation for concurrent access to a database.
* No globals.
* Thoroughly tested with [Quick](https://github.com/Quick/Quick) and [Nimble](https://github.com/Quick/Nimble).

## Overview

Using Squeal to create, populate, and select values from a database looks like this:

```swift
import Squeal

let db = Database(path:"data.sqlite3")!

db.createTable("people",
               definitions:[
                   "personId INTEGER PRIMARY KEY",
                   "name TEXT",
                   "email TEXT NOT NULL",
                   "UNIQUE(email)",
                   "CHECK (name IS NOT NULL OR email IS NOT NULL)"
               ])

db.insertInto("people", values:["name":"Harry Potter",     "email":"hpotter@hogwarts.edu"])
db.insertInto("people", values:["name":"Hermione Granger", "email":"hgranger@hogwarts.edu"])

for row in db.selectFrom("people", whereExpr:"name = ?", parameters:["Harry Potter"]) {
    println(row![0])               // Optional(1)
    println(row!["name"])          // Optional("Harry Potter")
    println(row!.dictionaryValue)  // ["name":"Harry Potter", "email":"hpotter@hogwarts.edu"]
    println(row!.values)           // [Optional(1), Optional("Harry Potter"), Optional("hpotter@hogwarts.edu")]
}
```

## Installation

1.  Clone this project into your project directory. E.g.:

    ```bash
    cd ~/SwiftProject
    mkdir Externals
    git clone git@github.com:nerdyc/Squeal.git Externals/Squeal
    ```

2.  Add `Squeal.xcodeproj` to your project by selecting the 'Add files to ...' item in the 'File' menu.

3.  Add `Squeal.framework` to the `Link Binary With Libraries` section of app or framework's `Build Phases`. Be
    careful to select the framework for your platform -- Mac or iOS.
    
    You can do this by selecting your project in XCode's Project navigator (the sidebar on the left), then select
    `Build Phases` for your app or framework's target.

4.  Add Squeal's `module.map` to your project's `Import Paths`.
    
    Within your target or project's `Build Settings`, set the `Import Paths` setting to
    `$(PROJECT_DIR)/Externals/Squeal/modules`. If you cloned `Squeal` to a different location, then modify the
    example value to match.

5.  Build and run.


Step #4 (adding the `module.map`) is necessary because SQLite is a library not a module. Swift can only import 
modules, and the `module.map` defines a module for SQLite so it can be imported into Swift code.

NOTE: If see an issue like "Could not build Objective-C module 'sqlite3'", ensure you have the XCode command-line tools installed. They're required for the module.map to work correctly.

## Accessing a Database

Databases are accessed through the `Database` class. Squeal supports creating on-disk, temporary, and in-memory 
databases:

```swift
var error: NSError?
let onDiskDatabase    = Database(path:"contacts.db", error:&error)
let temporaryDatabase = Database.newTemporaryDatabase(error:&error)
let inMemoryDatabase  = Database.newInMemoryDatabase(error:&error)  // alternatively: Database(error:)
```

If the database doesn't exist, it will be created. If it couldn't be created or opened, `nil` is returned.

## Creating Databases

Of course, when creating a new database you'll need to setup all your tables and other database structures.

### Creating Tables and Indexes

Squeal provides the `Database.createTable(...)` method for creating tables in SQLite databases:

```swift
database.createTable("people",
                     definitions:[
                         "personId INTEGER PRIMARY KEY",
                         "name TEXT",
                         "email TEXT NOT NULL",
                         "UNIQUE(email)",
                         "CHECK (name IS NOT NULL OR email IS NOT NULL)"
                     ])
```

There are also helpers for removing tables and managing indexes:

* `Database.renameTable(tableName:to:error:)`
* `Database.addColumnToTable(tableName:column:error:)`
* `Database.dropTable(tableName:error:)`
* `Database.createIndex(name:tableName:columns:unique:ifNotExists:error:)`
* `Database.dropIndex(indexName:ifExists:error:)`

### Migrating a Database

SQLite databases support a "User Version Number" that can be used to perform migrations. Squeal provides some simple
helpers for accessing this value:

```swift
let CURRENT_VERSION: Int32 = 2
if let version = database.queryUserVersionNumber() {
    if version < CURRENT_VERSION {
        database.transaction { (db:Database) -> Database.TransactionResult in
            if (version < 1) {
                // new database
            } else if (version < 2) {
                // perform migration 
            }
            
            if db.updateUserVersionNumber(CURRENT_VERSION) {
                return .Commit
            } else {
                return .Rollback
            }
        }
    }
}
```

The complete set of methods are:

* `Database.queryUserVersionNumber(error:)`
* `Database.updateUserVersionNumber(number:error:)`

### Accessing the Schema

The Database class provides helpers for accessing the SQLite schema. The `schema` property exposes the database
structure, including which tables and indices exist. Details about a table, including its columns, can be accessed via
`Database.tableInfoForTableNamed(tableName:error:)`.

## Inserting, Updating, and Deleting Data

Squeal also provides Swift helpers for inserting, updating, and removing data to SQLite databases.

### Inserting Rows

To insert data, use `insertInto(tableName:values:error:)`:

```swift
var error: NSError?
if let rowId = database.insertInto("people", values:["email":"amelia@gastrobot.net"], error:&error]) {
    // rowId is the id in the database
} else {
    // handle error
}
```

### Updating Rows

To update data, use `update(tableName:set:whereExpr:parameters:error:)`:

```swift
var error: NSError?
if let updateCount = database.update("people",
                                     set:       ["name":"Amelia"],
                                     whereExpr: "email = ?",
                                     parameters:["amelia@gastrobot.net"],
                                     error:     &error]) {
    // updateCount is the number of updated rows
} else {
    // handle error
}
```

Note the use of a parameter to avoid SQL injection.

### Deleting Rows

Deleting data can be done through `deleteFrom(tableName:whereExpr:parameters:error:)`:

```swift
var error: NSError?
if let deleteCount = database.deleteFrom("people",
                                         whereExpr: "email = ?",
                                         parameters:["amelia@gastrobot.net"],
                                         error:     &error]) {
    // deleteCount is the number of deleted rows
} else {
    // handle error
}
```

## Querying Data

The Database can be queried through the `Database.query(sqlString:parameters:error:)` or
`Database.selectFrom(from:columns:whereExpr:groupBy:having:orderBy:limit:offset:parameters:error:collector:)` methods.
The second method is a helper that will compose a SELECT statement from fragments. Most of the method parameters are 
optional.

For example:

```swift
var error:NSError?
for row in db.query("SELECT * FROM people", error:&error) {
    if row == nil? {
        // handle error
        break
    }
    
    println(row!.dictionaryValue)     // read the whole row as a Dictionary
    println(row!.values)              // or as an array
    
    println(row![0])                  // get the first column's value
    println(row!["personId"])         // get the 'personId' value
    
    println(row!.stringValue("name")) // get the 'name' value
}

// equivalent to above
for row in db.selectFrom("people", error:&error) {
    // ...
}
```

At each loop, a `Statement?` is provided. The `Statement?` will be `nil` if an error occurred, but otherwise provides
methods to access to the current row. See the `Statement` class for complete details.

### Counting rows

Rows can be counted with the `Database.countFrom(from:columns:whereExpr:parameters:error:)` method. Like 
`selectFrom(...)`, most method parameters are optional.

```swift
var error: NSError?
let peopleCount = database.countFrom("people", error:&error)
if peopleCount == nil
    // handle error
}
```

## Transactions & Savepoints

SQLite supports executing SQL statements inside transactions and savepoints. They are more or less identical, except
that savepoints can be nested, while transactions cannot.

Squeal provides Swift helpers for executing blocks of code in a transaction, as well helpers for manually beginning and
comitting transactions.

### Using a Block

The `Database.transaction(block:)` and `Database.savepoint(name:block:)` methods will start a transaction, and 
automatically end the transaction based on the result of a closure. It's the easiest way to perform transactional reads 
and writes to the database.

```swift
var result = database.transaction { (db:Database) -> Database.TransactionResult in
    var error: NSError?
    let insertedId = db.insertInto("people", values:["name":"Audrey"], error:&error)
    if insertedId == nil {
        return .Failed(error:error)
    }
    
    return .Commit
}
```

The `Database.savepoint(name:block:)` is idential, except that it requires a name to identify the savepoint:

```swift
var result = database.savepoint("insert_audrey") { (db:Database) -> Database.TransactionResult in
    var error: NSError?
    let insertedId = db.insertInto("people", values:["name":"Audrey"], error:&error)
    if insertedId == nil {
        return .Failed(error:error)
    }
  
    return .Commit
}
```

### Manually Creating Transactions

If you need to manually manage transactions, there are a number of helpers to do so:

* `Database.beginTransaction(error:)`
* `Database.rollback(error:)`
* `Database.commit(error:)`

And the equivalents for savepoints are available too:

* `Database.beginSavepoint(savepointName:error:)`
* `Database.rollbackSavepoint(savepointName:error:)`
* `Database.releaseSavepoint(savepointName:error:)`

### Executing Arbitrary SQL Statements

The above examples showcased Swift helpers provided by Squeal to execute the most common types of SQL statements. 
Squeal also provides methods for executing any SQL statement you need to.

For non-SELECT statements, the simplest way to execute a statement is via the `Database.execute(sqlString:error:)`
method:

```swift
var error: NSError?
if db.execute("VACUUM", error:&error) {
    // executed
} else {
    // handle error
}
```

Since `Database.execute(sqlString:error:)` simply returns `true` or `false`, it is not appropriate for queries. To execute queries and retrieve data, use the `query` method.

### Reusing Statements

If you need to perform the same query many times, you can reuse a `Statement` object and avoid recompiling the same
SQL each time. To do so, prepare a Statement and then use `Statement.query(parameters:error:)` to execute it each time:

```swift
let statement = database.prepareStatement("SELECT * FROM contacts WHERE email = ?")!
for row in statement.query(parameters:["hpotter@hogwarts.edu"]) {
    ...
}
```

To reuse a non-SELECT statement, use the `Statement.execute(parameters:error:)` method instead:

```swift
let statement = database.prepareStatement("INSERT INTO contacts (name,email) VALUES (?, ?)")!
statement.execute(parameters:["Harry Potter", "hpotter@hogwarts.edu"])
```

## Concurrency & Database Pools

SQLite is thread-safe, and the same `Database` object can be safely passed between threads. However, using the same `Database` object concurrently is not, since one thread might commit a transaction while another is updating a row.

Instead, each operation or thread should use its own `Database` object. Squeal provides the `DatabasePool` class to make
it easy to create and reuse `Database` objects. `DatabasePool` is very simple and does not enforce a bound on the size
of the pool. As a result, it will not block except to open a newly created database.

Note that SQLite supports multiple concurrent readers, but only a single write operation. Executing multiple writes 
concurrently is unlikely to improve performance. Refer to the [SQLite](http://www.sqlite.org/wal.html) documentation 
when deciding how to design concurrency for your app.

## Use Squeal from the command line, or a Playground

Accessing Squeal from a playground, or the command-line REPL isn't possible right now. Squeal relies on a custom
module.map to access SQLite from Swift, and this isn't supported in the XCode betas (yet?).

Any suggestions for a workaround would be appreciated!

## License

Squeal is released under the MIT License. Details are in the `LICENSE.txt` file in the project.

## Contributing

Contributions and suggestions are very welcome! No contribution is too small. Squeal (like Swift) is still evolving and feedback from the community is appreciated. Open an Issue, or submit a pull request!

The main requirement is for new code to be tested. Nobody appreciates bugs in their database.

### Testing

Squeal benefits greatly from the following two testing libraries:

* [Quick](https://github.com/Quick/Quick)
  
  Quick provides BDD-style testing for Swift code. Check out their examples, or Squeal's own tests for examples.
  
* [Nimble](https://github.com/Quick/Nimble)
  
  Nimble provides clean, extensible matchers for Swift tests.

