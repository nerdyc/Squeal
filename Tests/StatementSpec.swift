import Quick
import Nimble
import Squeal

class StatementSpec: QuickSpec {
    override func spec() {
        
        var database : Database!
        var statement : Statement!
        
        beforeEach {
            database = Database()
            try! database.execute("CREATE TABLE people (personId INTEGER PRIMARY KEY, name TEXT, age REAL, is_adult INTEGER, photo BLOB)")
            try! database.execute("INSERT INTO people (name, age, is_adult, photo) VALUES (\"Amelia\", 1.5, 0, NULL),(\"Brian\", 43.375, 1, X''),(\"Cara\", NULL, 1, X'696D616765')")
            // 696D616765 is "image" in Hex.
        }
        
        afterEach {
            statement = nil
            database = nil
        }
        
#if arch(x86_64) || arch(arm64)
// this test only works on 64-bit architectures because weak references are cleared immediately on 64-bit runtimes, but
// not on 32-bit. Probably because of tagged pointers?
        it("retains the database until the statement has been finalized") {
            statement = try! database.prepareStatement("SELECT personId, name, age, photo FROM people")
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
                statement = try! database.prepareStatement("SELECT personId, name, age, photo FROM people")
            }
            
            it("describe the selected columns") {
                expect(statement.columnCount).to(equal(4))
                expect(statement.columnNames).to(equal(["personId", "name", "age", "photo"]))
                
                expect(statement.indexOfColumn(named: "personId")).to(equal(0))
                expect(statement.indexOfColumn(named: "name")).to(equal(1))
                expect(statement.indexOfColumn(named: "age")).to(equal(2))
                expect(statement.indexOfColumn(named: "photo")).to(equal(3))
                
                expect(statement.nameOfColumn(atIndex:0)).to(equal("personId"));
                expect(statement.nameOfColumn(atIndex:1)).to(equal("name"));
                expect(statement.nameOfColumn(atIndex:2)).to(equal("age"));
                expect(statement.nameOfColumn(atIndex:3)).to(equal("photo"));
            }
            
        }
        
        // =============================================================================================================
        // MARK:- Current Row
        
        describe(".dictionaryValue") {

            beforeEach {
                statement = try! database.prepareStatement("SELECT personId, name, age, photo FROM people")
            }
            
            it("returns row values in a dictionary") {
                expect(try! statement.next()).to(beTruthy())
                
                // 0: id:1, name:Amelia, age:1.5, photo:NULL
                expect(statement.dictionaryValue["personId"] as? Int64).to(equal(1))
                expect(statement.dictionaryValue["name"] as? String).to(equal("Amelia"))
                expect(statement.dictionaryValue["age"] as? Double).to(equal(1.5))
                expect(statement.dictionaryValue["photo"]).to(beNil())
                
                // NULL columns aren't included in resulting dictionary
                expect(statement.dictionaryValue.keys.sorted()).to(equal(["age", "name", "personId"]))
            }
            
        }
        
        describe(".bindableValue()") {
            beforeEach {
                statement = try! database.prepareStatement("SELECT personId, name, age, photo FROM people")
            }
            
            it("returns the value at the index") {
                expect(try! statement.next()).to(equal(true))
                expect(statement.bindableValue("personId") as? Int64).to(equal(1))
                expect(statement.bindableValue("name") as? String).to(equal("Amelia"))
                expect(statement.bindableValue("age") as? Double).to(equal(1.5))
                expect(statement.bindableValue("photo")).to(beNil())
            }
            
        }
        
        describe(".[columnName]") {
            beforeEach {
                statement = try! database.prepareStatement("SELECT personId, name, age, photo FROM people")
            }
            
            it("returns the value at the index") {
                expect(try! statement.next()).to(equal(true))
                expect(statement["personId"] as? Int64).to(equal(1))
                expect(statement["name"] as? String).to(equal("Amelia"))
                expect(statement["age"] as? Double).to(equal(1.5))
                expect(statement["photo"]).to(beNil())
            }
        }

        describe(".arrayValue") {
            
            beforeEach {
                statement = try! database.prepareStatement("SELECT personId, name, age, photo FROM people")
            }
            
            it("returns row values in a dictionary") {
                expect(try! statement.next()).to(equal(true))
                
                // 0: id:1, name:Amelia, age:1.5, photo:NULL
                expect(statement.arrayValue[0] as? Int64).to(equal(1))
                expect(statement.arrayValue[1] as? String).to(equal("Amelia"))
                expect(statement.arrayValue[2] as? Double).to(equal(1.5))
                expect(statement.arrayValue[3]).to(beNil())
            }
            
        }
        
        describe(".bindableValue(atIndex:)") {
            beforeEach {
                statement = try! database.prepareStatement("SELECT personId, name, age, photo FROM people")
            }
            
            it("returns the value at the index") {
                expect(try! statement.next()).to(equal(true))
                expect(statement.bindableValue(atIndex:0) as? Int64).to(equal(1))
                expect(statement.bindableValue(atIndex:1) as? String).to(equal("Amelia"))
                expect(statement.bindableValue(atIndex:2) as? Double).to(equal(1.5))
                expect(statement.bindableValue(atIndex:3)).to(beNil())
            }
            
        }
        
