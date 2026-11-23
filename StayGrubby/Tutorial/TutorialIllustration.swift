import SwiftUI

/// The illustration for one tutorial page, drawn with the app's own tokens, score component and tab
/// icons. `step` advances the short demonstration; Reduce Motion (or `animated: false`, e.g. for
/// marketing renders) shows the finished state with no movement.
struct TutorialIllustration: View {
    let page: TutorialPage
    var animated = true
    @Environment(\.sgReduceMotion) private var reduceMotion
    @State private var step = 0
    /// This or that is interactive: tapping a card picks it (no ranking is recorded anywhere).
    @State private var picked: Int?

    private var still: Bool { reduceMotion || !animated }
    private var shown: Int { still ? Self.finalStep : step }
    static let finalStep = 3

    var body: some View {
        content
            .frame(maxWidth: 340)
            .padding(SGTheme.Space.medium)
            .background(SGTheme.ColorToken.surface, in: RoundedRectangle(cornerRadius: SGTheme.Radius.hero))
            .overlay { RoundedRectangle(cornerRadius: SGTheme.Radius.hero).stroke(SGTheme.ColorToken.border) }
            .accessibilityElement(children: page == .thisOrThat ? .contain : .ignore)
            .accessibilityLabel(page.illustrationLabel)
            .accessibilityIdentifier("tutorial-illustration-\(page.rawValue)")
            .task(id: still) {
                guard !still, picked == nil else { return }
                step = 0
                // A short loop: reveal, hold on the finished state, start again.
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(step == Self.finalStep ? 2200 : 750))
                    guard !Task.isCancelled else { return }
                    withAnimation(SGTheme.Motion.standard) { step = step == Self.finalStep ? 0 : step + 1 }
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch page {
        case .dishAndCooks: dishAndCooks
        case .thisOrThat: thisOrThat
        case .grubRank: grubRank
        case .foodBibleAndPass: foodBibleAndPass
        }
    }

    // MARK: Pages

    private var dishAndCooks: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            HStack(spacing: SGTheme.Space.small) {
                Tile(symbol: "fork.knife", size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text("DISH").font(SGTheme.TypeRole.eyebrow).foregroundStyle(SGTheme.ColorToken.accent)
                    Text("Butternut Squash Risotto").font(SGTheme.TypeRole.dish).lineLimit(2)
                    Text("\(max(shown, 1)) \(max(shown, 1) == 1 ? "cook" : "cooks")").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }
            Divider()
            ForEach(Array(["Sunday Batch", "Extra Sage", "Smoky"].enumerated()), id: \.offset) { index, name in
                if index < max(shown, 1) {
                    HStack {
                        Image(systemName: "flame").foregroundStyle(SGTheme.ColorToken.accent).frame(width: 24)
                        Text(name).font(SGTheme.TypeRole.headline)
                        Spacer()
                        Text(["Oct 2", "Oct 19", "Nov 8"][index]).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                    }
                    .padding(SGTheme.Space.small)
                    .background(SGTheme.ColorToken.background, in: RoundedRectangle(cornerRadius: SGTheme.Radius.field))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    private var thisOrThat: some View {
        VStack(spacing: SGTheme.Space.small) {
            Text("Which was better?").font(SGTheme.TypeRole.headline)
            HStack(spacing: SGTheme.Space.small) {
                pick(0, "Smoky Risotto", symbol: "flame")
                Text("or").font(SGTheme.TypeRole.eyebrow).foregroundStyle(.secondary).accessibilityHidden(true)
                pick(1, "Friday Tacos", symbol: "takeoutbag.and.cup.and.straw")
            }
            HStack(spacing: SGTheme.Space.xSmall) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule().fill(index < (picked == nil ? shown : 3) ? SGTheme.Brand.red : SGTheme.ColorToken.separator).frame(height: 4)
                }
            }.padding(.top, SGTheme.Space.xSmall)
            Text(picked != nil ? "Nice pick. That’s all ranking takes." : shown >= 3 ? "Got it. One more?" : "Tap the one you liked more")
                .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary).contentTransition(.opacity)
        }
    }

    private func pick(_ index: Int, _ name: String, symbol: String) -> some View {
        let chosen = picked.map { $0 == index } ?? (index == 0 && shown >= 2)
        let faded = picked.map { $0 != index } ?? (index == 1 && shown >= 2)
        return Button {
            if reduceMotion { picked = index } else { withAnimation(SGTheme.Motion.standard) { picked = index } }
        } label: { choice(name, symbol: symbol, chosen: chosen, faded: faded) }
        .buttonStyle(.plain)
        .accessibilityLabel(name).accessibilityAddTraits(chosen ? .isSelected : [])
        .accessibilityIdentifier("tutorial-pick-\(index)")
    }

