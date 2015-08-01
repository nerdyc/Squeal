import Quick
import Nimble
import Squeal
import SquealSpecHelpers

class DeleteHelpersSpec: QuickSpec {
    override func spec() {
        var database : Database!
        var result : Int?
        
        beforeEach {
            result = nil
            database = Database()
        }
        
        afterEach {
            database = nil
        }
        
        describe(".deleteFrom(tableName:whereExpr:parameters:error:)") {
            
            beforeEach {
                try! database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)")
                try! database.insertInto("contacts", values:["name": "Amelia"])
                try! database.insertInto("contacts", values:["name": "Brian"])
                try! database.insertInto("contacts", values:["name": "Cara"])
                
                result = try! database.deleteFrom("contacts",
                                                  whereExpr: "name IS ?",
                                                  parameters:["Brian"])
            }
            
            it("deletes the matching values in the database") {
                let values = try! database.queryFrom("contacts") { $0["name"] as! String }
                
                expect(result).to(equal(1))
                expect(values).to(equal(["Amelia", "Cara"]))
            }
            
        }
        
        describe(".deleteFrom(tableName:rowIds:error:)") {
            
            beforeEach {
                try! database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)")
                try! database.insertInto("contacts", values:["name": "Amelia"])
                try! database.insertInto("contacts", values:["name": "Brian"])
                try! database.insertInto("contacts", values:["name": "Cara"])
                
                result = try! database.deleteFrom("contacts",
                                                  rowIds: [2])
            }
            
            it("deletes the matching values in the database") {
                let values = try! database.queryFrom("contacts") { $0["name"] as! String }
                
                expect(result).to(equal(1))
                expect(values).to(equal(["Amelia", "Cara"]))
            }
            
        }
        
    }
}
