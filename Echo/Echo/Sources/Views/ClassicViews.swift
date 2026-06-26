import SwiftUI

// Classic mode intro — the player secretly picks something before Echo starts guessing.
struct ClassicReadyView: View {
    @EnvironmentObject var store: EchoStore
    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.s6) {
            Button { store.home() } label: {
                Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.inkSoft)
            }
            Spacer()
            Text("GUESS MY WORD").font(EType.label).tracking(4).foregroundStyle(Palette.indigo)
            Text("Think of anything.").font(EType.serif(32, .semibold)).foregroundStyle(Palette.ink)
            Text("An object, an animal, a place, a person, a food, an idea — whatever you like. Hold it in your head, and don't tell me.\n\nI'll ask up to 21 yes-or-no questions and try to guess it.")
                .font(EType.body).foregroundStyle(Palette.inkSoft).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            if let err = store.errorText { Text(err).font(EType.small).foregroundStyle(Palette.indigo) }
            Spacer()
            Button { Haptics.tap(); store.begin() } label: {
                HStack {
                    Text(store.starting ? "Starting…" : "Got it — start guessing").font(EType.serif(20, .semibold))
                    if !store.starting { Image(systemName: "arrow.right") }
                }
                .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 18)
                .background(Palette.indigo).clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
            }
            .disabled(store.starting)
        }
        .padding(.horizontal, Metrics.s8).padding(.vertical, Metrics.s10)
    }
}

// Classic mode result — Echo got it, or got stumped.
struct ClassicOutcomeView: View {
    @EnvironmentObject var store: EchoStore
    private var solved: Bool { store.outcome == "solved" }

    var body: some View {
        VStack(spacing: Metrics.s4) {
            Spacer()
            Text(solved ? "🎯" : "🙅").font(.system(size: 60))
            Text(solved ? "Got it." : "You beat me.").font(EType.title).foregroundStyle(Palette.ink)

            if solved {
                Text("I guessed it in \(store.answered) question\(store.answered == 1 ? "" : "s").")
                    .font(EType.body).foregroundStyle(Palette.inkSoft)
                if let g = store.lastGuess {
                    Text(g.echoMarkdown)
                        .font(EType.serif(22, .semibold)).foregroundStyle(Palette.indigo)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Metrics.s2)
                }
            } else {
                Text("Twenty-one questions and I couldn't crack it. Whatever you were thinking of — well played.")
                    .font(EType.body).foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            VStack(spacing: Metrics.s3) {
                Button { Haptics.tap(); store.playAgain() } label: {
                    Text("Play again").font(EType.serif(20, .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(Palette.indigo).clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
                }
                Button { Haptics.tap(); store.home() } label: {
                    Text("Back to start").font(EType.body).foregroundStyle(Palette.inkSoft)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).stroke(Palette.line, lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, Metrics.s8).padding(.vertical, Metrics.s10)
        .multilineTextAlignment(.center)
    }
}