    private func choice(_ name: String, symbol: String, chosen: Bool, faded: Bool = false) -> some View {
        VStack(spacing: SGTheme.Space.xSmall) {
            Tile(symbol: symbol, size: 84)
            Text(name).font(SGTheme.TypeRole.body.weight(.semibold)).multilineTextAlignment(.center).lineLimit(2, reservesSpace: true)
        }
        .padding(SGTheme.Space.small).frame(maxWidth: .infinity)
        .background(SGTheme.ColorToken.background, in: RoundedRectangle(cornerRadius: SGTheme.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: SGTheme.Radius.card)
                .stroke(chosen ? SGTheme.Brand.red : SGTheme.ColorToken.border, lineWidth: chosen ? SGTheme.Size.selectedBorder : SGTheme.Size.border)
        }
        .overlay(alignment: .topTrailing) {
            if chosen { Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(SGTheme.Brand.red).padding(SGTheme.Space.xSmall).transition(.scale.combined(with: .opacity)) }
        }
        .scaleEffect(chosen ? 1.03 : 1).opacity(faded ? 0.55 : 1)
    }

    private var grubRank: some View {
        let rows: [(String, String)] = [("Smoky Risotto", "9.4"), ("Sunday Short Ribs", "8.8"), ("Friday Tacos", "8.1"), ("Weeknight Ramen", "6.9")]
        return VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
            HStack {
                Image("TabRankFill").renderingMode(.template).resizable().scaledToFit().frame(width: 20, height: 20)
                    .foregroundStyle(SGTheme.ColorToken.accent)
                Text("Grub Rank").font(SGTheme.TypeRole.section)
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: SGTheme.Space.small) {
                    Text("\(index + 1)").font(SGTheme.TypeRole.rank).frame(width: SGTheme.Size.rankWidth)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.0).font(SGTheme.TypeRole.headline).lineLimit(1)
                        if index < 3 && shown >= 2 {
                            Text("Signature Dish").font(SGTheme.TypeRole.eyebrow).foregroundStyle(SGTheme.ColorToken.accent).transition(.opacity)
                        }
                    }
                    Spacer()
                    SGScore(text: shown >= 1 ? row.1 : nil)
                }
                .padding(.vertical, SGTheme.Space.xSmall).padding(.horizontal, SGTheme.Space.small)
                .background(index < 3 && shown >= 2 ? SGTheme.ColorToken.selected : SGTheme.ColorToken.background,
                            in: RoundedRectangle(cornerRadius: SGTheme.Radius.field))
                .offset(y: shown == 0 ? CGFloat(12 * (index + 1)) : 0).opacity(shown == 0 && index > 1 ? 0 : 1)
            }
        }
    }

    private var foodBibleAndPass: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            HStack(spacing: SGTheme.Space.small) {
                Tile(symbol: "book.closed", size: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Text("FOOD BIBLE").font(SGTheme.TypeRole.eyebrow).foregroundStyle(SGTheme.ColorToken.accent)
                    Text("Butternut Squash Risotto").font(SGTheme.TypeRole.headline).lineLimit(1)
                    Text("Serves 4 · 45 min").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                }
            }
            .padding(SGTheme.Space.small).frame(maxWidth: .infinity, alignment: .leading)
            .background(SGTheme.ColorToken.background, in: RoundedRectangle(cornerRadius: SGTheme.Radius.card))
            if shown >= 1 {
                VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                    HStack(spacing: SGTheme.Space.xSmall) {
                        Image("TabPassFill").renderingMode(.template).resizable().scaledToFit().frame(width: 18, height: 18)
                            .foregroundStyle(SGTheme.ColorToken.accent)
                        Text("THE PASS").font(SGTheme.TypeRole.eyebrow).foregroundStyle(SGTheme.ColorToken.accent)
                        Spacer()
                        SGScore(text: "9.4", role: .pill)
                    }
                    Tile(symbol: "camera", size: nil).frame(height: 84)
                    Text("Smoky Risotto, finally nailed it.").font(SGTheme.TypeRole.body)
                    HStack(spacing: SGTheme.Space.xSmall) {
                        Text("🙌").font(.title3).scaleEffect(shown >= 3 ? 1.15 : 1)
                        Text(shown >= 2 ? "\(shown >= 3 ? 4 : 3) Hands" : "Give Hands").font(SGTheme.TypeRole.secondary.weight(.semibold))
                            .contentTransition(.numericText())
                    }
                }
                .padding(SGTheme.Space.small)
                .background(SGTheme.ColorToken.background, in: RoundedRectangle(cornerRadius: SGTheme.Radius.card))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

/// A plain photo stand-in: no stock imagery or gradients, just the surface and a quiet symbol.
private struct Tile: View {
    let symbol: String
    let size: CGFloat?
    var body: some View {
        RoundedRectangle(cornerRadius: SGTheme.Radius.field)
            .fill(SGTheme.ColorToken.elevatedSurface)
            .overlay { Image(systemName: symbol).font(.title2).foregroundStyle(SGTheme.ColorToken.placeholderMark) }
            .frame(width: size, height: size)
            .frame(maxWidth: size == nil ? .infinity : nil)
    }
}
