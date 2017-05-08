import Quick
import Nimble
import Squeal

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
        
        describe(".deleteFrom(from:where:parameters:)") {
            
            beforeEach {
                try! database.execute("CREATE TABLE contacts (contactId INTEGER PRIMARY KEY, name TEXT)")
                try! database.insertInto("contacts", values:["name": "Amelia"])
                try! database.insertInto("contacts", values:["name": "Brian"])
                try! database.insertInto("contacts", values:["name": "Cara"])
                
                result = try! database.delete(from:"contacts",
                                              where: "name IS ?",
                                              parameters:["Brian"])
            }
            
            it("deletes the matching values in the database") {
                let values = try! database.select(from:"contacts") { $0["name"] as! String }
                
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
                
                result = try! database.delete(from:"contacts", rowIds: [2])
            }
            
            it("deletes the matching values in the database") {
                let values = try! database.select(from:"contacts") { $0["name"] as! String }
                
                expect(result).to(equal(1))
                expect(values).to(equal(["Amelia", "Cara"]))
            }
            
        }
        
    }
}
