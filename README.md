# Squeal, a Swift interface to SQLite

Squeal allows [SQLite](http://www.sqlite.org/) databases to be created and accessed with [Swift](https://developer.apple.com/swift/). Squeal's goal is to make the most common SQLite tasks easy in Swift, while still providing complete access to SQLite's
advanced features.

To this end, Squeal provides helpers for executing the most common types of SQLite statements in Swift. Creating tables,
inserting data, and reading results can all be done with a minimum of boilerplate code.

Squeal also provides access to SQLite statement objects, which allow SQL to be pre-compiled and reused for optimal 
performance.

## Installation

1.  Clone this project into your project directory. E.g.:

    ```bash
    cd ~/SwiftProject
    mkdir Externals
    git clone git@github.com:nerdyc/Squeal.git Externals/Squeal
    ```

2.  Add `Squeal.xcodeproj` to your project by selecting the 'Add files to ...' item in the 'File' menu.

3.  Add Squeal's `module.map` to your project's `Import Paths`.
    
    You can do this by selecting your project in XCode's Project navigator (the sidebar on the left), then select
    `Build Settings` for your app target.
    
    Within `Build Settings`, set the `Import Paths` setting to `$(PROJECT_DIR)/Externals/Squeal/modules`. If you cloned
    `Squeal` to a different location, then modify the example value to match.

4.  Build and run.


Step #3 is necessary because SQLite is a library not a module. Swift can only import modules, and the `module.map` 
defines a module for SQLite so it can be imported into Swift code.

NOTE: If see an issue like "Could not build Objective-C module 'sqlite3'", ensure you have the XCode command-line tools installed. They're required for the module.map to work correctly.

## Accessing a Database

Databases are accessed through the `Database` class. Squeal supports creating on-disk, temporary, and in-memory 
databases:

```swift
let onDiskDatabase    = Database(path:"contacts.db")
let temporaryDatabase = Database.newTemporaryDatabase()
let inMemoryDatabase  = Database.newInMemoryDatabase()  // alternatively: Database()
```

After creating a `Database` object, it must be opened before use:

```swift
let database = Database()
var error : NSError?
if !database.open(&error) {
    // handle error
}
```

Databases must be closed to free their resources:

```swift
var error : NSError?
if !database.close(&error) {
    // handle error
}
```

Closing a database will attempt to close all outstanding `Statement` objects, but may fail if the `Database` object is 
still being used elsewhere in your app.

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

## Reading Data

Data can be read via the
`Database.selectFrom(from:columns:whereExpr:groupBy:having:orderBy:limit:offset:parameters:error:collector:)` method.
Most of the method parameters are optional.

The `collector` argument is a closure that will be called for each matching row. The method returns an array of all
processed rows.

For example, the following code snippet reads `Person` structs from the database:

```swift
struct Person {
    let id:Int64?
    let name:String?
    let email:String?
}

var people = database.selectFrom("people") { (statement:Statement) -> Person in
    // this block is called to process each row.
    return Person(id:   statement.int64Value("personId"),
                  name: statement.stringValue("name"),
                  email:statement.stringValue("email"))
}
if people != nil {
    // ...
} else {
    // handle error
}
```

### Counting rows

Rows can be counted with the `Database.countFrom(from:columns:whereExpr:parameters:error:)` method. Like 
`selectFrom(...)`, most method parameters are optional.

```swift
var error: NSError?
if let peopleCount = database.countFrom("people", error:&error) {
    // continue
} else {
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

## Concurrency & Database Pools

SQLite is thread-safe, and the same `Database` object can be safely passed between threads. However, using the same `Database` object concurrently is not, since one thread might commit a transaction while another is updating a row.

Instead, each operation or thread should use its own `Database` object. Squeal provides the `DatabasePool` class to make
it easy to create and reuse `Database` objects. `DatabasePool` is very simple and does not enforce a bound on the size
of the pool. As a result, it will not block except to open a newly created database.

Note that SQLite supports multiple concurrent readers, but only a single write operation. Executing multiple writes 
concurrently is unlikely to improve performance. Refer to the [SQLite](http://www.sqlite.org/wal.html) documentation 
when deciding how to design concurrency for your app.

## Executing Arbitrary SQLite Statements

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

Since `Database.execute(sqlString:error:)` simply returns `true` or `false`, it is not appropriate for queries. To execute queries and retrieve data, it's necessary to prepare a `Statement` object.

### Prepare `Statement` objects to execute SQL

Once a database has been opened, SQLite commands and queries are executed through `Statement` objects.

`Statement` objects are created by the `Database.prepareStatement()` method:

```swift
var error : NSError?
let statement = database.prepareStatement("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)",
                                          error:&error)
if statement == nil {
    // handle error
}
```

Preparing a statement compiles and validates the SQL string, but does not execute it. SQLite compiles SQL strings into
an internal executable representation. Think of `Statement` objects like mini computer programs.

Once prepared, statements are executed through the `Statement.execute(error:)` or `Statement.query(error:)` methods. `Statement` objects are reusable, and are more efficient when reused. See below for details.

Once a `Statement` is no longer needed, it must be closed to release its resources:

```swift
statement.close()
```

After closing a `Statement`, it is unusable and should be discarded.

### Use `Statement.execute(:error)` to perform updates

Any SQL statement that is not a `SELECT` should use the `Statement.execute(error:)` method:

```swift
let executeSucceeded = statement.execute(&error)
```

After executing an INSERT statement, the ID of the inserted row can be accessed from the `Database.lastInsertedRowId` property. The number of rows affected by an UPDATE or DELETE statement is accessible from the `Database.numberOfChangedRows` property.

### Iterate a Statement when querying the database

`SELECT` statements are special because they return data. To execute a query and iterate through the results, just use
a for loop after preparing a statement:

```swift
var error : NSError?
if let statement = database.prepareStatement("SELECT name FROM contacts", error:&error) {
    for result in statement {
        switch result {
        case .Row:
            // process the row
            var contactName = statement.stringValue("name")
        case .Error(let e):
            // handle the error
        }
    }
}
```

This is a convenience interface to `Statement.next(error:)`. As mentioned above, you can think of `Statement` objects as
mini programs. The `next(error:)` method is like stepping through that program in a debugger. At each step, we call
`next(error:)` to advance to the next row. A `Bool?` will be returned to indicate whether another row was returned
(`true`), all data has been consumed (`false`), or an error occured (`nil`).

### Use parameters in SQL to simplify escaping and avoid injection attacks

SQLite supports parameratized SQL statements, like `SELECT * FROM contacts WHERE name = ?`. When compiled into a
`Statement` object, you can specify the value for the `?` separately by *binding* a value for it. This help to avoid the
need to escape values when constructing SQL, and allows compiled statements to be reused many times.

For example:

```swift
var error : NSError?
if let statement = database.prepareStatement("SELECT * FROM contacts WHERE name = ?",
                                             error:&error) {
    
    if statement.bindStringParameter("; DELETE FROM contacts", atIndex:1, error:&error) {
        for result in statement {
            switch result {
            case .Row:
                // process the row
                var contactName = statement.stringValue("name")
            case .Error(let e):
                // handle the error
            }
        }
    }
}
```

Note that **parameters are 1-based**. Binding a parameter at index '0' will always fail.

SQLite also supports inserting an indexed parameter multiple times. This is best shown by example: 

```sql
SELECT * FROM contacts WHERE name = ?1 OR email = ?1
```

This statement has a single parameter that is inserted multiple times. It will match any contact whose name or email 
matches the first parameter. 

#### Named Parameters

SQLite supports parameters like `$NAME`, which can make longer queries more comprehensible. For example, this query is
equivalent to the previous example:

```SQL
SELECT * FROM contacts WHERE name = $searchString OR email = $searchString
```

Rather than binding an index, you bind it's name:

```swift
statement.bindStringParameter("johnny.appleseed@apple.com", named:"$searchString", error:&error)
```

Note that the `$` character must be included. SQLite also supports named parameters of the form `:NAME` or `@NAME`. See
the [SQLite documentation](http://www.sqlite.org/lang_expr.html#varparam) for authoritative details.

#### Types that can be bound

SQLite supports TEXT, INTEGER, REAL, BLOB, and NULL values. The Squeal methods to bind these are:

* `Statement.bindStringValue(stringValue:atIndex:error:)`
* `Statement.bindInt64Value(int64Value:atIndex:error:)`
* `Statement.bindDoubleValue(doubleValue:atIndex:error:)`
* `Statement.bindBlobValue(blobValue:atIndex:error:)`
* `Statement.bindNullValue(atIndex:error:)`

##### `Bindable`

The above methods are the core methods used to bind parameters. Squeal also provides helpers for binding arbitrary 
types, as well as multiple parameters at once:

* `Statement.bindParameter(name:value:error:)`
* `Statement.bind(parameters:error:)`
* `Statement.bind(namedParameters:error:)`

These methods can bind any type that conforms to the `Bindable` protocol. Currently there are `Bindable` implementations
for these types:

* String
* Int, Int32, Int64, and all other native integer types
* Bool
* Double
* Float
* NSData

If you'd like to support binding other types (e.g. NSDate) then you can do so by implementing the `Bindable` protocol,
and calling one of the core methods listed above.

### Reuse statements for efficiency

`Statement` objects can be re-executed multiple times. If your app executes the same queries many times, this will
increase performance by reducing the amount of time spent parsing SQL. Different parameters can be set each time a
statement is executed. 

To reuse a statement, invoke `reset(error:)`:

```swift
statement.reset(&error)
```

**Resetting a statement does not clear parameters**. To clear all parameters, invoke `clearParameters()`:

```swift
statement.reset(&error)
statement.clearParameters()
```

### Use Squeal from the command line, or a Playground

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

