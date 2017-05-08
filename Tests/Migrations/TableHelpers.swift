import Nimble
import Squeal

// =================================================================================================
// MARK:- Column Matchers

func haveColumns(_ expectedColumnNames:String...) -> Predicate<Table> {
    return Predicate.fromDeprecatedClosure { actualExpression, failureMessage in
        guard let table = try actualExpression.evaluate() else {
            return false
        }
        
        failureMessage.expected = "expected \(table.name) table"
        failureMessage.actualValue = table.columnNames.description
        failureMessage.postfixMessage = "have columns <\(expectedColumnNames)>"
        return table.columnNames == expectedColumnNames
    }
}

func haveColumns(_ expectedColumnNames:String...) -> Predicate<TableInfo> {
    return Predicate.fromDeprecatedClosure { actualExpression, failureMessage in
        guard let table = try actualExpression.evaluate() else {
            return false
        }
        
        failureMessage.expected = "expected \(table.name) table"
        failureMessage.actualValue = table.columnNames.description
        failureMessage.postfixMessage = "have columns <\(expectedColumnNames)>"
        return table.columnNames == expectedColumnNames
    }
}

// =================================================================================================
// MARK:- Table Matchers

func haveTables(_ expectedTableNames:String...) -> Predicate<Database> {
    return Predicate.fromDeprecatedClosure { actualExpression, failureMessage in
        guard let db = try actualExpression.evaluate() else {
            return false
        }
        
        failureMessage.expected = "expected database"
        failureMessage.actualValue = "\(db.schema.tableNames)"
        failureMessage.postfixMessage = "have tables <\(expectedTableNames)>"
        return db.schema.tableNames == expectedTableNames
    }
}

func haveTables(_ expectedTableNames:String...) -> Predicate<Version> {
    return Predicate.fromDeprecatedClosure { actualExpression, failureMessage in
        guard let version = try actualExpression.evaluate() else {
            return false
        }
        
        failureMessage.expected = "expected schema"
        failureMessage.actualValue = "\(version.tableNames)"
        failureMessage.postfixMessage = "have tables <\(expectedTableNames)>"
        return version.tableNames == expectedTableNames
    }
}

// =================================================================================================
// MARK:- Index Matchers

func haveIndex(_ name:String) -> Predicate<Database> {
    return Predicate.fromDeprecatedClosure { actualExpression, failureMessage in
        guard let db = try actualExpression.evaluate() else {
            return false
        }
        
        let schema = db.schema
        
        failureMessage.expected = "expected database"
        failureMessage.actualValue = "\(db.schema.indexNames)"
        failureMessage.postfixMessage = "have index <\(name)>"
        
        return schema.indexNames.contains(name)
    }
}

func haveIndex(_ name:String) -> Predicate<Version> {
    return Predicate.fromDeprecatedClosure { actualExpression, failureMessage in
        guard let version = try actualExpression.evaluate() else {
            return false
        }
        
        failureMessage.expected = "expected database"
        failureMessage.actualValue = "\(version.indexNames)"
        failureMessage.postfixMessage = "have index <\(name)>"
        
        return version.indexNames.contains(name)
    }
}

func haveIndex(_ name:String, on tableName:String, columns:[String]) -> Predicate<Database> {
    return Predicate.fromDeprecatedClosure { actualExpression, failureMessage in
        guard let db = try actualExpression.evaluate() else {
            return false
        }
        let schema = db.schema

        guard schema.indexNames.contains(name) else {
            failureMessage.expected = "expected database"
            failureMessage.actualValue = "\(schema.indexNames)"
            failureMessage.postfixMessage = "have index <\(name)>"
            
            return false
        }
        
        guard let tableInfo = try db.tableInfoForTableNamed(tableName) else {
            failureMessage.expected = "expected database"
            failureMessage.actualValue = "\(schema.tableNames)"
            failureMessage.postfixMessage = "have table <\(tableName)>"
            
            return false
        }
        
        guard let indexInfo = tableInfo.indexNamed(name) else {
            failureMessage.expected = "expected \(tableName) table"
            failureMessage.actualValue = "\(tableInfo.indexNames)"
            failureMessage.postfixMessage = "have index <\(name)>"
            
            return false
        }
        
        failureMessage.expected = "expected \(name) index"
        failureMessage.actualValue = "\(indexInfo.columnNames)"
        failureMessage.postfixMessage = "have columns <\(columns)>"
        return indexInfo.columnNames == columns
    }
}
