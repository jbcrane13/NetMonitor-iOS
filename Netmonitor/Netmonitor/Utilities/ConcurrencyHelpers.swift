import Foundation

/// A thread-safe helper actor for managing single-use continuation state.
/// Prevents multiple resumes of a CheckedContinuation in async/await patterns.
actor ResumeState {
    private(set) var hasResumed = false

    func setResumed() {
        hasResumed = true
    }

    /// Atomically checks and sets the resumed flag.
    /// Returns `true` if this call was the first to resume (safe to proceed),
    /// or `false` if already resumed (should bail out).
    func tryResume() -> Bool {
        if hasResumed { return false }
        hasResumed = true
        return true
    }
}
