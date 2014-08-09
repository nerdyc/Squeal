import Quick
import Nimble
import sqlite3
import Squeal
import Foundation

func createTemporaryDirectory(prefix:String = "Squeal") -> String {
    let suffix = NSUUID().UUIDString
    let tempDirectoryPath = NSTemporaryDirectory().stringByAppendingPathComponent(prefix + "-" + suffix)
    
    var error : NSError?
    var success = NSFileManager.defaultManager().createDirectoryAtPath(tempDirectoryPath,
                                                                       withIntermediateDirectories: true,
                                                                       attributes:                  nil,
                                                                       error:                       &error)
    if !success {
        NSException(name: NSInternalInconsistencyException,
                    reason: "Error creating temporary directory \(error)",
                    userInfo: nil).raise()
    }
    
    return tempDirectoryPath
}

extension Database {
    
    func open() {
        var error : NSError?
        if !open(&error) {
            NSException(name: NSInternalInconsistencyException,
                        reason: "Failed to open database: \(error?.localizedDescription)",
                        userInfo: nil).raise()
        }
    }
    
    func execute(statement:String) {
        var error : NSError?
        var resultSet = execute(statement, error:&error)
        
        if !resultSet {
            NSException(name:       NSInternalInconsistencyException,
                        reason:     "Failed to execute statement (\(statement)): \(error?.localizedDescription)",
                        userInfo:   nil).raise()
        }
    }
    
    func query(statement:String) -> ResultSet {
        var error : NSError?
        var resultSet = query(statement, error:&error)
        
        if resultSet == nil {
            NSException(name:       NSInternalInconsistencyException,
                        reason:     "Failed to query statement (\(statement)): \(error?.localizedDescription)",
                        userInfo:   nil).raise()
        }
        
        return resultSet!
    }
    
}

extension ResultSet {
    
    func next() -> Bool {
        var error : NSError? = nil
        var result = next(&error)
        if result == nil {
            NSException(name:       NSInternalInconsistencyException,
                        reason:     "Failed to advance result set: \(error?.localizedDescription)",
                        userInfo:   nil).raise()
            
            return false
        } else {
            return result!
        }
    }
    
}

