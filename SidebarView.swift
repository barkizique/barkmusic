import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: MusicPlayerViewModel

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { viewModel.selectFolder() }) {
                Label("Выбрать папку", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()

            if !viewModel.folderName.isEmpty {
                HStack {
                    Image(systemName: "music.note.list")
                        .foregroundStyle(.secondary)
                    Text(viewModel.folderName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            Divider()

            if viewModel.isLoading {
                Spacer()
                ProgressView("Загрузка треков...")
                Spacer()
            } else if viewModel.tracks.isEmpty && !viewModel.folderName.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("В папке нет аудиофайлов")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else {
                List {
                    ForEach(viewModel.tracks) { track in
                        TrackRow(
                            track: track,
                            isPlaying: track == viewModel.currentTrack
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.playTrack(track)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Плеер")
    }
}

// MARK: - Track Row

struct TrackRow: View {
    let track: Track
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 10) {
            if isPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(Color.accentColor)
                    .font(.caption)
                    .frame(width: 16)
            } else {
                Color.clear.frame(width: 16)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.body)
                    .foregroundStyle(isPlaying ? Color.accentColor : .primary)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(track.formattedDuration)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
