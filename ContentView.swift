import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 400)
        } detail: {
            DetailView()
        }
    }
}

// MARK: - Detail View

struct DetailView: View {
    @EnvironmentObject var viewModel: MusicPlayerViewModel

    var body: some View {
        Group {
            if viewModel.folderName.isEmpty {
                EmptyStateView()
            } else if viewModel.isLoading {
                LoadingStateView()
            } else if viewModel.tracks.isEmpty {
                NoTracksStateView()
            } else if let track = viewModel.currentTrack {
                PlayerView(track: track)
            } else {
                SelectTrackStateView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - State Views

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("Выберите папку с музыкой")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("в боковом меню")
                .foregroundStyle(.tertiary)
        }
    }
}

struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Загрузка треков...")
                .foregroundStyle(.secondary)
        }
    }
}

struct NoTracksStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("В папке нет аудиофайлов")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}

struct SelectTrackStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Выберите трек из списка")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}
