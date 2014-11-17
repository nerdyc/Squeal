import Quick
import Nimble
import Squeal
import SquealSpecHelpers

class StatementSpec: QuickSpec {
    override func spec() {
        
        var database : Database!
        var statement : Statement!
        var error : NSError?
        
        beforeEach {
            database = Database.openTemporaryDatabase()
            database.executeOrFail("CREATE TABLE people (personId INTEGER PRIMARY KEY, name TEXT, age REAL, is_adult INTEGER, photo BLOB)")
            database.executeOrFail("INSERT INTO people (name, age, is_adult, photo) VALUES (\"Amelia\", 1.5, 0, NULL),(\"Brian\", 43.375, 1, X''),(\"Cara\", NULL, 1, X'696D616765')")
            // 696D616765 is "image" in Hex.
        }
        
        afterEach {
            statement = nil
            database = nil
            error = nil
        }
        
#if arch(x86_64) || arch(arm64)
// this test only works on 64-bit architectures because weak references are cleared immediately on 640bit runtimes, but
// not on 32-bit. Probably because of tagged pointers?
        it("retains the database until the statement has been finalized") {
            statement = database.prepareStatement("SELECT personId, name, age, photo FROM people")
            weak var db = database
            
            // remove the last non-weak external reference to the database; only the statement has retained it.
            database = nil
            expect(db).notTo(beNil())
            
            // now release the statement, which should release the last hold on the database.
            statement = nil
            expect(db).to(beNil())
        }
#endif
        
        // =============================================================================================================
        // MARK:- Columns
        
        describe(".columnCount, .columnNames, etc.") {
        
            beforeEach {
                statement = database.prepareStatement("SELECT personId, name, age, photo FROM people")
            }
            
            it("describe the selected columns") {
                expect(statement.columnCount).to(equal(4))
                expect(statement.columnNames).to(equal(["personId", "name", "age", "photo"]))
                
                expect(statement.indexOfColumnNamed("personId")).to(equal(0))
                expect(statement.indexOfColumnNamed("name")).to(equal(1))
                expect(statement.indexOfColumnNamed("age")).to(equal(2))
                expect(statement.indexOfColumnNamed("photo")).to(equal(3))
                
                expect(statement.nameOfColumnAtIndex(0)).to(equal("personId"));
                expect(statement.nameOfColumnAtIndex(1)).to(equal("name"));
                expect(statement.nameOfColumnAtIndex(2)).to(equal("age"));
                expect(statement.nameOfColumnAtIndex(3)).to(equal("photo"));
            }
            
        }
        
        // =============================================================================================================
        // MARK:- Current Row
        
        describe(".dictionaryValue") {

            beforeEach {
                statement = database.prepareStatement("SELECT personId, name, age, photo FROM people")
            }
            
            it("returns row values in a dictionary") {
                expect(statement.next()).to(equal(.Some(true)))
                
                // 0: id:1, name:Amelia, age:1.5, photo:NULL
                expect(statement.dictionaryValue["personId"] as? Int64).to(equal(1))
                expect(statement.dictionaryValue["name"] as? String).to(equal("Amelia"))
                expect(statement.dictionaryValue["age"] as? Double).to(equal(1.5))
                expect(statement.dictionaryValue["photo"]).to(beNil())
                
                // NULL columns aren't included in resulting dictionary
                expect(sorted(statement.dictionaryValue.keys)).to(equal(["age", "name", "personId"]))
            }
            
        }
        
        describe(".valueOf()") {
            beforeEach {
                statement = database.prepareStatement("SELECT personId, name, age, photo FROM people")
            }
            
            it("returns the value at the index") {
                expect(statement.next()).to(equal(.Some(true)))
                expect(statement.valueOf("personId") as? Int64).to(equal(1))
                expect(statement.valueOf("name") as? String).to(equal("Amelia"))
                expect(statement.valueOf("age") as? Double).to(equal(1.5))
                expect(statement.valueOf("photo")).to(beNil())
            }
            
        }
        
        describe(".[columnName]") {
            beforeEach {
                statement = database.prepareStatement("SELECT personId, name, age, photo FROM people")
            }
            
            it("returns the value at the index") {
                expect(statement.next()).to(equal(.Some(true)))
                expect(statement["personId"] as? Int64).to(equal(1))
                expect(statement["name"] as? String).to(equal("Amelia"))
                expect(statement["age"] as? Double).to(equal(1.5))
                expect(statement["photo"]).to(beNil())
            }
        }

        describe(".values") {
            
            beforeEach {
                statement = database.prepareStatement("SELECT personId, name, age, photo FROM people")
            }
            
            it("returns row values in a dictionary") {
                expect(statement.next()).to(equal(.Some(true)))
                
                // 0: id:1, name:Amelia, age:1.5, photo:NULL
                expect(statement.values[0] as? Int64).to(equal(1))
                expect(statement.values[1] as? String).to(equal("Amelia"))
                expect(statement.values[2] as? Double).to(equal(1.5))
                expect(statement.values[3]).to(beNil())
            }
            
        }
        
        describe(".valueAtIndex(columnIndex:)") {
            beforeEach {
                statement = database.prepareStatement("SELECT personId, name, age, photo FROM people")
            }
            
            it("returns the value at the index") {
                expect(statement.next()).to(equal(.Some(true)))
                expect(statement.valueAtIndex(0) as? Int64).to(equal(1))
                expect(statement.valueAtIndex(1) as? String).to(equal("Amelia"))
                expect(statement.valueAtIndex(2) as? Double).to(equal(1.5))
                expect(statement.valueAtIndex(3)).to(beNil())
            }
            
        }
        
        describe(".[columnIndex]") {
            beforeEach {
                statement = database.prepareStatement("SELECT personId, name, age, photo FROM people")
            }
            
            it("returns the value at the index") {
                expect(statement.next()).to(equal(.Some(true)))
                expect(statement[0] as? Int64).to(equal(1))
                expect(statement[1] as? String).to(equal("Amelia"))
                expect(statement[2] as? Double).to(equal(1.5))
                expect(statement[3]).to(beNil())
            }
        }

        // =============================================================================================================
        // MARK:- STEPS
        
        describe(".query(error:)") {
            beforeEach {
                statement = database.prepareStatement("SELECT personId, name, age, photo FROM people WHERE personId > ?")
            }
            
            it("iterates through each row of the statement") {
                statement.bindOrFail(1)
                
                var ids = [RowId]()
                for s in statement.query(error:&error) {
                    expect(s).notTo(beNil())
                    expect(error).to(beNil())
                    
                    ids.append(s?.int64ValueAtIndex(0) ?? 0)
                }
                expect(ids).to(equal([2, 3]))
                
                // now prove that it resets the statement
                ids.removeAll()
                for s in statement.query(error:&error) {
                    expect(s).notTo(beNil())
                    expect(error).to(beNil())
                    
                    ids.append(s?.int64ValueAtIndex(0) ?? 0)
                }
                expect(ids).to(equal([2, 3]))
            }
        }
        
        describe(".query(parameters:error:)") {
            beforeEach {
                statement = database.prepareStatement("SELECT personId, name, age, photo FROM people WHERE personId > ?")
            }
            
            it("clears parameters and iterates through each step of the statement") {
                statement.bindOrFail(3) // bind another value to prove the value is cleared
                
                var ids = [RowId]()
                for s in statement.query(parameters:[1], error:&error) {
                    expect(s).notTo(beNil())
                    expect(error).to(beNil())
                    
                    ids.append(s?.int64ValueAtIndex(0) ?? 0)
                }
                expect(ids).to(equal([2, 3]))
            }
        }
        
        describe(".generate()") {
            
            beforeEach {
                statement = database.prepareStatement("SELECT personId, name, age, photo FROM people WHERE personId > ?")
            }
            
            it("is an alias for .query") {
                statement.bindOrFail(1)
                
                var ids = [RowId]()
                for row in statement {
                    expect(row).notTo(beNil())
                    expect(error).to(beNil())
                    
                    ids.append(row?["personId"] as RowId)
                }
                expect(ids).to(equal([2, 3]))
            }
            
        }
        
        describe("next(error:)") {
            
            beforeEach {
                statement = database.prepareStatement("SELECT personId, name, age, photo FROM people")
            }
            
            it("advances to the next row, returning false when there are no more rows") {
                expect(statement.next()).to(equal(.Some(true)))
                
                // 0: id:1, name:Amelia, age:1.5, photo:NULL
                expect(statement.intValueAtIndex(0)).to(equal(1))
                expect(statement.intValue("personId")).to(equal(1))
                expect(statement.stringValueAtIndex(1)).to(equal("Amelia"))
                expect(statement.stringValue("name")).to(equal("Amelia"))
                expect(statement.realValueAtIndex(2)).to(equal(1.5))
                expect(statement.realValue("age")).to(equal(1.5))
                expect(statement.blobValueAtIndex(3)).to(beNil())
                expect(statement.blobValue("photo")).to(beNil())
                
                // 1: id:2, Brian, age:43.375, photo:''
                expect(statement.next()).to(equal(.Some(true)))
                expect(statement.intValueAtIndex(0)).to(equal(2))
                expect(statement.intValue("personId")).to(equal(2))
                expect(statement.stringValueAtIndex(1)).to(equal("Brian"))
                expect(statement.stringValue("name")).to(equal("Brian"))
                expect(statement.realValueAtIndex(2)).to(equal(43.375))
                expect(statement.realValue("age")).to(equal(43.375))
                expect(statement.blobValueAtIndex(3)).to(equal(NSData()))
                expect(statement.blobValue("photo")).to(equal(NSData()))
                
                // 2: id:3, name:Cara, age:nil, photo:X'696D616765' ("image")
                expect(statement.next()).to(equal(.Some(true)))
                expect(statement.intValueAtIndex(0)).to(equal(3))
                expect(statement.intValue("personId")).to(equal(3))
                expect(statement.stringValueAtIndex(1)).to(equal("Cara"))
                expect(statement.stringValue("name")).to(equal("Cara"))
                expect(statement.realValueAtIndex(2)).to(beNil())
                expect(statement.realValue("age")).to(beNil())
                expect(statement.blobValueAtIndex(3)).to(equal("image".dataUsingEncoding(NSUTF8StringEncoding)))
                expect(statement.blobValue("photo")).to(equal("image".dataUsingEncoding(NSUTF8StringEncoding)))
                
                expect(statement.next()).to(equal(.Some(false)))
            }
            
        }
        

        
        // =============================================================================================================
        // MARK:- Parameters
        
        describe("reset()") {
            
            beforeEach {
                statement = database.prepareStatement("SELECT * FROM people WHERE name IS ?")
                statement.bindOrFail("Brian")
                statement.next()
                statement.reset()
            }
            
            it("resets the statement so it can be executed again") {
                expect(statement.next()).to(equal(.Some(true)))
                expect(statement.stringValue("name")).to(equal("Brian"))
            }
            
        }
        
        describe("parameterCount") {
            
            beforeEach {
                statement = database.prepareStatement("SELECT * FROM people WHERE name IS ? AND age > ?")
            }
            
            it("returns the number of parameters") {
                expect(statement.parameterCount).to(equal(2))
            }
            
        }
        
        // =============================================================================================================
        // MARK:- Named Parameters
        
        describe("indexOfParameterNamed(name:)") {
            beforeEach {
                statement = database.prepareStatement("SELECT * FROM people WHERE name IS $NAME")
            }
            
            it("returns the index of the parameter when it exists") {
                expect(statement.indexOfParameterNamed("$NAME")).to(equal(1))
            }
            
            it("returns nil when it doesn't exist") {
                expect(statement.indexOfParameterNamed("$NOPE")).to(beNil())
            }
        }
        
    }
}

