import SwiftUI

// MARK: - Player View

struct PlayerView: View {
    @EnvironmentObject var viewModel: MusicPlayerViewModel
    let track: Track

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ArtworkView(image: track.artwork)
                .frame(width: 260, height: 260)

            VStack(spacing: 4) {
                Text(track.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            ProgressSection(duration: track.duration)
                .padding(.horizontal, 40)

            ControlsSection()

            Spacer()
        }
        .padding()
    }
}

// MARK: - Album Artwork

struct ArtworkView: View {
    let image: NSImage?

    var body: some View {
        Group {
            if let nsImage = image {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor))
                    Image(systemName: "music.note")
                        .font(.system(size: 80))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 260, height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Progress Slider

struct ProgressSection: View {
    @EnvironmentObject var viewModel: MusicPlayerViewModel
    let duration: TimeInterval

    var body: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { viewModel.currentTime },
                    set: { viewModel.seek(to: $0) }
                ),
                in: 0...max(duration.isFinite ? duration : 1, 1)
            )
            .controlSize(.small)

            HStack {
                Text(TimeFormatter.string(from: viewModel.currentTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(TimeFormatter.string(from: duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Playback Controls

struct ControlsSection: View {
    @EnvironmentObject var viewModel: MusicPlayerViewModel

    var body: some View {
        HStack(spacing: 28) {
            ShuffleButton()
            PreviousButton()
            PlayPauseButton()
            NextButton()
            RepeatButton()
        }
    }
}

struct ShuffleButton: View {
    @EnvironmentObject var viewModel: MusicPlayerViewModel

    var body: some View {
        Button(action: { viewModel.toggleShuffle() }) {
            Image(systemName: "shuffle")
                .font(.title3)
        }
        .buttonStyle(.plain)
        .foregroundStyle(viewModel.shuffleEnabled ? Color.accentColor : .secondary)
        .help("Перемешать")
    }
}

struct PreviousButton: View {
    @EnvironmentObject var viewModel: MusicPlayerViewModel

    var body: some View {
        Button(action: { viewModel.previousTrack() }) {
            Image(systemName: "backward.fill")
                .font(.title2)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .help("Предыдущий трек")
    }
}

struct PlayPauseButton: View {
    @EnvironmentObject var viewModel: MusicPlayerViewModel

    var body: some View {
        Button(action: { viewModel.togglePlayPause() }) {
            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 36))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .keyboardShortcut(.space, modifiers: [])
        .help(viewModel.isPlaying ? "Пауза" : "Воспроизвести")
    }
}

struct NextButton: View {
    @EnvironmentObject var viewModel: MusicPlayerViewModel

    var body: some View {
        Button(action: { viewModel.nextTrack() }) {
            Image(systemName: "forward.fill")
                .font(.title2)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .help("Следующий трек")
    }
}

struct RepeatButton: View {
    @EnvironmentObject var viewModel: MusicPlayerViewModel

    var body: some View {
        Button(action: { viewModel.cycleRepeatMode() }) {
            Image(systemName: repeatIcon)
                .font(.title3)
        }
        .buttonStyle(.plain)
        .foregroundStyle(viewModel.repeatMode != .off ? Color.accentColor : .secondary)
        .help(repeatHint)
    }

    private var repeatIcon: String {
        switch viewModel.repeatMode {
        case .off: return "repeat"
        case .one: return "repeat.1"
        case .all: return "repeat"
        }
    }

    private var repeatHint: String {
        switch viewModel.repeatMode {
        case .off: return "Повтор выключен"
        case .one: return "Повтор одного трека"
        case .all: return "Повтор всей очереди"
        }
    }
}

// MARK: - Time Formatter

enum TimeFormatter {
    static func string(from timeInterval: TimeInterval) -> String {
        guard timeInterval.isFinite, !timeInterval.isNaN else { return "0:00" }
        let total = Int(timeInterval)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
