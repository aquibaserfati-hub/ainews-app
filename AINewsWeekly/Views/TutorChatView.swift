import SwiftUI

// TutorChatView — sheet presented from LessonDetailView's "Ask the tutor"
// button. Chat-style UI, scrollable transcript, streaming response from
// the Worker (TutorService). First message auto-populates with a template
// pulled from the current step context.
//
//   ┌───────────────────────────────────────────┐
//   │ Cancel             Tutor                  │
//   ├───────────────────────────────────────────┤
//   │  ╭─────────────────────────────────╮      │
//   │  │ I'm on step 4 of 'Setting up    │ user │
//   │  │ Claude Code'. The validation    │      │
//   │  │ says I should see... but...     │      │
//   │  ╰─────────────────────────────────╯      │
//   │      ╭─────────────────────────────╮      │
//   │ ai   │ Let's check ownership of    │      │
//   │      │ ~/.claude first. Run...     │      │
//   │      ╰─────────────────────────────╯      │
//   │                                           │
//   │  ┌──────────────────────────────┐ ┌───┐  │
//   │  │ ask the tutor...             │ │ ↑ │  │
//   │  └──────────────────────────────┘ └───┘  │
//   └───────────────────────────────────────────┘
struct TutorChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LessonProgressStore.self) private var progressStore

    let lesson: Lesson
    let currentStep: LessonStep
    let stepNumber: Int

    @State private var draftText: String = ""
    @State private var isStreaming: Bool = false
    @State private var streamingMessageId: String? = nil
    @State private var lastError: TutorError? = nil

    private let service: TutorService

    init(
        lesson: Lesson,
        currentStep: LessonStep,
        stepNumber: Int,
        service: TutorService = TutorService()
    ) {
        self.lesson = lesson
        self.currentStep = currentStep
        self.stepNumber = stepNumber
        self.service = service
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                transcriptScroll
                inputBar
            }
            .background(Color.inkCream.ignoresSafeArea())
            .navigationTitle("Tutor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.inkAmber)
                }
            }
            .onAppear { populateDraftIfEmpty() }
        }
    }

    // MARK: - Sub-views

    private var transcript: [TutorMessage] {
        progressStore.progress(for: lesson.id)?.tutorTranscript ?? []
    }

    private var transcriptScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if transcript.isEmpty {
                        emptyState
                            .padding(.top, 40)
                    }
                    ForEach(transcript) { msg in
                        TutorMessageBubble(message: msg)
                            .id(msg.id)
                    }
                    if let error = lastError {
                        ErrorBanner(error: error, onRetry: {
                            lastError = nil
                            // Resend the most recent user message.
                            if let lastUser = transcript.last(where: { $0.role == .user }) {
                                send(messageBody: lastUser.body, replayingFromError: true)
                            }
                        })
                        .id("error-banner")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .onChange(of: transcript.count) {
                if let last = transcript.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: lastError != nil) {
                if lastError != nil {
                    withAnimation { proxy.scrollTo("error-banner", anchor: .bottom) }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(Color.inkAmber)
            Text("Ask the tutor")
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(Color.inkText)
            Text("It already knows the lesson and which step you're on.")
                .font(.callout)
                .foregroundStyle(Color.inkTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if draftText.isEmpty {
                    Text("ask the tutor…")
                        .foregroundStyle(Color.inkTextTertiary)
                        .padding(.top, 11)
                        .padding(.leading, 14)
                }
                TextEditor(text: $draftText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .frame(minHeight: 40, maxHeight: 120)
            }
            .background(Color.inkCard)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.inkAmberSoft, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Button {
                let body = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !body.isEmpty else { return }
                draftText = ""
                send(messageBody: body, replayingFromError: false)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(canSend ? Color.inkAmber : Color.inkAmberSoft)
            }
            .disabled(!canSend)
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.inkCream)
    }

    private var canSend: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }

    // MARK: - First-message template (eng review fix #5 / doc lines 277-299)

    private func populateDraftIfEmpty() {
        guard transcript.isEmpty, draftText.isEmpty else { return }
        var template = "I'm on step \(stepNumber) of \(lesson.title): \"\(currentStep.title)\".\n\n[describe what you're seeing or stuck on here]"
        if let hint = currentStep.validationHint, !hint.isEmpty {
            template += "\n\nThe step says I should see \"\(hint)\" but [...]."
        }
        draftText = template
    }

    // MARK: - Send

    private func send(messageBody: String, replayingFromError: Bool) {
        // If we're not replaying, append the user message to the transcript.
        if !replayingFromError {
            let userMsg = TutorMessage(
                id: UUID().uuidString,
                role: .user,
                body: messageBody,
                timestamp: Date()
            )
            progressStore.appendTutorMessage(lessonId: lesson.id, message: userMsg)
        }

        isStreaming = true
        lastError = nil
        let assistantId = UUID().uuidString
        streamingMessageId = assistantId
        // Seed an empty assistant message we'll mutate as deltas arrive.
        let seed = TutorMessage(id: assistantId, role: .assistant, body: "", timestamp: Date())
        progressStore.appendTutorMessage(lessonId: lesson.id, message: seed)

        let payload = TutorRequestPayload(
            lesson_id: lesson.id,
            step_id: currentStep.id,
            user_message: messageBody,
            completed_step_ids: progressStore
                .progress(for: lesson.id)?
                .completedStepIds ?? []
        )

        Task { @MainActor in
            var aggregated = ""
            for await event in service.stream(payload: payload) {
                switch event {
                case .textDelta(let s):
                    aggregated += s
                    progressStore.replaceLastAssistantMessage(
                        lessonId: lesson.id,
                        body: aggregated
                    )
                case .done:
                    // Stream finished cleanly — leave the assistant body as-is.
                    break
                case .error(let err):
                    lastError = err
                    // Drop the empty seed assistant placeholder if we never
                    // received any deltas.
                    if aggregated.isEmpty {
                        progressStore.dropLastAssistantPlaceholder(lessonId: lesson.id)
                    }
                }
            }
            isStreaming = false
            streamingMessageId = nil
        }
    }
}

