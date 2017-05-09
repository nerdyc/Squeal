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
        id = row.value("id") ?? 0
        name = row.value("name")
        email = row.value("email") ?? ""
    }
}

let contacts:[Contact] = try db.select(
    from:"contacts",
    where:"name IS NOT NULL",
    block: Contact.init
)

// Count:
let numberOfContacts = try db.count(from:"contacts")
