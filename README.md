# Squeal

Squeal allows [sqlite](http://www.sqlite.org/) databases to be created and accessed with [Swift](https://developer.apple.com/swift/).

## Installation

1.  Clone this project into your project directory. E.g.:

    ```bash
    cd ~/SampleProject
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


Step #3 is necessary because sqlite is a library not a module. Swift can only import modules, and the `module.map` 
defines a module for sqlite so it can be imported into Swift code.

## Usage

### Use the Database class to create and open databases

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

### Prepare Statement objects to execute SQL

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

Preparing a statement compiles and validates the SQL string, but does not execute it. sqlite compiles SQL strings into
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

sqlite supports parameratized SQL statements, like `SELECT * FROM contacts WHERE name = ?`. When compiled into a
`Statement` object, you can specify the value for the `?` separately by *binding* a value for it. This help to avoid the
need to escape values when constructing SQL, and allows compiled statements to be reused many times.

For example:

```swift
var error : NSError?
if let statement = database.prepareStatement("SELECT * FROM contacts WHERE name = ?",
                                             error:&error) {
    
    if statement.bindStringParameter("Steve Jobs", atIndex:1, error:&error) {
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

sqlite also supports inserting an indexed parameter multiple times. This is best shown by example: 

```sql
SELECT * FROM contacts WHERE name = ?1 OR email = ?1
```

This statement has a single parameter that is inserted multiple times. It will match any contact whose name or email 
matches the first parameter. 

#### Named Parameters

sqlite supports parameters like `$NAME`, which can make longer queries more comprehensible. For example, this query is
equivalent to the previous example:

```SQL
SELECT * FROM contacts WHERE name = $searchString OR email = $searchString
```

Rather than binding an index, you bind it's name:

```swift
statement.bindStringParameter("johnny.appleseed@apple.com", named:"$searchString", error:&error)
```

Note that the `$` character must be included. sqlite also supports named parameters of the form `:NAME` or `@NAME`. See
the [sqlite documentation](http://www.sqlite.org/lang_expr.html#varparam) for authoritative details.

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
module.map to access sqlite from Swift, and this isn't supported in the XCode betas (yet?).

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
