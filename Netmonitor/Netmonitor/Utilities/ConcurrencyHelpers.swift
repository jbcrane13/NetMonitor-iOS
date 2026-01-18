import Foundation

/// A thread-safe helper actor for managing single-use continuation state.
/// Prevents multiple resumes of a CheckedContinuation in async/await patterns.
actor ResumeState {
    private(set) var hasResumed = false

    func setResumed() {
        hasResumed = true
    }
}