        describe(".[columnIndex]") {
            beforeEach {
                statement = try! database.prepareStatement("SELECT personId, name, age, photo FROM people")
            }
            
            it("returns the value at the index") {
                expect(try! statement.next()).to(equal(true))
                expect(statement[0] as? Int64).to(equal(1))
                expect(statement[1] as? String).to(equal("Amelia"))
                expect(statement[2] as? Double).to(equal(1.5))
                expect(statement[3]).to(beNil())
            }
        }

        // =============================================================================================================
        // MARK:- STEPS
        
        describe(".select()") {
            beforeEach {
                statement = try! database.prepareStatement("SELECT personId, name, age, photo FROM people WHERE personId > ?")
                try! statement.bind([1])
            }
            
            it("iterates through each row of the statement") {
                let ids = try! statement.select { $0.int64Value(atIndex:0) ?? 0 }
                expect(ids).to(equal([2, 3]))
                
                // now prove that it resets the statement
                let sameIds = try! statement.select { $0.int64Value(atIndex:0) ?? 0 }
                expect(sameIds).to(equal([2, 3]))
            }
        }
        
        describe(".query(parameters:)") {
            beforeEach {
                statement = try! database.prepareStatement("SELECT personId, name, age, photo FROM people WHERE personId > ?")
            }
            
            it("clears parameters and iterates through each step of the statement") {
                try! statement.bind([3]) // bind another value to prove the value is cleared
                
                let ids = try! statement.select([1]) { $0.int64Value(atIndex:0) ?? 0 }
                expect(ids).to(equal([2, 3]))
            }
        }
        
        describe("next()") {
            
            beforeEach {
                statement = try! database.prepareStatement("SELECT personId, name, age, photo FROM people")
            }
            
            it("advances to the next row, returning false when there are no more rows") {
                expect(try! statement.next()).to(equal(true))
                
                // 0: id:1, name:Amelia, age:1.5, photo:NULL
                expect(statement.intValue(atIndex:0)).to(equal(1))
                expect(statement.intValue("personId")).to(equal(1))
                expect(statement.stringValue(atIndex:1)).to(equal("Amelia"))
                expect(statement.stringValue("name")).to(equal("Amelia"))
                expect(statement.doubleValue(atIndex:2)).to(equal(1.5))
                expect(statement.doubleValue("age")).to(equal(1.5))
                expect(statement.blobValue(atIndex:3)).to(beNil())
                expect(statement.blobValue("photo")).to(beNil())
                
                // 1: id:2, Brian, age:43.375, photo:''
                expect(try! statement.next()).to(equal(true))
                expect(statement.intValue(atIndex:0)).to(equal(2))
                expect(statement.intValue("personId")).to(equal(2))
                expect(statement.stringValue(atIndex:1)).to(equal("Brian"))
                expect(statement.stringValue("name")).to(equal("Brian"))
                expect(statement.doubleValue(atIndex:2)).to(equal(43.375))
                expect(statement.doubleValue("age")).to(equal(43.375))
                expect(statement.blobValue(atIndex:3)).to(equal(Data()))
                expect(statement.blobValue("photo")).to(equal(Data()))
                
                // 2: id:3, name:Cara, age:nil, photo:X'696D616765' ("image")
                expect(try! statement.next()).to(equal(true))
                expect(statement.intValue(atIndex:0)).to(equal(3))
                expect(statement.intValue("personId")).to(equal(3))
                expect(statement.stringValue(atIndex:1)).to(equal("Cara"))
                expect(statement.stringValue("name")).to(equal("Cara"))
                expect(statement.doubleValue(atIndex:2)).to(beNil())
                expect(statement.doubleValue("age")).to(beNil())
                expect(statement.blobValue(atIndex:3)).to(equal("image".data(using: String.Encoding.utf8)))
                expect(statement.blobValue("photo")).to(equal("image".data(using: String.Encoding.utf8)))
                
                expect(try! statement.next()).to(equal(false))
            }
            
        }
        

        
        // =============================================================================================================
        // MARK:- Parameters
        
        describe("reset()") {
            
            beforeEach {
                statement = try! database.prepareStatement("SELECT * FROM people WHERE name IS ?")
                try! statement.bind(["Brian"])
                expect(try! statement.next()) == true
                try! statement.reset()
            }
            
            it("resets the statement so it can be executed again") {
                expect(try! statement.next()).to(equal(true))
                expect(statement.stringValue("name")).to(equal("Brian"))
            }
            
        }
        
        describe("parameterCount") {
            
            beforeEach {
                statement = try! database.prepareStatement("SELECT * FROM people WHERE name IS ? AND age > ?")
            }
            
            it("returns the number of parameters") {
                expect(statement.parameterCount).to(equal(2))
            }
            
        }
        
        // =============================================================================================================
        // MARK:- Named Parameters
        
        describe("indexOfParameterNamed(name:)") {
            beforeEach {
                statement = try! database.prepareStatement("SELECT * FROM people WHERE name IS $NAME")
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

