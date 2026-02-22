import SwiftUI
import AVKit
import AVFoundation

struct DemoVideoScreen: View {
    @State private var player: AVQueuePlayer?
    @State private var playerLooper: AVPlayerLooper?
    private let videoAspectRatio: CGFloat = 1648.0 / 1072.0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            playerBody
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            configurePlayerIfNeeded()
        }
        .onDisappear {
            teardownPlayer()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: OnboardingStrings.demoTitle)
                .font(.system(size: 22, weight: .bold))
        }
    }

    @ViewBuilder
    private var playerBody: some View {
        if let player {
            AspectFitPlayerView(player: player)
                .aspectRatio(videoAspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .onAppear { player.play() }
        } else {
            ContentUnavailableView(
                "Demo unavailable",
                systemImage: "play.rectangle",
                description: Text("NozzleDemo.mp4 is missing from the app bundle.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func configurePlayerIfNeeded() {
        guard player == nil else { return }
        guard let url = Bundle.main.url(forResource: "NozzleDemo", withExtension: "mp4") else { return }

        let queuePlayer = AVQueuePlayer()
        let playerItem = AVPlayerItem(url: url)
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
        queuePlayer.play()

        player = queuePlayer
        playerLooper = looper
    }

    private func teardownPlayer() {
        player?.pause()
        player?.removeAllItems()
        player = nil
        playerLooper = nil
    }
}

private struct AspectFitPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .none
        view.videoGravity = .resizeAspect
        view.showsFullScreenToggleButton = false
        view.allowsPictureInPicturePlayback = false
        view.player = player
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }
}

#Preview {
    DemoVideoScreen()
        .frame(width: 800, height: 600)
}
