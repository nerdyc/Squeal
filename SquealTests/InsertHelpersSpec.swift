import Quick
import Nimble
import Squeal
import SquealSpecHelpers

class InsertHelpersSpec: QuickSpec {
    override func spec() {
        var database : Database!
        var error : NSError?
        
        beforeEach {
            database = Database.openTemporaryDatabase()
        }
        
        afterEach {
            database = nil
            error = nil
        }
        
        describe(".insertInto(tableName:columns:values:error:") {
            
            var result : Int64?
            
            beforeEach {
                database.executeOrFail("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)")
                result = database.insertInto("contacts",
                                            columns:["name"],
                                            values:["Amelia"],
                                            error:&error)
            }
            
            it("inserts the row into the table, and returns its row id") {
                expect(result).to(equal(1))
                expect(error).to(beNil())
                
                let contacts = database.queryRows("SELECT * FROM contacts")
                expect(contacts).notTo(beNil())
                expect(contacts?.count).to(equal(1))
                
                expect(contacts?.first?["contactId"] as? Int64).to(equal(1))
                expect(contacts?.first?["name"] as? String).to(equal("Amelia"))
            }
            
        }
        
        describe(".insertInto(tableName:values:error:") {
            
            var result : Int64?
            
            beforeEach {
                database.executeOrFail("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)")
                result = database.insertInto("contacts", values:["name":"Amelia"], error:&error)
            }
            
            it("inserts the row into the table, and returns its row id") {
                expect(result).to(equal(1))
                expect(error).to(beNil())
                
                let contacts = database.queryRows("SELECT * FROM contacts")
                expect(contacts).notTo(beNil())
                expect(contacts?.count).to(equal(1))
                
                expect(contacts?.first?["contactId"] as? Int64).to(equal(1))
                expect(contacts?.first?["name"] as? String).to(equal("Amelia"))
            }
            
        }
        
    }
}
