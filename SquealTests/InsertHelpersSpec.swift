import Quick
import Nimble
import Squeal
import SquealSpecHelpers

class InsertHelpersSpec: QuickSpec {
    override func spec() {
        var database : Database!
        
        beforeEach {
            database = Database()
        }
        
        afterEach {
            database = nil
        }
        
        describe(".insertInto(tableName:columns:values:error:)") {
            
            var result : Int64?
            
            beforeEach {
                try! database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)")
                result = try! database.insertInto("contacts",
                                                  columns:["name"],
                                                  values:["Amelia"])
            }
            
            it("inserts the row into the table, and returns its row id") {
                expect(result).to(equal(1))

                let contacts = try! database.queryRows("SELECT * FROM contacts")
                expect(contacts.count).to(equal(1))
                
                expect(contacts.first?["contactId"] as? Int64).to(equal(1))
                expect(contacts.first?["name"] as? String).to(equal("Amelia"))
            }
            
        }
        
        describe(".insertInto(tableName:values:error:") {
            
            var result : Int64?

            beforeEach {
                try! database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT, title TEXT)")
            }

            describe("when all values are non-nil") {
            
                beforeEach {
                    result = try! database.insertInto("contacts", values:["name":"Amelia"])
                }
                
                it("inserts the row into the table, and returns its row id") {
                    expect(result).to(equal(1))
                    
                    let contacts = try! database.queryRows("SELECT * FROM contacts")
                    expect(contacts.count).to(equal(1))
                    
                    expect(contacts.first?["contactId"] as? Int64).to(equal(1))
                    expect(contacts.first?["name"] as? String).to(equal("Amelia"))
                }
            
            }
            
            describe("when a value is nil") {
                
                beforeEach {
                    result = try! database.insertInto("contacts", values:["title": nil, "name":"Amelia"])
                }
                
                it("inserts the row into the table, and returns its row id") {
                    expect(result).to(equal(1))
                    
                    let contacts = try! database.queryRows("SELECT * FROM contacts")
                    expect(contacts.count).to(equal(1))
                    
                    expect(contacts.first?["contactId"] as? Int64).to(equal(1))
                    expect(contacts.first?["name"] as? String).to(equal("Amelia"))
                    expect(contacts.first?["title"] as? String).to(beNil())
                }

            }
            
        }
        
    }
}
