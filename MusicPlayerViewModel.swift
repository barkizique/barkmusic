import Foundation
import AVFoundation
import AppKit
import Combine

// MARK: - Track Model

struct Track: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let title: String
    let artist: String
    let artwork: NSImage?
    let duration: TimeInterval

    var formattedDuration: String {
        guard duration.isFinite, !duration.isNaN, duration > 0 else { return "--:--" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - ViewModel

final class MusicPlayerViewModel: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var currentTrack: Track?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var shuffleEnabled = false
    @Published var repeatMode: RepeatMode = .off
    @Published var folderName: String = ""
    @Published var isLoading = false

    enum RepeatMode: CaseIterable {
        case off, one, all

        var next: RepeatMode {
            switch self {
            case .off:  return .one
            case .one:  return .all
            case .all:  return .off
            }
        }
    }

    // MARK: - Private properties

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var itemEndObserver: NSObjectProtocol?

    private var orderedTracks: [Track] = []
    private var shuffledTracks: [Track] = []
    private var currentIndex: Int = 0

    private var currentFolderURL: URL?

    private var activeQueue: [Track] {
        shuffleEnabled ? shuffledTracks : orderedTracks
    }

    // MARK: - Init / Deinit

    init() {
        addTimeObserver()
        restoreFolderAccess()
    }

    deinit {
        removeTimeObserver()
        currentFolderURL?.stopAccessingSecurityScopedResource()
    }

    // MARK: - Folder selection (NSOpenPanel)

    /// Opens the standard macOS folder picker dialog.
    /// After selection, the folder is bookmarked for future sandbox access
    /// and scanned for supported audio files (.mp3, .m4a).
    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Выберите папку с музыкальными файлами"
        panel.prompt = "Выбрать папку"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        currentFolderURL?.stopAccessingSecurityScopedResource()

        _ = url.startAccessingSecurityScopedResource()
        currentFolderURL = url

        do {
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmark, forKey: "FolderBookmark")
        } catch {
            print("Failed to save bookmark: \(error)")
        }

        folderName = url.lastPathComponent
        scanAudioFiles(in: url)
    }

    private func restoreFolderAccess() {
        guard let data = UserDefaults.standard.data(forKey: "FolderBookmark") else { return }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                let newBookmark = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                UserDefaults.standard.set(newBookmark, forKey: "FolderBookmark")
            }

            _ = url.startAccessingSecurityScopedResource()
            currentFolderURL = url
            folderName = url.lastPathComponent
            scanAudioFiles(in: url)
        } catch {
            print("Failed to restore bookmark: \(error)")
        }
    }

    /// Recursively scans a directory for audio files and loads metadata in the background.
    private func scanAudioFiles(in directory: URL) {
        isLoading = true

        // Synchronous file enumeration — outside Task to avoid Swift 6 concurrency issues
        // with NSDirectoryEnumerator (which is not Sendable).
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            isLoading = false
            return
        }

        var audioURLs: [URL] = []
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if ext == "mp3" || ext == "m4a" {
                audioURLs.append(fileURL)
            }
        }
        audioURLs.sort { $0.lastPathComponent < $1.lastPathComponent }

        // --- Metadata extraction via AVAsset (async KeyPath API) ---
        Task {
            var scanned: [Track] = []
            for url in audioURLs {
                if let track = await loadTrack(from: url) {
                    scanned.append(track)
                }
            }

            await MainActor.run {
                self.orderedTracks = scanned
                self.shuffledTracks = scanned.shuffled()
                self.tracks = scanned
                self.isLoading = false

                if scanned.isEmpty {
                    self.currentTrack = nil
                    self.player.replaceCurrentItem(with: nil)
                    self.isPlaying = false
                }
            }
        }
    }

    /// Loads track metadata from a single audio URL using modern async KeyPath API.
    private func loadTrack(from url: URL) async -> Track? {
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: false])

        let title = (try? await extractString(from: asset, identifier: .commonIdentifierTitle))
            ?? url.deletingPathExtension().lastPathComponent
        let artist = (try? await extractString(from: asset, identifier: .commonIdentifierArtist))
            ?? "Неизвестный исполнитель"
        let artwork = (try? await extractImage(from: asset))
        let duration = (try? await asset.load(.duration).seconds) ?? 0

        return Track(
            url: url,
            title: title,
            artist: artist,
            artwork: artwork,
            duration: duration.isNaN ? 0 : duration
        )
    }

    /// Helper: extract a string metadata field via async KeyPath API.
    private func extractString(from asset: AVAsset, identifier: AVMetadataIdentifier) async throws -> String? {
        let metadata = try await asset.load(.commonMetadata)
        let items = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: identifier)
        return try await items.first?.load(.stringValue)
    }

    /// Helper: extract artwork image via async KeyPath API.
    private func extractImage(from asset: AVAsset) async throws -> NSImage? {
        let metadata = try await asset.load(.commonMetadata)
        let items = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierArtwork)
        guard let data = try await items.first?.load(.dataValue) else { return nil }
        return NSImage(data: data)
    }

    // MARK: - Playback controls

    func playTrack(_ track: Track) {
        if shuffleEnabled {
            var remaining = orderedTracks.filter { $0 != track }
            remaining.shuffle()
            shuffledTracks = [track] + remaining
            currentIndex = 0
        } else {
            guard let index = orderedTracks.firstIndex(of: track) else { return }
            currentIndex = index
        }

        currentTrack = track
        player.replaceCurrentItem(with: AVPlayerItem(url: track.url))
        player.play()
        isPlaying = true
        currentTime = 0
    }

    func togglePlayPause() {
        guard currentTrack != nil || !tracks.isEmpty else { return }

        if currentTrack == nil {
            playTrack(tracks[0])
            return
        }

        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    func nextTrack() {
        guard !activeQueue.isEmpty else { return }

        if repeatMode == .one {
            guard currentTrack != nil else { return }
            player.seek(to: .zero)
            player.play()
            isPlaying = true
            return
        }

        let nextIndex = currentIndex + 1
        if nextIndex < activeQueue.count {
            currentIndex = nextIndex
            playTrack(activeQueue[nextIndex])
        } else if repeatMode == .all {
            currentIndex = 0
            playTrack(activeQueue[0])
        } else {
            player.pause()
            isPlaying = false
            currentTime = 0
        }
    }

    func previousTrack() {
        guard !activeQueue.isEmpty else { return }

        if currentTime > 3 {
            player.seek(to: .zero)
            return
        }

        let prevIndex = currentIndex - 1
        if prevIndex >= 0 {
            currentIndex = prevIndex
            playTrack(activeQueue[prevIndex])
        } else if repeatMode == .all {
            currentIndex = activeQueue.count - 1
            playTrack(activeQueue.last!)
        } else {
            player.seek(to: .zero)
        }
    }

    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func toggleShuffle() {
        shuffleEnabled.toggle()

        if shuffleEnabled {
            if let current = currentTrack {
                var remaining = orderedTracks.filter { $0 != current }
                remaining.shuffle()
                shuffledTracks = [current] + remaining
                currentIndex = 0
            } else {
                shuffledTracks = orderedTracks.shuffled()
                currentIndex = 0
            }
        } else {
            if let current = currentTrack,
               let index = orderedTracks.firstIndex(of: current) {
                currentIndex = index
            }
        }
    }

    func cycleRepeatMode() {
        repeatMode = repeatMode.next
    }

    // MARK: - Time observation

    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
            [weak self] time in
            self?.currentTime = time.seconds
        }

        itemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let item = notification.object as? AVPlayerItem,
                  item == self.player.currentItem
            else { return }
            self.nextTrack()
        }
    }

    private func removeTimeObserver() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let observer = itemEndObserver {
            NotificationCenter.default.removeObserver(observer)
            itemEndObserver = nil
        }
    }
}
