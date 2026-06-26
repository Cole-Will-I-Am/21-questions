import SwiftUI

struct RevealView: View {
    @EnvironmentObject var store: EchoStore
    @State private var stage = 0
    @State private var cardImage: Image?

    var body: some View {
        ScrollView {
            if let p = store.portrait {
                VStack(alignment: .leading, spacing: Metrics.s6) {
                    header(p)
                    section("WHO YOU ARE", p.portrait.who, show: stage >= 1)
                    section("HOW YOU DECIDE", p.portrait.decide, show: stage >= 2)
                    section("WHAT YOU VALUE", p.portrait.value, show: stage >= 3)
                    section("WHAT YOU'RE NOT TELLING YOURSELF", p.portrait.blindspot, show: stage >= 4, accent: true)
                    quote(p.quotable, show: stage >= 5)
                    if store.openedSeal?.hypothesis != nil { sealReveal(show: stage >= 6) }
                    ratingRow(show: stage >= 6)
                    actions(p, show: stage >= 6)
                }
                .padding(.horizontal, Metrics.s8)
                .padding(.vertical, Metrics.s10)
            }
        }
        .onAppear { runReveal() }
    }

    private func header(_ p: Portrait) -> some View {
        VStack(alignment: .leading, spacing: Metrics.s3) {
            Text("YOUR READ").font(EType.label).tracking(5).foregroundStyle(Palette.indigo)
            Text(p.archetype).font(EType.title).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            FlowChips(p.traits)
        }
        .padding(.bottom, Metrics.s2)
    }

    private func section(_ title: String, _ body: String, show: Bool, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: Metrics.s2) {
            Text(title).font(EType.label).tracking(2).foregroundStyle(accent ? Palette.indigo : Palette.inkSoft)
            Text(body).font(EType.reveal).foregroundStyle(accent ? Palette.ink : Palette.ink.opacity(0.92))
                .lineSpacing(5).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(accent ? Metrics.s4 : 0)
        .background(accent ? Palette.bgRaised : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .opacity(show ? 1 : 0)
        .offset(y: show ? 0 : 14)
    }

    private func quote(_ q: String, show: Bool) -> some View {
        Text("“\(q)”")
            .font(EType.serif(24, .semibold)).italic()
            .foregroundStyle(Palette.indigo)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, Metrics.s2)
            .opacity(show ? 1 : 0)
    }

    private func sealReveal(show: Bool) -> some View {
        VStack(alignment: .leading, spacing: Metrics.s2) {
            Label("THE SEAL — opened", systemImage: "lock.open.fill")
                .font(EType.label).tracking(2).foregroundStyle(Palette.indigo)
            Text(store.openedSeal?.hypothesis?.prediction ?? "")
                .font(EType.body).foregroundStyle(Palette.ink).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            Text("Locked at question 3 — \(store.total - 3) questions before this reveal.")
                .font(EType.small).foregroundStyle(Palette.inkFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Metrics.s4)
        .background(Palette.bgRaised2)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.indigo.opacity(0.4), lineWidth: 1))
        .opacity(show ? 1 : 0)
    }

    private func ratingRow(show: Bool) -> some View {
        VStack(spacing: Metrics.s2) {
            Text("How close did Echo get?").font(EType.small).foregroundStyle(Palette.inkSoft)
            HStack(spacing: Metrics.s3) {
                ForEach(1...5, id: \.self) { i in
                    Button { store.rate(i) } label: {
                        Image(systemName: (store.rating ?? 0) >= i ? "circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle((store.rating ?? 0) >= i ? Palette.indigo : Palette.line)
                    }.buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Metrics.s4)
        .opacity(show ? 1 : 0)
    }

    private func actions(_ p: Portrait, show: Bool) -> some View {
        VStack(spacing: Metrics.s3) {
            if let img = cardImage {
                ShareLink(item: img, preview: SharePreview("My Echo read", image: img)) {
                    Label("Share your card", systemImage: "square.and.arrow.up")
                        .font(EType.serif(18, .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Palette.indigo)
                        .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
                }
            }
            Button { Haptics.tap(); store.playAgain() } label: {
                Text("Read me again").font(EType.body).foregroundStyle(Palette.inkSoft)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).stroke(Palette.line, lineWidth: 1))
            }
        }
        .padding(.top, Metrics.s4)
        .opacity(show ? 1 : 0)
    }

    private func runReveal() {
        Task { @MainActor in
            for s in 1...6 {
                try? await Task.sleep(for: .seconds(s == 1 ? 0.7 : 0.85))
                withAnimation(.easeOut(duration: 0.6)) { stage = s }
                Haptics.soft()
            }
            if let p = store.portrait {
                let r = ImageRenderer(content: PortraitCard(portrait: p).frame(width: 360, height: 480))
                r.scale = 3
                if let ui = r.uiImage { cardImage = Image(uiImage: ui) }
            }
        }
    }
}

// Simple wrapping chip row for the traits.
struct FlowChips: View {
    let items: [String]
    init(_ items: [String]) { self.items = items }
    var body: some View {
        HStack(spacing: Metrics.s2) {
            ForEach(items, id: \.self) { t in
                Text(t).font(EType.label).foregroundStyle(Palette.inkSoft)
                    .padding(.horizontal, Metrics.s3).padding(.vertical, 5)
                    .background(Palette.bgRaised).clipShape(Capsule())
                    .overlay(Capsule().stroke(Palette.line, lineWidth: 1))
            }
        }
    }
}

// The designed, screenshot-native share asset (§5 of the blueprint).
struct PortraitCard: View {
    let portrait: Portrait
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ECHO").font(EType.label).tracking(6).foregroundStyle(Palette.indigo)
            Spacer(minLength: 0)
            Text(portrait.archetype)
                .font(EType.serif(30, .bold)).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            FlowChips(portrait.traits)
            Text("“\(portrait.quotable)”")
                .font(EType.serif(19, .semibold)).italic().foregroundStyle(Palette.indigo)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Text("See your own read.")
                .font(EType.small).foregroundStyle(Palette.inkSoft)
        }
        .padding(26)
        .frame(width: 360, height: 480, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(hex: 0x1A1830), Color(hex: 0x0B0B10)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Palette.indigo.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
