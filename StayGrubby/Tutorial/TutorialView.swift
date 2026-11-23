import SwiftUI

/// The first-time tutorial walkthrough: four pages with Skip, Back, Next and Get Started. `finish` runs on
/// Skip and Get Started alike; the host decides what that records (first run) or does nothing (replay).
struct TutorialView: View {
    var replay = false
    let finish: () -> Void
    @State private var page: TutorialPage = .dishAndCooks
    @Environment(\.sgReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $page) {
                ForEach(TutorialPage.allCases) { item in
                    ScrollView {
                        VStack(spacing: SGTheme.Space.large) {
                            TutorialIllustration(page: item, animated: item == page)
                            VStack(spacing: SGTheme.Space.small) {
                                Text(item.eyebrow.uppercased()).font(SGTheme.TypeRole.eyebrow).foregroundStyle(SGTheme.ColorToken.accent)
                                Text(item.title).font(SGTheme.TypeRole.page).multilineTextAlignment(.center)
                                    .accessibilityAddTraits(.isHeader)
                                Text(item.message).font(SGTheme.TypeRole.reading).foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("tutorial-page-\(item.rawValue)")
                        }
                        .frame(maxWidth: SGTheme.Size.sharingContentMaximum)
                        .padding(.horizontal, SGTheme.Space.readingMargin).padding(.vertical, SGTheme.Space.medium)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .tag(item)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(reduceMotion ? nil : SGTheme.Motion.standard, value: page)
            controls
        }
        .background(SGTheme.ColorToken.background.ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            Image("StayGrubbyWordmark").resizable().scaledToFit().frame(width: 72, height: 40).accessibilityLabel("#stayGRUBBY")
            Spacer()
            if !page.isLast {
                Button(replay ? "Close" : "Skip", action: finish)
                    .font(SGTheme.TypeRole.headline).foregroundStyle(.secondary)
                    .frame(minWidth: SGTheme.Size.minimumTap, minHeight: SGTheme.Size.minimumTap)
                    .accessibilityIdentifier("tutorial-skip")
            }
        }
        .frame(minHeight: SGTheme.Size.minimumTap)
        .padding(.horizontal, SGTheme.Space.medium).padding(.top, SGTheme.Space.xSmall)
    }

    private var controls: some View {
        VStack(spacing: SGTheme.Space.medium) {
            HStack(spacing: SGTheme.Space.xSmall) {
                ForEach(TutorialPage.allCases) { item in
                    Capsule().fill(item == page ? SGTheme.Brand.red : SGTheme.ColorToken.separator)
                        .frame(width: item == page ? 22 : 8, height: 8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Page \(page.rawValue + 1) of \(TutorialPage.allCases.count)")
            .accessibilityIdentifier("tutorial-progress")

            let stacked = typeSize.isAccessibilitySize
            let layout = stacked ? AnyLayout(VStackLayout(spacing: SGTheme.Space.small)) : AnyLayout(HStackLayout(spacing: SGTheme.Space.small))
            layout {
                if page.rawValue > 0 {
                    Button { move(-1) } label: { Text("Back").frame(maxWidth: .infinity) }.buttonStyle(SGButtonStyle()).accessibilityIdentifier("tutorial-back")
                }
                if page.isLast {
                    Button(action: finish) { Text(replay ? "Done" : "Get Started").frame(maxWidth: .infinity) }
                        .buttonStyle(SGButtonStyle(prominent: true)).accessibilityIdentifier("tutorial-get-started")
                } else {
                    Button { move(1) } label: { Text("Next").frame(maxWidth: .infinity) }.buttonStyle(SGButtonStyle(prominent: true)).accessibilityIdentifier("tutorial-next")
                }
            }
        }
        .padding(.horizontal, SGTheme.Space.medium).padding(.bottom, SGTheme.Space.medium).padding(.top, SGTheme.Space.small)
    }

    private func move(_ delta: Int) {
        guard let next = TutorialPage(rawValue: page.rawValue + delta) else { return }
        if reduceMotion { page = next } else { withAnimation(SGTheme.Motion.standard) { page = next } }
    }
}
