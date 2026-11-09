/// Whether the persisted identity is known well enough to report authentication.
public enum ClerkIdentityRestoreState: Sendable, Equatable {
  /// Restore has not completed, or a persisted device token still needs a client.
  case pending
  /// The identity store could not be read. Retry when storage is available.
  case failed
  /// The store was read successfully and contains no identity.
  case empty
  /// A client was restored or accepted, including a client with no active session.
  case restored
}
