import Quick
import Nimble
import Squeal

class DatabaseContentSpec: QuickSpec {
    override func spec() {
        var database : Database!
        var statement : Statement!
        var error : NSError?
        
        beforeEach {
            database = Database.newTemporaryDatabase()
            database.open()
        }
        
        afterEach {
            if (statement != nil && statement.isOpen) {
                statement.close()
            }
            statement = nil
            
            if database.isOpen {
                database.close(nil)
            }
            database = nil
            
            error = nil
        }
        
        // =============================================================================================================
        // MARK:- Insert
        
        describe(".insertRow(tableName:columns:values:error:") {
            
            var result : Int64?
            
            beforeEach {
                database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)")
                result = database.insertRow("contacts",
                                            columns:["name"],
                                            values:["Amelia"],
                                            error:&error)
            }
            
            it("inserts the row into the table, and returns its row id") {
                expect(result).to(equal(1))
                expect(error).to(beNil())
                
                let query = database.query("SELECT * FROM contacts")
                expect(query.next()).to(beTruthy())
                expect(query.intValue("contactId")).to(equal(1))
                expect(query.stringValue("name")).to(equal("Amelia"))

                expect(query.next()).to(beFalsy())
            }
            
        }
        
        describe(".insertRow(tableName:values:error:") {
            
            var result : Int64?
            
            beforeEach {
                database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)")
                result = database.insertRow("contacts", values:["name":"Amelia"], error:&error)
            }
            
            it("inserts the row into the table, and returns its row id") {
                expect(result).to(equal(1))
                expect(error).to(beNil())
                
                let query = database.query("SELECT * FROM contacts")
                expect(query.next()).to(beTruthy())
                expect(query.intValue("contactId")).to(equal(1))
                expect(query.stringValue("name")).to(equal("Amelia"))
                
                expect(query.next()).to(beFalsy())
            }
            
        }
        
    }
}
