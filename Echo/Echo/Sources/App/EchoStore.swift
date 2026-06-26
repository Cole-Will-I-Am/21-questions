import SwiftUI

@MainActor
final class EchoStore: ObservableObject {
    enum Screen: Equatable { case loading, coldOpen, classicReady, question, seal, reveal, classicOutcome }

    @Published var screen: Screen = .loading
    @Published var mode = "mirror"               // mirror | classic
    @Published var turn: Turn?
    @Published var answered = 0
    @Published var total = 21
    @Published var sealHash: String?
    @Published var portrait: Portrait?
    @Published var openedSeal: Seal?
    @Published var rating: Int?
    @Published var outcome: String?              // classic: "solved" | "stumped"
    @Published var lastGuess: String?            // classic: the guess Echo landed on
    @Published var sending = false
    @Published var starting = false
    @Published var errorText: String?

    private let api = Backend()
    private var token: String?
    private var sessionId: String?
    private var pendingGuess: String?

    func bootstrap() {
        Task {
            await ensureAccount()
            try? await Task.sleep(for: .seconds(0.9))     // let the cold-open line breathe
            if screen == .loading { withAnimation(.easeInOut(duration: 0.5)) { screen = .coldOpen } }
        }
    }

    private func ensureAccount() async {
        if token != nil { return }
        do {
            let r = try await api.registerAnon(deviceId: Keychain.deviceId(),
                                               deviceSecret: Keychain.get("echo.deviceSecret"))
            token = r.token
            if let s = r.deviceSecret { Keychain.set("echo.deviceSecret", s) }
        } catch {
            errorText = "Couldn't reach Echo — check your connection."
        }
    }

    // Mode selection from the cold open.
    func chooseMirror() { mode = "mirror"; begin() }
    func chooseClassic() { mode = "classic"; withAnimation(.easeInOut(duration: 0.4)) { screen = .classicReady } }

    func begin() {
        guard !starting else { return }
        starting = true; errorText = nil
        Task {
            await ensureAccount()
            guard let token else { starting = false; errorText = "Couldn't reach Echo."; return }
            do {
                let r = try await api.startSession(token: token, mode: mode)
                sessionId = r.sessionId
                total = r.total
                turn = r.turn
                answered = 0
                portrait = nil; openedSeal = nil; sealHash = nil; rating = nil
                outcome = nil; lastGuess = nil; pendingGuess = nil
                withAnimation(.easeInOut(duration: 0.45)) { screen = .question }
            } catch {
                errorText = "Couldn't start. Try again."
            }
            starting = false
        }
    }

    func submit(_ kind: AnswerKind) {
        guard !sending, let token, let sessionId else { return }
        let payload = kind.payload
        guard !payload.isEmpty else { return }
        if turn?.answer_type == "guess" { pendingGuess = turn?.question }   // remember Echo's guess to confirm
        sending = true; errorText = nil
        Haptics.soft()
        Task {
            do {
                let r = try await api.answer(token: token, sessionId: sessionId, answer: payload)
                answered = r.progress.answered
                total = r.progress.total
                if r.done {
                    if mode == "classic" {
                        outcome = r.outcome
                        lastGuess = pendingGuess
                        Haptics.heavy()
                        withAnimation(.easeInOut(duration: 0.5)) { screen = .classicOutcome }
                    } else {
                        portrait = r.portrait
                        openedSeal = r.seal
                        Haptics.heavy()
                        withAnimation(.easeInOut(duration: 0.6)) { screen = .reveal }
                    }
                } else if let next = r.turn {
                    turn = next
                    if let h = r.seal?.hash {              // Q3 — Echo seals its early guess
                        sealHash = h
                        Haptics.seal()
                        withAnimation(.easeInOut(duration: 0.5)) { screen = .seal }
                    }
                }
            } catch {
                errorText = "That didn't go through — try again."
            }
            sending = false
        }
    }

    func continueFromSeal() {
        withAnimation(.easeInOut(duration: 0.4)) { screen = .question }
    }

    func rate(_ n: Int) {
        rating = n
        Haptics.tap()
        guard let token, let sessionId else { return }
        Task { try? await api.rate(token: token, sessionId: sessionId, rating: n) }
    }

    func playAgain() {
        if mode == "classic" { withAnimation(.easeInOut(duration: 0.4)) { screen = .classicReady } }
        else { begin() }
    }
    func home() { withAnimation(.easeInOut(duration: 0.4)) { screen = .coldOpen } }
}
