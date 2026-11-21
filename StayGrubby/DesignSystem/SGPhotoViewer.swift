import SwiftUI

/// One full-screen photo viewer for the whole app (November 18, 2026): pinch or double-tap to zoom, pan
/// a zoomed photo, swipe between photos that already exist, swipe down or tap X to close. It only shows
/// photos the caller can already display: local cook photos are read from this device's files, post photos
/// through `AuthorizedRemoteImage` (same permission and cache rules, so a cached photo is not downloaded
/// again), and other images the screen has already loaded. It never writes or uploads anything.
struct SGPhotoViewerItem: Identifiable {
    enum Source { case local(CookingMedia), post(path: String), image(UIImage) }
    let id: String
    let source: Source
    let label: String
    static func local(_ media: CookingMedia, label: String) -> Self { .init(id: media.id.uuidString, source: .local(media), label: label) }
    static func post(_ path: String, label: String) -> Self { .init(id: path, source: .post(path: path), label: label) }
}

struct SGPhotoViewer: View {
    let items: [SGPhotoViewerItem]
    @State var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var zoomed = false

    init(items: [SGPhotoViewerItem], start: String? = nil) {
        self.items = items
        _selection = State(initialValue: start ?? items.first?.id ?? "")
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(1 - min(abs(dragOffset) / 600, 0.6)).ignoresSafeArea()
            TabView(selection: $selection) {
                ForEach(items) { item in
                    ZoomablePhoto(item: item, zoomed: $zoomed).tag(item.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: items.count > 1 ? .automatic : .never))
            .offset(y: dragOffset)
            // Swipe down to close, only when not zoomed (a zoomed photo pans instead).
            .simultaneousGesture(DragGesture(minimumDistance: 20).onChanged { value in
                guard !zoomed, abs(value.translation.height) > abs(value.translation.width) else { return }
                dragOffset = max(0, value.translation.height)
            }.onEnded { value in
                guard !zoomed else { return }
                if value.translation.height > 140 { dismiss() } else { withAnimation(.spring(duration: 0.25)) { dragOffset = 0 } }
            })
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.headline.weight(.semibold)).foregroundStyle(.white)
                    .frame(width: SGTheme.Size.minimumTap, height: SGTheme.Size.minimumTap)
                    .background(.black.opacity(0.45), in: Circle())
            }
            .padding(SGTheme.Space.medium).accessibilityLabel("Close photo").accessibilityIdentifier("photo-viewer-close")
        }
        .statusBarHidden()
        .accessibilityIdentifier("photo-viewer")
    }
}

/// One photo with pinch, double-tap and pan. Keeps the photo's aspect ratio.
private struct ZoomablePhoto: View {
    let item: SGPhotoViewerItem
    @Binding var zoomed: Bool
    @Environment(\.cookingMediaRoot) private var mediaRoot
    @Environment(\.socialMedia) private var media
    @Environment(\.accountContentCache) private var cache
    @State private var image: UIImage?
    @State private var failed = false
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image {
                    Image(uiImage: image).resizable().scaledToFit()
                        .scaleEffect(scale).offset(offset)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .gesture(MagnifyGesture().onChanged { value in
                            scale = min(max(lastScale * value.magnification, 1), 5)
                        }.onEnded { _ in settle() })
                        .simultaneousGesture(DragGesture().onChanged { value in
                            offset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
                        }.onEnded { _ in lastOffset = offset }, including: scale > 1 ? .all : .subviews)
                        .onTapGesture(count: 2) { location in
                            withAnimation(.spring(duration: 0.3)) {
                                if scale > 1 { reset() }
                                else {
                                    scale = 2.5; lastScale = 2.5
                                    // Zoom toward the tapped point.
                                    offset = CGSize(width: (geometry.size.width / 2 - location.x) * 1.5, height: (geometry.size.height / 2 - location.y) * 1.5)
                                    lastOffset = offset
                                }
                                zoomed = scale > 1
                            }
                        }
                        .accessibilityLabel(item.label).accessibilityAddTraits(.isImage)
                        .accessibilityIdentifier("photo-viewer-image")
                } else if failed {
                    SGContentState(title: "Photo unavailable", symbol: "photo", message: "Try again when you’re online.").foregroundStyle(.white)
                } else {
                    ProgressView().tint(.white)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }
        .task(id: item.id) { await load() }
    }
    private func settle() {
        lastScale = scale
        if scale <= 1.01 { withAnimation(.spring(duration: 0.25)) { reset() } }
        zoomed = scale > 1
    }
    private func reset() { scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero; zoomed = false }
    private func load() async {
        switch item.source {
        case .image(let value): image = value
        case .local(let photo):
            // The full display file (not the thumbnail), decoded off the main thread.
            let root = mediaRoot
            let data = LocalPhotoStore.data(for: photo, thumbnail: false, rootURL: root)
            image = await Task.detached { data.flatMap(UIImage.init(data:)) }.value
            failed = image == nil
        case .post(let path):
            guard let media else { failed = true; return }
            do { image = try await AuthorizedRemoteImage.load(key: "post-image/\(path)", action: .download(path: path), cache: cache, media: media) }
            catch { failed = !Task.isCancelled }
        }
    }
}

