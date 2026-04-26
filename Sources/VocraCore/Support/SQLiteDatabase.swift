import Foundation
import SQLite3

public final class SQLiteDatabase {
  private var handle: OpaquePointer?

  public init(path: String) throws {
    guard sqlite3_open(path, &handle) == SQLITE_OK else {
      throw SQLiteError.open(String(cString: sqlite3_errmsg(handle)))
    }
  }

  deinit {
    sqlite3_close(handle)
  }

  public func execute(_ sql: String) throws {
    guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else {
      throw SQLiteError.execute(String(cString: sqlite3_errmsg(handle)))
    }
  }

  public func prepare(_ sql: String) throws -> OpaquePointer? {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
      throw SQLiteError.prepare(String(cString: sqlite3_errmsg(handle)))
    }
    return statement
  }
}

public enum SQLiteError: Error, Equatable, Sendable {
  case open(String)
  case execute(String)
  case prepare(String)
  case step(String)
}
