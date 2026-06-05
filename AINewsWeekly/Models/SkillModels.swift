import Foundation

struct Skill: Identifiable, Hashable {
    let id: String
    let name: String
    let tagline: String
    let description: String
    let installCommand: String
    let features: [String]
    let category: SkillCategory
    let githubURL: URL?
    let docsURL: URL?
}

enum SkillCategory: String, CaseIterable {
    case workflow = "Workflow"
    case coding = "Coding"
    case testing = "Testing"
    case all = "All"
}

// MARK: - Curated skill registry

extension Skill {
    static let curated: [Skill] = [gstack, superpowers]

    static let gstack = Skill(
        id: "gstack",
        name: "GStack",
        tagline: "40+ workflow skills for Claude Code",
        description: "GStack supercharges your Claude Code workflow with battle-tested skills: /ship, /review, /investigate, /qa, /plan-eng-review, and 40 more. One install transforms Claude Code from a coding assistant into a full engineering workflow partner. Built by Garry — YC-style product thinking baked into every command.",
        installCommand: "cd ~/.claude/skills && git clone https://github.com/garrynewman/gstack.git gstack && cd gstack && ./setup",
        features: [
            "/ship — smart PR creation with tests + diff review",
            "/review — pre-landing code review gate",
            "/investigate — systematic root-cause debugging",
            "/qa — automated QA testing loop",
            "/plan-eng-review — architecture + edge case review",
            "/office-hours — YC-style product feedback",
            "/context-save — save + restore session state",
            "/design-review — visual polish + spacing audit"
        ],
        category: .workflow,
        githubURL: URL(string: "https://github.com/garrynewman/gstack"),
        docsURL: URL(string: "https://garryslist.org")
    )

    static let superpowers = Skill(
        id: "superpowers",
        name: "Superpowers",
        tagline: "Engineering discipline for Claude Code",
        description: "Superpowers installs workflow discipline into every Claude Code session. TDD-first development, systematic debugging, structured code review, and verification before claiming done. Makes Claude Code operate like a senior engineer — no shortcuts, no blind implementations.",
        installCommand: "npx skills add superpowers",
        features: [
            "Test-Driven Development — write tests before code",
            "Systematic Debugging — root cause before fixes",
            "Requesting Code Review — structured review workflow",
            "Receiving Code Review — verify before implementing",
            "Verification Before Completion — evidence before assertions",
            "Brainstorming — explore intent before building",
            "Git Worktrees — isolated feature development",
            "Executing Plans — checkpoints through implementation"
        ],
        category: .coding,
        githubURL: URL(string: "https://github.com/superpowers-ai/superpowers"),
        docsURL: nil
    )
}
