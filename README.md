# Squeal

Squeal allows [sqlite](http://www.sqlite.org/) databases to be created and accessed with [Swift](https://developer.apple.com/swift/).

## Use the Database class to create and open databases

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

Closing a database will attempt to close all outstanding `Statement` objects, but may fail if the database is still
being used elsewhere in your app.

## Prepare Statement objects to execute SQL

Once a database has been opened, SQL commands and queries can be executed through `Statement` objects.

`Statement` objects are created by the `Database.prepareStatement()` method:

```swift
var error : NSError?
let statement = database.prepareStatement("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)",
                                          error:&error)
if statement == nil {
    // handle error
}
```

Preparing a statement compiles and validates the SQL string, but does not execute it. `sqlite` compiles SQL strings into
an internal executable representation. Think of `Statement` objects like mini computer programs.

Once prepared, statements are executed through the `Statement.execute(error:)` or `Statement.query(error:)` methods. `Statement` objects are reusable, and are more efficient when reused. See below for details.

Once a `Statement` is no longer needed, it must be closed to release its resources:

```swift
statement.close()
```

After closing a `Statement`, it is unusable and should be discarded.

## Use `Statement.execute(:error)` to perform updates

Any SQL statement that is not a `SELECT` should use the `execute(error:)` method:

```swift
let executeSucceeded = statement.execute(&error)
```

## Use `Statement.next(:error)` to query the database

`SELECT` statements are special because they return data. To execute a query and iterate through the results, use the
`Statement.next(error:)` method after preparing a statement:

```swift
var error : NSError?
if let statement = database.prepareStatement("SELECT name FROM contacts", error:&error) {
    while true {
        if let hasRow = statement.next(&error) {
            if hasRow {
                // process the row
                var contactName = statement.stringValue("name")
            } else {
                // no more data
            }
        } else {
            // handle error
        }
    }
}
```

As mentioned above, you can think of `Statement` objects as mini programs. The `next(error:)` method is like stepping 
through that program in a debugger. At each step, we call `next(error:)` to advance to the next row. A `Bool?` will be 
returned to indicate whether another row was returned (`true`), all data has been consumed (`false`), or an error 
occured (`nil`).

## Use parameters in SQL to simplify escaping and avoid injection attacks

`sqlite` supports parameratized SQL statements, like `SELECT * FROM contacts WHERE name = ?`. When compiled into a `Statement` object, you can specify the value for the `?` separately by *binding* a value for it. This help to avoid the need to escape values when constructing SQL, and allows compiled statements to be reused many times.

For example:

```swift
var error : NSError?
if let statement = database.prepareStatement("SELECT * FROM contacts WHERE name = ?",
                                             error:&error) {
    
    if (statement.bindStringParameter("Steve Jobs", atIndex:1, error:&error)) {
        while true {
            if let hasNext = statement.next(&error) {
                if hasNext {
                    let contactId = statement.intValue("contactId")
                    // ...
                }
            }
        }
    }
}
```

Note that **parameters are 1-based**. Binding a parameter at index '0' will always fail.

`sqlite` also supports inserting an indexed parameter multiple times. This is best shown by example: 

```sql
SELECT * FROM contacts WHERE name = ?1 OR email = ?1
```

This statment only one parameter, and will match any contact whose name or email matches the first parameter. 

### Named Parameters

`sqlite` supports parameters like `$NAME`, which can make longer queries more comprehensible. For example, this query is
equivalent to the previous example:

```SQL
SELECT * FROM contacts WHERE name = $searchString OR email = $searchString
```

Rather than binding an index, you bind it's name:

```swift
statement.bindStringParameter("johnny.appleseed@apple.com", named:"$searchString", error:&error)
```

Note that the `$` character must be included. sqlite also supports named parameters of the form `:NAME` or `@NAME`. See the [sqlite documentation](http://www.sqlite.org/docs.html) for authoritative details.

## Reuse statements for efficiency

`Statement` objects can be re-executed multiple times. If your app executes the same queries many times, this will increase performance by reducing the amount of time spent parsing SQL. Different parameters can be set each time a statement is executed. 

To reuse a statement, invoke `reset(error:)`:

```swift
statement.reset(&error)
```

**Resetting a statement does not clear parameters**. To clear all parameters, invoke `clearParameters()`:

```swift
statement.reset(&error)
statement.clearParameters()
```

## Use Squeal from the command line, or a Playground

Accessing Squeal from a playground, or the command-line REPL isn't possible right now. Squeal relies on a custom module.map to access sqlite from Swift, and this isn't supported in the XCode betas (yet?).

Any suggestions for a workaround would be appreciated!

