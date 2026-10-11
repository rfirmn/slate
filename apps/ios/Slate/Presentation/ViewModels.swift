import Foundation

@MainActor
final class AuthenticationViewModel {
    enum State { case idle, submitting, authenticated(User), failed(String) }
    private(set) var state: State = .idle
    private let repository: ProjectRepository
    init(repository: ProjectRepository) { self.repository = repository }
    static func validation(email: String, password: String, displayName: String?) -> String? {
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, parts[1].contains("."), password.count >= 12, password.count <= 128 else { return "Enter a valid email and a password of at least 12 characters." }
        if let displayName, displayName.isEmpty { return "Enter your name." }
        return nil
    }
    func authenticate(email: String, password: String, displayName: String?) async throws -> User {
        state = .submitting
        do { let user = try await repository.authenticate(email: email, password: password, displayName: displayName); state = .authenticated(user); return user }
        catch { state = .failed(error.localizedDescription); throw error }
    }
}

@MainActor
final class ProjectsViewModel {
    private(set) var projects: [Project] = []
    private(set) var drafts: [PendingDraft] = []
    private(set) var loading = false
    private let repository: ProjectRepository
    init(repository: ProjectRepository) { self.repository = repository }
    func refresh() async throws {
        guard !loading else { return }; loading = true; defer { loading = false }
        projects = try await repository.projects(); drafts = try await repository.pendingDrafts()
    }
    func filtered(query: String, scope: Int) -> [Project] {
        projects.filter { project in
            let matches = query.isEmpty || project.title.localizedCaseInsensitiveContains(query) || project.client.name.localizedCaseInsensitiveContains(query)
            let status = scope == 0 || (scope == 1 && ![.completed, .cancelled].contains(project.status)) || (scope == 2 && ["ELIGIBLE", "RELEASED"].contains(project.deliveryStatus))
            return matches && status
        }
    }
}
