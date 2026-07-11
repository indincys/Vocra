import Foundation

/// Whole milliseconds elapsed from `start` to now on `clock`. Shared so the app model,
/// the AI client, and the selection reader don't each carry their own copy.
public func elapsedMilliseconds(from start: ContinuousClock.Instant, clock: ContinuousClock) -> Int64 {
  let components = start.duration(to: clock.now).components
  return components.seconds * 1_000 + components.attoseconds / 1_000_000_000_000_000
}
