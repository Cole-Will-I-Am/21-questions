import SwiftUI

struct QuestionView: View {
    @EnvironmentObject var store: EchoStore
    @State private var showReaction = false
    @State private var showQuestion = false
    @State private var sliderVal: Double = 50
    @State private var draft = ""
    @State private var showQuit = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: Metrics.s4) {
            header
            Spacer(minLength: Metrics.s4)
            if let turn = store.turn {
                VStack(alignment: .leading, spacing: Metrics.s4) {
                    if !turn.reaction.isEmpty {
                        Text(turn.reaction.echoMarkdown)
                            .font(EType.echo).italic()
                            .foregroundStyle(Palette.indigo)
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity(showReaction ? 1 : 0)
                            .offset(y: showReaction ? 0 : 8)
                    }
                    Text(turn.question.echoMarkdown)
                        .font(EType.question)
                        .foregroundStyle(Palette.ink)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(showQuestion ? 1 : 0)
                        .offset(y: showQuestion ? 0 : 10)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: Metrics.s4)
            if let err = store.errorText {
                Text(err).font(EType.small).foregroundStyle(Palette.indigo)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            answerArea.opacity(showQuestion ? 1 : 0)
        }
        .padding(.horizontal, Metrics.s8)
        .padding(.vertical, Metrics.s6)
        .onAppear { sequence(store.turn) }
        .onChange(of: store.turn?.n) { _, _ in sequence(store.turn) }
        .alert("Leave this game?", isPresented: $showQuit) {
            Button("Leave", role: .destructive) { store.quitGame() }
            Button("Keep playing", role: .cancel) { }
        } message: {
            Text("Your progress in this round won't be saved.")
        }
    }

    private var header: some View {
        VStack(spacing: Metrics.s3) {
            HStack(spacing: Metrics.s3) {
                Button { Haptics.tap(); showQuit = true } label: {
                    Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.inkSoft)
                }
                .accessibilityLabel("Leave game")
                Text("ECHO").font(EType.label).tracking(4).foregroundStyle(Palette.indigo)
                Spacer()
                Text("\(store.turn?.n ?? 0) / \(store.total)").font(EType.mono).foregroundStyle(Palette.inkSoft)
            }
            ProgressDots(current: store.turn?.n ?? 0, total: store.total)
        }
    }

    @ViewBuilder private var answerArea: some View {
        if store.sending {
            HStack(spacing: Metrics.s2) {
                ProgressView().tint(Palette.indigo)
                Text("Echo is considering…").font(EType.small).foregroundStyle(Palette.inkSoft)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 18)
        } else if let turn = store.turn {
            switch turn.answer_type {
            case "chips":  chips(turn.options ?? [])
            case "slider": sliderArea(turn.slider_labels ?? ["", ""])
            case "yesno":  yesNoArea
            case "guess":  guessArea
            default:       textArea
            }
        }
    }

    private func chips(_ opts: [String]) -> some View {
        VStack(spacing: Metrics.s2) {
            ForEach(opts, id: \.self) { o in
                Button { store.submit(.chip(o)) } label: {
                    Text(o.echoMarkdown).font(EType.body).foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 14).padding(.horizontal, Metrics.s4)
                        .background(Palette.bgRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Palette.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sliderArea(_ labels: [String]) -> some View {
        VStack(spacing: Metrics.s3) {
            HStack {
                Text((labels.first ?? "").echoMarkdown).font(EType.small).foregroundStyle(Palette.inkSoft)
                Spacer()
                Text((labels.count > 1 ? labels[1] : "").echoMarkdown).font(EType.small).foregroundStyle(Palette.inkSoft)
            }
            Slider(value: $sliderVal, in: 0...100).tint(Palette.indigo)
            Button { store.submit(.slider(Int(sliderVal.rounded()))) } label: { continueLabel("Continue") }
                .buttonStyle(.plain)
        }
    }

    private var textArea: some View {
        VStack(spacing: Metrics.s3) {
            TextField("Say it your way…", text: $draft, axis: .vertical)
                .font(EType.body).foregroundStyle(Palette.ink).tint(Palette.indigo)
                .lineLimit(1...5).focused($focused)
                .padding(Metrics.s4).background(Palette.bgRaised)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(focused ? Palette.indigo : Palette.line, lineWidth: 1))
            let empty = draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            Button { store.submit(.text(draft)) } label: { continueLabel("Continue") }
                .buttonStyle(.plain).disabled(empty).opacity(empty ? 0.4 : 1)
        }
    }

    // Classic mode — a yes/no question: Yes / No prominent, Sometimes / Unsure secondary.
    private var yesNoArea: some View {
        VStack(spacing: Metrics.s2) {
            HStack(spacing: Metrics.s2) { yesNoButton("Yes", filled: true); yesNoButton("No", filled: true) }
            HStack(spacing: Metrics.s2) { yesNoButton("Sometimes", filled: false); yesNoButton("Unsure", filled: false) }
        }
    }
    private func yesNoButton(_ t: String, filled: Bool) -> some View {
        Button { store.submit(.chip(t)) } label: {
            Text(t).font(filled ? EType.serif(18, .semibold) : EType.body)
                .foregroundStyle(filled ? .white : Palette.inkSoft)
                .frame(maxWidth: .infinity).padding(.vertical, filled ? 16 : 12)
                .background(filled ? Palette.indigo : Palette.bgRaised)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(filled ? .clear : Palette.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // Classic mode — Echo makes a guess: confirm or reject.
    private var guessArea: some View {
        VStack(spacing: Metrics.s2) {
            Button { store.submit(.chip("Yes")) } label: {
                Text("Yes — that's it!").font(EType.serif(18, .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Palette.indigo)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }.buttonStyle(.plain)
            Button { store.submit(.chip("No")) } label: {
                Text("Not quite").font(EType.body).foregroundStyle(Palette.inkSoft)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Palette.line, lineWidth: 1))
            }.buttonStyle(.plain)
        }
    }

    private func continueLabel(_ t: String) -> some View {
        Text(t).font(EType.serif(18, .semibold)).foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(Palette.indigo)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func sequence(_ turn: Turn?) {
        showReaction = false; showQuestion = false
        sliderVal = 50; draft = ""; focused = false
        Task { @MainActor in
            let hasReaction = !(turn?.reaction.isEmpty ?? true)
            try? await Task.sleep(for: .seconds(hasReaction ? 0.15 : 0.1))
            if hasReaction {
                withAnimation(.easeOut(duration: 0.5)) { showReaction = true }
                try? await Task.sleep(for: .seconds(0.9))
            }
            withAnimation(.easeOut(duration: 0.55)) { showQuestion = true }
        }
    }
}

struct ProgressDots: View {
    let current: Int
    let total: Int
    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...max(total, 1), id: \.self) { i in
                Circle()
                    .fill(i < current ? Palette.indigo : (i == current ? Palette.ink : Palette.line))
                    .frame(width: i == current ? 7 : 5, height: i == current ? 7 : 5)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