// MARK: - Bubble

private struct TutorMessageBubble: View {
    let message: TutorMessage

    var body: some View {
        HStack(alignment: .top) {
            if message.role == .user { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 0) {
                Text(message.body.isEmpty ? "…" : message.body)
                    .font(.body)
                    .foregroundStyle(message.role == .user ? Color.inkText : Color.inkText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(message.role == .user ? Color.inkAmberSoft : Color.inkCard)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(message.role == .user ? Color.inkAmber.opacity(0.4) : Color.inkAmberSoft, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}

// MARK: - Error banner

private struct ErrorBanner: View {
    let error: TutorError
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .foregroundStyle(Color.inkAmber)
                Text(headline)
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                    .foregroundStyle(Color.inkText)
            }
            Text(error.userFacingMessage)
                .font(.callout)
                .foregroundStyle(Color.inkTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if showRetry {
                Button("Retry", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .tint(.inkAmber)
                    .controlSize(.small)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.inkAmberSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var iconName: String {
        switch error {
        case .circuitBreaker: return "moon.zzz"
        case .rateLimit: return "hourglass"
        case .network, .timeout: return "wifi.exclamationmark"
        default: return "exclamationmark.triangle"
        }
    }

    private var headline: String {
        switch error {
        case .circuitBreaker: return "Tutor is resting"
        case .rateLimit: return "Too many questions"
        case .network: return "Connection lost"
        case .timeout: return "Tutor unreachable"
        default: return "Couldn't reach the tutor"
        }
    }

    private var showRetry: Bool {
        // Retry only makes sense for transient failures.
        switch error {
        case .network, .timeout, .anthropicUpstream:
            return true
        default:
            return false
        }
    }
}
