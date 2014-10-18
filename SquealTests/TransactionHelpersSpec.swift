import Quick
import Nimble
import Squeal
import SquealSpecHelpers

class TransactionHelpersSpec: QuickSpec {
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
        
        describe(".transaction()") {
            
            beforeEach {
                database.executeOrFail("CREATE TABLE people (id PRIMARY KEY, name TEXT)")
            }
            
            context("when the transaction is committed") {
                
                it("persists all changes") {
                    var result = database.transaction {
                        $0.insert("people", row: ["name":"Amelia"])
                        $0.insert("people", row: ["name":"Brian"])
                        $0.insert("people", row: ["name":"Cara"])
                        
                        return .Commit
                    }
                    
                    expect(database.countFrom("people")).to(equal(3))
                }
                
            }
            
            context("when the transaction is rolled back") {
                
                it("discards changes") {
                    var result = database.transaction {
                        $0.insert("people", row: ["name":"Amelia"])
                        $0.insert("people", row: ["name":"Brian"])
                        $0.insert("people", row: ["name":"Cara"])
                        
                        return .Rollback
                    }
                    
                    expect(database.countFrom("people")).to(equal(0))
                }
                
            }
            
        }
        
    }
}
