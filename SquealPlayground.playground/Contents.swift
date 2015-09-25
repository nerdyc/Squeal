/*:
## Setup

After adding Squeal to your project, you should be able to import it like this:
*/
import Squeal
/*:
 
## Accessing a Database

Databases are accessed through the `Database` class. Squeal supports creating on-disk, temporary, and in-memory databases. When creating an on-disk database, the database will be created if needed. Though it will fail if any directories in the path don't exist.

*/

let db       = Database() // in-memory db
let onDiskDB = try Database(path:"contacts.db")

/*:
## Executing SQL Statements
The above examples showcased Swift helpers provided by Squeal to execute the most common types of SQL statements. Squeal also provides methods for executing any SQL statement you need to.

For non-SELECT statements, the simplest way to execute a statement is via the `Database.execute(sqlString:)` method:
*/

//try db.execute("VACUUM")
//try db.execute("PRAGMA journal_mode=WAL")

/*:
## Querying a Database

When performing SELECT statements, the statement should be prepared first.
*/

let results = try db.prepareStatement("SELECT 'Amelia Grey' as name")

/*:
After being prepared, results can be iterated via the `next` method.
*/

while try results.next() {
    let name = results["name"] as! String
    let name2 = results.stringValue("name")
    
    let name3 = results[0] as! String
    let name4 = results.stringValueAtIndex(0)
}

/*:
## Helper Methods

Beyond its basic usage, Squeal provides helper methods to make executing common SQL operations easier.

### Creating Tables & Indices

Once you've created your database, you'll need to create the tables that structure your data, and the indices that speed up access to that data.

*/

try db.createTable("people",
                   definitions:[
                        "personId INTEGER PRIMARY KEY",
                        "name TEXT",
                        "email TEXT NOT NULL",
                        "UNIQUE(email)",
                        "CHECK (name IS NOT NULL OR email IS NOT NULL)"
                   ],
                   ifNotExists:true)

try db.createIndex("people_name", tableName: "people", columns: ["name"], ifNotExists:true)

/*:
### Inspecting the Schema
*/

let tableNames = db.schema.tableNames
let indexNames = db.schema.indexNames

/*:
### Migrations

As your app evolves, your database schema will need to change. SQLite databases support a "User Version Number" that can be used to set and check the version of the database.
*/
let currentVersion = try db.queryUserVersionNumber()
if currentVersion < 2 {
    try db.transaction { _ in
        try db.createTable("companies",
                           definitions: ["companyId INTEGER PRIMARY KEY",
                                         "name TEXT NOT NULL",
                                         "domain TEXT"])
        
        try db.updateUserVersionNumber(2)
    }
}
let updatedVersion = try db.queryUserVersionNumber()

/*:
### Inserting Rows
*/

let ameliaId = try db.insertInto("people",
                                 values: [ "name":"Amelia Grey",
                                           "email":"amelia@gastrobot.xyz" ])

let brianId = try db.insertInto("people",
                                columns: ["name", "email"],
                                values: [ "Brian Lennon", "brian@gastrobot.xyz" ])

/*:
### Updating Rows
*/

let numberOfUpatedRows = try db.update("people",
                                       set: ["email":"brian.lennon@gastrobot.xyz"],
                                       whereExpr: "personId = ?",
                                       parameters: [brianId])

/*:
### Deleting Rows
*/

let numberOfDeletedRows = try db.deleteFrom("people",
                                            whereExpr: "email = ?",
                                            parameters: ["brian.lennon@gastrobot.xyz"])


/*:
 ### Selecting Rows
 */

let emails =
    try db.selectFrom("people", whereExpr:"name LIKE 'amelia%'") { $0["email"] }
