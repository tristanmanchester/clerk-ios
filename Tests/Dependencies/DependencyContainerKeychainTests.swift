//
//  DependencyContainerKeychainTests.swift
//  Clerk
//

@testable import ClerkKit
import Foundation
import Testing

struct DependencyContainerKeychainTests {
  @Test
  @MainActor
  func keychainStorageWithoutAccessGroupUsesSystemKeychain() throws {
    let container = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(service: "service")
      ),
      runtimeScope: ClerkRuntimeScope()
    )

    #expect(container.keychain is SystemKeychain)
  }

  @Test
  @MainActor
  func cacheWritesStayOnTheCallingThreadOnlyOnMacOS() throws {
    let container = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: .init(keychainConfig: .init(service: "service")),
      runtimeScope: ClerkRuntimeScope()
    )

    #if os(macOS)
    #expect(container.cacheWrites.writesOnCallingThread)
    #else
    #expect(!container.cacheWrites.writesOnCallingThread)
    #endif
  }

  @Test
  @MainActor
  func identityIsStoredInTheConfiguredKeychain() throws {
    let container = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: .init(keychainConfig: .init(service: "service")),
      runtimeScope: ClerkRuntimeScope()
    )

    #expect(container.identityStore.keychain is SystemKeychain)
    #expect(!container.identityIsInAccessGroup)
  }

  @Test
  @MainActor
  func anAccessGroupSharesTheIdentityAndKeepsPrivateStatePerApp() throws {
    let container = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: .init(keychainConfig: .init(service: "service", accessGroup: "group.example")),
      runtimeScope: ClerkRuntimeScope(),
      ownerIdentifierProvider: { "com.example.app" }
    )

    #expect(container.identityIsInAccessGroup)
    let privateStorage = try #require(container.appLocalKeychain as? MigratingKeychainStorage)
    let primary = try #require(privateStorage.primary as? SystemKeychain)
    #expect(primary.service == "com.example.app.clerk.app")
    #if os(macOS)
    // macOS keeps private state in the data-protection keychain under the group, so every build
    // of the app can read it, and reads whatever the file keychain still holds once.
    #expect(primary.accessGroup == "group.example")
    #expect(privateStorage.toleratesUnreadableFallback)
    let legacy = try #require(privateStorage.fallback as? MigratingKeychainStorage)
    #expect((legacy.primary as? SystemKeychain)?.service == "com.example.app.clerk.app")
    #expect((legacy.primary as? SystemKeychain)?.accessGroup == nil)
    #expect((legacy.fallback as? SystemKeychain)?.service == "service")
    #else
    #expect(primary.accessGroup == nil)
    let fallback = try #require(privateStorage.fallback as? SystemKeychain)
    #expect(fallback.service == "service")
    #expect(fallback.accessGroup == nil)
    #endif
  }

  @Test
  func anUnreadableFallbackReadsAsEmptyInsteadOfFailingTheLoad() throws {
    struct Unreadable: KeychainStorage {
      func set(_ data: Data, forKey key: String) throws { throw KeychainError.unexpectedStatus(-25308) }
      func data(forKey key: String) throws -> Data? { throw KeychainError.unexpectedStatus(-25308) }
      func deleteItem(forKey key: String) throws { throw KeychainError.unexpectedStatus(-25308) }
      func hasItem(forKey key: String) throws -> Bool { throw KeychainError.unexpectedStatus(-25308) }
    }
    let primary = InMemoryKeychain()
    let storage = MigratingKeychainStorage(primary: primary, fallback: Unreadable(), toleratesUnreadableFallback: true)

    #expect(try storage.data(forKey: "cachedClient") == nil)
    #expect(try storage.hasItem(forKey: "cachedClient") == false)
    try storage.deleteItem(forKey: "cachedClient")

    try storage.set(Data("client".utf8), forKey: "cachedClient")
    #expect(try storage.data(forKey: "cachedClient") == Data("client".utf8))
    #expect(throws: KeychainError.self) {
      try MigratingKeychainStorage(primary: InMemoryKeychain(), fallback: Unreadable()).data(forKey: "cachedClient")
    }
  }

  @Test
  @MainActor
  func injectedKeychainHoldsEveryStore() throws {
    let keychain = InMemoryKeychain()
    let container = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: .init(),
      runtimeScope: ClerkRuntimeScope(),
      probesAccessGroupOverride: false,
      keychainStorageOverride: keychain
    )

    #expect((container.keychain as? InMemoryKeychain) === keychain)
    #expect((container.appLocalKeychain as? InMemoryKeychain) === keychain)
    #expect((container.identityStore.keychain as? InMemoryKeychain) === keychain)
  }
}