extension View {
    /// Opens `SGPhotoViewer` on tap. `items` is evaluated when tapped; nothing opens when it is empty.
    func sgOpensPhotoViewer(_ items: @escaping () -> [SGPhotoViewerItem], start: String? = nil) -> some View {
        modifier(PhotoViewerOpener(items: items, start: start))
    }
}

private struct PhotoViewerOpener: ViewModifier {
    let items: () -> [SGPhotoViewerItem]
    let start: String?
    @State private var presented: [SGPhotoViewerItem]?
    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture { let value = items(); if !value.isEmpty { presented = value } }
            .accessibilityAction(named: "View Photo Full Screen") { let value = items(); if !value.isEmpty { presented = value } }
            .fullScreenCover(isPresented: Binding(get: { presented != nil }, set: { if !$0 { presented = nil } })) {
                if let presented { SGPhotoViewer(items: presented, start: start) }
            }
    }
}

/// The opening experience (launch & loading, November 21, 2026). The system launch screen
/// (`StayGrubby-Info.plist` → `UILaunchScreen`: `LaunchBackground` + `LaunchWordmark`) and this view draw the
/// same 160-pt wordmark at the screen's centre on the same background, so launch → session restore → library
/// opening reads as one still screen with a quiet pulse beneath the wordmark. No artificial delay: it shows
/// only while the account or library is genuinely opening, never account content, and the pulse fades in
/// after a short moment so fast launches never flash it. Reduce Motion keeps the dots still. The label is
/// for VoiceOver only.
struct SGLaunchView: View {
    let label: String
    @Environment(\.sgReduceMotion) private var reduceMotion
    @State private var appeared = Date.now
    var body: some View {
        ZStack {
            SGTheme.ColorToken.background.ignoresSafeArea()
            Image("LaunchWordmark").accessibilityHidden(true)
            LaunchPulse(start: appeared, still: reduceMotion).offset(y: 118).accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("#stayGRUBBY. \(label)")
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("launch-loading")
    }
}

/// Three brand-red dots breathing in sequence. Driven by wall-clock time, so consecutive loading screens
/// (session restore, then the library) continue the same rhythm instead of restarting.
private struct LaunchPulse: View {
    let start: Date
    let still: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: still)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let visible = min(max((timeline.date.timeIntervalSince(start) - 0.35) / 0.3, 0), 1)
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { index in
                    let wave = still ? 0.5 : (sin((now * 2 * .pi / 1.2) - Double(index) * 0.7) + 1) / 2
                    Circle().fill(SGTheme.Brand.red)
                        .frame(width: 8, height: 8)
                        .scaleEffect(0.75 + 0.35 * wave)
                        .opacity(0.35 + 0.65 * wave)
                }
            }
            .opacity(still ? 1 : visible)
        }
    }
}
