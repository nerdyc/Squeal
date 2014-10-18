import Quick
import Nimble
import Squeal
import SquealSpecHelpers

class DatabasePoolSpec: QuickSpec {
    override func spec() {
        
        var databasePool : DatabasePool!
        var error : NSError?
        
        beforeEach {
            var tempPath = Database.createTemporaryDirectory()
            databasePool = DatabasePool(databasePath: tempPath.stringByAppendingPathComponent("DatabasePoolSpec"))
        }
        
        afterEach {
            databasePool.drain()
            databasePool = nil
        }

        describe(".dequeueDatabase(error:)") {
            
            var database : Database!
            var otherDatabase : Database?
            
            beforeEach {
                database = databasePool.dequeueDatabase(error: &error)
            }
            
            afterEach {
                if database != nil {
                    databasePool.removeDatabase(database)
                }
                
                if otherDatabase != nil {
                    databasePool.removeDatabase(otherDatabase!)
                }
            }
            
            it("returns a database") {
                expect(database).notTo(beNil())
                expect(error).to(beNil())
                expect(databasePool.activeDatabaseCount).to(equal(1))
                expect(databasePool.inactiveDatabaseCount).to(equal(0))
            }
            
            it("returns a new database if a database isn't available") {
                otherDatabase = databasePool.dequeueDatabase(error: &error)
                expect(otherDatabase).notTo(beNil())
                expect(error).to(beNil())
                
                if otherDatabase != nil {
                    expect(otherDatabase! !== database).to(beTruthy())
                }
            }
            
            it("returns an existing database if one exists") {
                if database != nil {
                    databasePool.enqueueDatabase(database)
                    
                    otherDatabase = databasePool.dequeueDatabase(error: &error)
                    expect(otherDatabase).notTo(beNil())
                    expect(error).to(beNil())
                    
                    if otherDatabase != nil {
                        expect(otherDatabase! === database).to(beTruthy())
                    }
                }
            }
            
        }
        
        describe(".enqueueDatabase(database:)") {
            
            var database : Database?
            
            beforeEach {
                database = databasePool.dequeueDatabase(error: &error)
                expect(database).notTo(beNil())
                expect(error).to(beNil())
            }
            
            afterEach {
                database = nil
            }
            
            it("returns the database to the queue") {
                databasePool.enqueueDatabase(database!)
                
                expect(databasePool.activeDatabaseCount).to(equal(0))
                expect(databasePool.inactiveDatabaseCount).to(equal(1))
            }
            
        }
        
        describe(".removeDatabase(database:)") {
            
            var database : Database?
            
            beforeEach {
                database = databasePool.dequeueDatabase(error: &error)
                expect(database).notTo(beNil())
                expect(error).to(beNil())
            }
            
            afterEach {
                database = nil
            }
            
            it("removes the database from the pool") {
                databasePool.removeDatabase(database!)
                
                expect(databasePool.activeDatabaseCount).to(equal(0))
                expect(databasePool.inactiveDatabaseCount).to(equal(0))
            }
            
        }
        
        describe(".drain()") {
            
            var database : Database!
            var otherDatabase : Database!
            
            beforeEach {
                database = databasePool.dequeueDatabase(error: &error)
                expect(database).notTo(beNil())
                expect(error).to(beNil())
                
                otherDatabase = databasePool.dequeueDatabase(error: &error)
                expect(otherDatabase).notTo(beNil())
                expect(error).to(beNil())
                
                databasePool.enqueueDatabase(otherDatabase!)
            }
            
            afterEach {
                databasePool.removeDatabase(database)
                databasePool.removeDatabase(otherDatabase)
            }
            
            it("removes all unused databases from the pool") {
                expect(databasePool.activeDatabaseCount).to(equal(1))
                expect(databasePool.inactiveDatabaseCount).to(equal(1))
                
                databasePool.drain()
                
                expect(databasePool.activeDatabaseCount).to(equal(1))
                expect(databasePool.inactiveDatabaseCount).to(equal(0))
            }
            
        }
        
    }
}
