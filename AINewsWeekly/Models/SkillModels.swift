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
    static let curated: [Skill] = [gstack, superpowers, cursorRules, aider, continuedev, windsurf]

    static let gstack = Skill(
        id: "gstack",
        name: "GStack",
        tagline: "40+ workflow skills for Claude Code",
        description: "GStack supercharges your Claude Code workflow with battle-tested skills: /ship, /review, /investigate, /qa, /plan-eng-review, and 40 more. One install transforms Claude Code from a coding assistant into a full engineering workflow partner. Built by Garry — YC-style product thinking baked into every command.",
        installCommand: "cd ~/.claude/skills && git clone https://github.com/garrytan/gstack.git gstack && cd gstack && ./setup",
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
        githubURL: URL(string: "https://github.com/garrytan/gstack"),
        docsURL: URL(string: "https://garryslist.org")
    )

    static let superpowers = Skill(
        id: "superpowers",
        name: "Superpowers",
        tagline: "Engineering discipline for Claude Code",
        description: "Superpowers installs workflow discipline into every Claude Code session. TDD-first development, systematic debugging, structured code review, and verification before claiming done. Makes Claude Code operate like a senior engineer — no shortcuts, no blind implementations.",
        installCommand: "claude /plugin install superpowers@claude-plugins-official",
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
        githubURL: URL(string: "https://github.com/obra/superpowers"),
        docsURL: nil
    )

    static let cursorRules = Skill(
        id: "cursor-rules",
        name: "Cursor Rules",
        tagline: "Curated .cursorrules for every stack",
        description: "A community-maintained library of .cursorrules files that configure Cursor's AI behavior for specific stacks — Next.js, Swift, Python, Go, and more. Drop the right rules file into your project root and Cursor immediately understands your conventions, naming patterns, and architecture.",
        installCommand: "curl -sSL https://raw.githubusercontent.com/PatrickJS/awesome-cursorrules/main/rules/nextjs-cursor-rules/.cursorrules > .cursorrules",
        features: [
            "Next.js, React, TypeScript rules",
            "Swift, SwiftUI, iOS rules",
            "Python, FastAPI, Django rules",
            "Go, Rust, systems programming rules",
            "Database and SQL rules",
            "Testing and TDD rules"
        ],
        category: .coding,
        githubURL: URL(string: "https://github.com/PatrickJS/awesome-cursorrules"),
        docsURL: nil
    )

    static let aider = Skill(
        id: "aider",
        name: "Aider",
        tagline: "AI pair programming in your terminal",
        description: "Aider lets you pair program with Claude or GPT directly from your terminal. It understands your whole codebase via git, edits multiple files at once, and auto-commits changes with descriptive messages. The best terminal-native alternative to Cursor for developers who live in the command line.",
        installCommand: "pip install aider-chat && aider --model claude-sonnet-4-6",
        features: [
            "Multi-file edits in one prompt",
            "Auto git commits with AI-written messages",
            "Whole repo context via git history",
            "Works with Claude, GPT, Gemini, local models",
            "Voice coding support",
            "/add, /drop, /run slash commands"
        ],
        category: .coding,
        githubURL: URL(string: "https://github.com/Aider-AI/aider"),
        docsURL: URL(string: "https://aider.chat")
    )

    static let continuedev = Skill(
        id: "continue-dev",
        name: "Continue",
        tagline: "Open-source AI coding assistant for VS Code",
        description: "Continue is the open-source alternative to GitHub Copilot. Install it in VS Code or JetBrains, connect any model (Claude, GPT, local Ollama), and get inline completions, chat, and edit mode — all free and self-hosted. Full control over which model and which data leaves your machine.",
        installCommand: "code --install-extension Continue.continue",
        features: [
            "Inline autocomplete — Tab to accept",
            "Chat panel with full codebase context",
            "Edit mode — describe changes, accept diffs",
            "Connect Claude, GPT, Gemini, or local models",
            "Custom slash commands and context providers",
            "100% open source — no vendor lock-in"
        ],
        category: .coding,
        githubURL: URL(string: "https://github.com/continuedev/continue"),
        docsURL: URL(string: "https://docs.continue.dev")
    )

    static let windsurf = Skill(
        id: "windsurf",
        name: "Windsurf",
        tagline: "Codeium's agentic AI IDE",
        description: "Windsurf is Codeium's AI-native IDE — a Cursor competitor with its own 'Cascade' agentic system. Cascade maintains awareness of your entire codebase, runs multi-step tasks autonomously, and can browse the web for docs while coding. Free tier is generous: unlimited Cascade base actions.",
        installCommand: "# Download from codeium.com/windsurf",
        features: [
            "Cascade — multi-step agentic coding",
            "Full codebase awareness without manual context",
            "Web search for docs while coding",
            "Inline completions + chat + terminal integration",
            "Free tier with unlimited base Cascade actions",
            "VS Code extension ecosystem compatible"
        ],
        category: .workflow,
        githubURL: nil,
        docsURL: URL(string: "https://codeium.com/windsurf")
    )
}

// MARK: - Saved skills store

@Observable
final class SavedSkillsStore {
    private let key = "savedSkillIds"
    private(set) var savedIds: Set<String>

    init() {
        let stored = UserDefaults.standard.stringArray(forKey: "savedSkillIds") ?? []
        self.savedIds = Set(stored)
    }

    func toggle(_ skill: Skill) {
        if savedIds.contains(skill.id) {
            savedIds.remove(skill.id)
        } else {
            savedIds.insert(skill.id)
        }
        UserDefaults.standard.set(Array(savedIds), forKey: key)
    }

    func isSaved(_ skill: Skill) -> Bool {
        savedIds.contains(skill.id)
    }
}
