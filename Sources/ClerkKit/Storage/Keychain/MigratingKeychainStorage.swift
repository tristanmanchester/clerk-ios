import Foundation

struct MigratingKeychainStorage: KeychainStorage {
  let primary: any KeychainStorage
  let fallback: any KeychainStorage
  /// Treat a fallback that can't be read as empty. On macOS the fallback is the file keychain,
  /// whose items only the exact build that wrote them can read: every app update gets a new code
  /// hash, and with keychain prompts off the read fails. Failing the whole identity load on that
  /// signs the user out and makes Clerk see a new device after each update.
  var toleratesUnreadableFallback = false

  func set(_ data: Data, forKey key: String) throws {
    try primary.set(data, forKey: key)
  }

  func data(forKey key: String) throws -> Data? {
    if let data = try primary.data(forKey: key) {
      return data
    }

    let fallbackData: Data?
    if toleratesUnreadableFallback {
      fallbackData = try? fallback.data(forKey: key)
    } else {
      fallbackData = try fallback.data(forKey: key)
    }
    guard let fallbackData else {
      return nil
    }

    do {
      try primary.set(fallbackData, forKey: key)
    } catch {
      return fallbackData
    }

    if toleratesUnreadableFallback {
      // Moved: the copy in the fallback would only go stale.
      try? fallback.deleteItem(forKey: key)
    }
    return fallbackData
  }

  func deleteItem(forKey key: String) throws {
    var deletionError: Error?

    do {
      try primary.deleteItem(forKey: key)
    } catch {
      deletionError = error
    }

    do {
      try fallback.deleteItem(forKey: key)
    } catch {
      if !toleratesUnreadableFallback {
        deletionError = deletionError ?? error
      }
    }

    if let deletionError {
      throw deletionError
    }
  }

  func hasItem(forKey key: String) throws -> Bool {
    if try primary.hasItem(forKey: key) {
      return true
    }

    if toleratesUnreadableFallback {
      return (try? fallback.hasItem(forKey: key)) ?? false
    }
    return try fallback.hasItem(forKey: key)
  }
}