class DatabaseSpec: QuickSpec {
    override func spec() {
        
        var database : Database!
        var tempPath : String!
        
        beforeEach {
            tempPath = createTemporaryDirectory()
            database = Database(path:tempPath + "/Squeal")
        }
        
        // =============================================================================================================
        // MARK:- Open
        
        describe("open()") {
            
            context("when the database doesn't exist") {
                
                beforeEach {
                    var error : NSError?
                    if !database.open(&error) {
                        NSException(name: NSInternalInconsistencyException,
                                    reason: "Unable to open database \(error)",
                                    userInfo: nil)
                    }
                }
                
                it("creates the database") {
                    expect(database.isOpen).to(beTruthy())
                    expect(NSFileManager.defaultManager().fileExistsAtPath(database.path)).to(beTruthy())
                }
                
            }
            
        }
        
        // =============================================================================================================
        // MARK:- Close
        
        describe("close()") {
            
            var result: Bool = false
            var error: NSError?
            var resultSet: ResultSet?
            
            beforeEach {
                database.open()
                database.execute("CREATE TABLE people (id PRIMARY KEY, name TEXT)")
                database.execute("INSERT INTO people(name) VALUES ('A'), ('B'), ('C')")
                resultSet = database.query("SELECT id,name FROM people")
                resultSet!.next()
                
                result = database.close(&error)
            }
            
            it("closes the database and any open result sets") {
                expect(result).to(beTruthy())
                expect(error).to(beNil())
                
                expect(resultSet!.isOpen).to(beFalsy())
                expect(resultSet!.columnCount).to(equal(0))
                expect(resultSet!.integerValueAtIndex(0)).to(beNil())
                expect(resultSet!.stringValueAtIndex(1)).to(beNil())
            }
            
        }
        
        // =============================================================================================================
        // MARK:- Execute
        
        describe("execute(sqlString:error:)") {
            
            var result : Bool = false
            var error : NSError?

            beforeEach {
                database.open()
            }
            
            context("when the statement suceeds") {
                
                beforeEach {
                    result = database.execute("CREATE TABLE people (personId INTEGER PRIMARY KEY)",
                                              error:&error)
                }
                
                it("returns true") {
                    expect(result).to(beTruthy())
                    expect(error).to(beNil())
                }
                
            }
            
            context("when the statement fails") {
                
                beforeEach {
                    result = database.execute("CREATE INDEX invalid_index ON not_a_table (id)",
                                              error:&error)
                }
                
                it("provides an error") {
                    expect(result).to(beFalsy())
                    expect(error).notTo(beNil())
                }
                
            }
            
            context("when the statement is invalid") {
                
                beforeEach {
                    result = database.execute("CREATE TABLE people (personId ",
                                              error:&error)
                }
                
                it("provides an error") {
                    expect(result).to(beFalsy())
                    expect(error).notTo(beNil())
                }
                
            }
            
        }
        
        describe("query(sqlString:error:)") {
            
            var resultSet : ResultSet?
            var error : NSError?
            
            beforeEach {
                database.open()
                database.execute("CREATE TABLE people (personId INTEGER PRIMARY KEY, name TEXT, age REAL)")
                database.execute("INSERT INTO people (name, age) VALUES (\"Amelia\", 1.5),(\"Brian\", 43.375),(\"Cara\", NULL)")
            }

            context("when the query is valid") {
                
                beforeEach {
                    resultSet = database.query("SELECT personId, name, age FROM people", error:&error)
                }
                
                it("returns the results") {
                    expect(resultSet).notTo(beNil())
                    if resultSet != nil {
                        expect(resultSet!.next()).to(beTruthy())
                        expect(resultSet!.columnCount).to(equal(3))
                        expect(resultSet!.columnNames).to(equal(["personId", "name", "age"]))
                        
                        expect(resultSet!.indexOfColumnNamed("personId")).to(equal(0))
                        expect(resultSet!.indexOfColumnNamed("name")).to(equal(1))
                        expect(resultSet!.indexOfColumnNamed("age")).to(equal(2))

                        expect(resultSet!.nameOfColumnAtIndex(0)).to(equal("personId"));
                        expect(resultSet!.nameOfColumnAtIndex(1)).to(equal("name"));
                        expect(resultSet!.nameOfColumnAtIndex(2)).to(equal("age"));
                        
                        // 0: id:1, name:Amelia, age:1.5
                        expect(resultSet!.integerValueAtIndex(0)).to(equal(1))
                        expect(resultSet!.integerValue("personId")).to(equal(1))
                        expect(resultSet!.stringValueAtIndex(1)).to(equal("Amelia"))
                        expect(resultSet!.stringValue("name")).to(equal("Amelia"))
                        expect(resultSet!.realValueAtIndex(2)).to(equal(1.5))
                        expect(resultSet!.realValue("age")).to(equal(1.5))
                        
                        // 1: id:2, Brian, age:43.375
                        expect(resultSet!.next()).to(beTruthy())
                        expect(resultSet!.integerValueAtIndex(0)).to(equal(2))
                        expect(resultSet!.integerValue("personId")).to(equal(2))
                        expect(resultSet!.stringValueAtIndex(1)).to(equal("Brian"))
                        expect(resultSet!.stringValue("name")).to(equal("Brian"))
                        expect(resultSet!.realValueAtIndex(2)).to(equal(43.375))
                        expect(resultSet!.realValue("age")).to(equal(43.375))
                        
                        // 2: id:3, name:Cara, age:nil
                        expect(resultSet!.next()).to(beTruthy())
                        expect(resultSet!.integerValueAtIndex(0)).to(equal(3))
                        expect(resultSet!.integerValue("personId")).to(equal(3))
                        expect(resultSet!.stringValueAtIndex(1)).to(equal("Cara"))
                        expect(resultSet!.stringValue("name")).to(equal("Cara"))
                        expect(resultSet!.realValueAtIndex(2)).to(beNil())
                        expect(resultSet!.realValue("age")).to(beNil())
                        
                        expect(resultSet!.next()).to(beFalsy())
                    }
                }
                
            }
            
        }
        
        describe("query(sqlString:arguments:error:)") {
            
            var resultSet : ResultSet?
            var error : NSError?
            
            beforeEach {
                database.open()
                database.execute("CREATE TABLE people (personId INTEGER PRIMARY KEY, name TEXT, age REAL, is_adult INTEGER)")
                database.execute("INSERT INTO people (name, age, is_adult) VALUES (\"Amelia\", 1.5, 0),(\"Brian\", 43.375, 1),(\"Cara\", NULL, 1)")
            }
            
            context("when a string argument is provided") {
                
                beforeEach {
                    resultSet = database.query("SELECT * FROM people WHERE name IS ?",
                                               arguments: [ "Brian" ],
                                               error: &error)
                }
                
                it("executes the query with the bound parameters") {
                    expect(error).to(beNil())
                    expect(resultSet).notTo(beNil())
                    if resultSet != nil {
                        expect(resultSet!.next()).to(beTruthy())
                        expect(resultSet!.stringValue("name")).to(equal("Brian"))
                        expect(resultSet!.next()).to(beFalsy())
                    }
                }
                
            }
            
            context("when an Int argument is provided") {
                beforeEach {
                    resultSet = database.query("SELECT * FROM people WHERE personId IS ?",
                        arguments: [ Int(1) ],
                        error: &error)
                }
                
                it("executes the query with the bound parameters") {
                    expect(error).to(beNil())
                    expect(resultSet).notTo(beNil())
                    if resultSet != nil {
                        expect(resultSet!.next()).to(beTruthy())
                        expect(resultSet!.stringValue("name")).to(equal("Amelia"))
                        expect(resultSet!.next()).to(beFalsy())
                        
                    }
                }
            }

            context("when an Int64 argument is provided") {
                beforeEach {
                    resultSet = database.query("SELECT * FROM people WHERE personId IS ?",
                        arguments: [ Int64(1) ],
                        error: &error)
                }
                
                it("executes the query with the bound parameters") {
                    expect(error).to(beNil())
                    expect(resultSet).notTo(beNil())
                    if resultSet != nil {
                        expect(resultSet!.next()).to(beTruthy())
                        expect(resultSet!.stringValue("name")).to(equal("Amelia"))
                        expect(resultSet!.next()).to(beFalsy())
                        
                    }
                }
            }
            
            context("when an Int32 argument is provided") {
                beforeEach {
                    resultSet = database.query("SELECT * FROM people WHERE personId IS ?",
                        arguments: [ Int32(1) ],
                        error: &error)
                }
                
                it("executes the query with the bound parameters") {
                    expect(error).to(beNil())
                    expect(resultSet).notTo(beNil())
                    if resultSet != nil {
                        expect(resultSet!.next()).to(beTruthy())
                        expect(resultSet!.stringValue("name")).to(equal("Amelia"))
                        expect(resultSet!.next()).to(beFalsy())
                        
                    }
                }
            }
            
            context("when an Int16 argument is provided") {
                beforeEach {
                    resultSet = database.query("SELECT * FROM people WHERE personId IS ?",
                        arguments: [ Int16(1) ],
                        error: &error)
                }
                
                it("executes the query with the bound parameters") {
                    expect(error).to(beNil())
                    expect(resultSet).notTo(beNil())
                    if resultSet != nil {
                        expect(resultSet!.next()).to(beTruthy())
                        expect(resultSet!.stringValue("name")).to(equal("Amelia"))
                        expect(resultSet!.next()).to(beFalsy())
                        
                    }
                }
            }
            
            context("when an Int8 argument is provided") {
                beforeEach {
                    resultSet = database.query("SELECT * FROM people WHERE personId IS ?",
                        arguments: [ Int8(1) ],
                        error: &error)
                }
                
                it("executes the query with the bound parameters") {
                    expect(error).to(beNil())
                    expect(resultSet).notTo(beNil())
                    if resultSet != nil {
                        expect(resultSet!.next()).to(beTruthy())
                        expect(resultSet!.stringValue("name")).to(equal("Amelia"))
                        expect(resultSet!.next()).to(beFalsy())
                        
                    }
                }
            }
            
            context("when an UInt64 argument is provided") {
                beforeEach {
                    resultSet = database.query("SELECT * FROM people WHERE personId IS ?",
                        arguments: [ UInt64(1) ],
                        error: &error)
                }
                
                it("executes the query with the bound parameters") {
                    expect(error).to(beNil())
                    expect(resultSet).notTo(beNil())
                    if resultSet != nil {
                        expect(resultSet!.next()).to(beTruthy())
                        expect(resultSet!.stringValue("name")).to(equal("Amelia"))
                        expect(resultSet!.next()).to(beFalsy())
                        
                    }
                }
            }
            
            context("when an UInt32 argument is provided") {
                beforeEach {
                    resultSet = database.query("SELECT * FROM people WHERE personId IS ?",
                        arguments: [ UInt32(1) ],
                        error: &error)
                }
                
                it("executes the query with the bound parameters") {
                    expect(error).to(beNil())
                    expect(resultSet).notTo(beNil())
                    if resultSet != nil {
                        expect(resultSet!.next()).to(beTruthy())
                        expect(resultSet!.stringValue("name")).to(equal("Amelia"))
                        expect(resultSet!.next()).to(beFalsy())
                        
                    }
                }
            }
            
            context("when an UInt16 argument is provided") {
                beforeEach {
                    resultSet = database.query("SELECT * FROM people WHERE personId IS ?",
                        arguments: [ UInt16(1) ],
                        error: &error)
                }
                
                it("executes the query with the bound parameters") {
                    expect(error).to(beNil())
                    expect(resultSet).notTo(beNil())
                    if resultSet != nil {
                        expect(resultSet!.next()).to(beTruthy())
                        expect(resultSet!.stringValue("name")).to(equal("Amelia"))
                        expect(resultSet!.next()).to(beFalsy())
                        
                    }
                }
            }
            
            context("when an UInt8 argument is provided") {
                beforeEach {
                    resultSet = database.query("SELECT * FROM people WHERE personId IS ?",
                        arguments: [ UInt8(1) ],
                        error: &error)
                }
                
                it("executes the query with the bound parameters") {
                    expect(error).to(beNil())
                    expect(resultSet).notTo(beNil())
                    if resultSet != nil {
                        expect(resultSet!.next()).to(beTruthy())
                        expect(resultSet!.stringValue("name")).to(equal("Amelia"))
                        expect(resultSet!.next()).to(beFalsy())
                        
                    }
                }
            }
            
            context("when a Double argument is provided") {
                beforeEach {
                    resultSet = database.query("SELECT * FROM people WHERE age > ?",
                        arguments: [ Double(43.374) ],
                        error: &error)
                }
                
                it("executes the query with the bound parameters") {
                    expect(error).to(beNil())
                    expect(resultSet).notTo(beNil())
                    if resultSet != nil {
                        expect(resultSet!.next()).to(beTruthy())
                        expect(resultSet!.stringValue("name")).to(equal("Brian"))
                        expect(resultSet!.next()).to(beFalsy())
                        
                    }
                }
            }
            
            context("when a Float argument is provided") {
                beforeEach {
                    resultSet = database.query("SELECT * FROM people WHERE age > ?",
                        arguments: [ Float(43.374) ],
                        error: &error)
                }
                
                it("executes the query with the bound parameters") {
                    expect(error).to(beNil())
                    expect(resultSet).notTo(beNil())
                    if resultSet != nil {
                        expect(resultSet!.next()).to(beTruthy())
                        expect(resultSet!.stringValue("name")).to(equal("Brian"))
                        expect(resultSet!.next()).to(beFalsy())
                        
                    }
                }
            }
            
            context("when a Bool argument is provided") {
                beforeEach {
                    resultSet = database.query("SELECT * FROM people WHERE is_adult IS ?",
                        arguments: [ false ],
                        error: &error)
                }
                
                it("executes the query with the bound parameters") {
                    expect(error).to(beNil())
                    expect(resultSet).notTo(beNil())
                    if resultSet != nil {
                        expect(resultSet!.next()).to(beTruthy())
                        expect(resultSet!.stringValue("name")).to(equal("Amelia"))
                        expect(resultSet!.next()).to(beFalsy())
                        
                    }
                }
            }
            

            context("when a nil argument is provided") {
                beforeEach {
                    resultSet = database.query("SELECT * FROM people WHERE age IS ?",
                        arguments: [ nil ],
                        error: &error)
                }
                
                it("executes the query with the bound parameters") {
                    expect(error).to(beNil())
                    expect(resultSet).notTo(beNil())
                    if resultSet != nil {
                        expect(resultSet!.next()).to(beTruthy())
                        expect(resultSet!.stringValue("name")).to(equal("Cara"))
                        expect(resultSet!.next()).to(beFalsy())
                        
                    }
                }
            }

        }
        
    }
}
