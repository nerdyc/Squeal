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
