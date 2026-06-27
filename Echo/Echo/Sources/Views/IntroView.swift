import SwiftUI

// First-launch onboarding: what Echo is, before the two ways to play.
struct IntroView: View {
    @EnvironmentObject var store: EchoStore
    @State private var page = 0

    private struct Page { let icon: String; let title: String; let body: String }
    private let pages: [Page] = [
        Page(icon: "sparkles",
             title: "It reads you.",
             body: "21 Questions, inverted. You don't stump Echo — over twenty-one adaptive questions, it works out who *you* are."),
        Page(icon: "lock.fill",
             title: "It commits.",
             body: "Three questions in, Echo seals a specific early guess about you and locks it. At the end it opens the seal — so you know it never moved the goalposts."),
        Page(icon: "eye",
             title: "It gets specific.",
             body: "No vague horoscopes. The final portrait aims to be specific enough that a stranger could pick you out of a line-up.\n\nOr flip it — in **Guess my word**, you think of anything and Echo guesses it. Either way: Echo reflects, it doesn't diagnose, and your answers are yours."),
    ]
    private var last: Int { pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { Haptics.tap(); store.dismissIntro() } label: {
                    Text("Skip").font(EType.small).foregroundStyle(Palette.inkFaint)
                }
            }
            .padding(.horizontal, Metrics.s6).padding(.top, Metrics.s4)

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { i, p in
                    VStack(alignment: .leading, spacing: Metrics.s4) {
                        Spacer()
                        Image(systemName: p.icon)
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(Palette.indigo)
                        Text(p.title)
                            .font(EType.serif(34, .bold)).foregroundStyle(Palette.ink)
                        Text(p.body.echoMarkdown)
                            .font(EType.body).foregroundStyle(Palette.inkSoft).lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(); Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Metrics.s8)
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: page)

            HStack(spacing: 7) {
                ForEach(0..<pages.count, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Palette.indigo : Palette.line)
                        .frame(width: i == page ? 20 : 7, height: 7)
                        .animation(.spring(response: 0.3), value: page)
                }
            }
            .padding(.bottom, Metrics.s4)

            Button {
                Haptics.tap()
                if page < last { withAnimation { page += 1 } } else { store.dismissIntro() }
            } label: {
                HStack {
                    Text(page < last ? "Next" : "Begin").font(EType.serif(20, .semibold))
                    Image(systemName: "arrow.right")
                }
                .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 18)
                .background(Palette.indigo)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
            }
            .padding(.horizontal, Metrics.s8).padding(.bottom, Metrics.s10)
        }
    }
}
