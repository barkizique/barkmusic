# BarkMusic — macOS Music Player

Нативный музыкальный плеер для macOS на SwiftUI, воспроизводящий `.mp3` и `.m4a` из локальной папки.

## Архитектура

**MVVM** с единым `MusicPlayerViewModel`, который управляет всем состоянием: список треков, очередь воспроизведения, текущее время, режимы shuffle/repeat.

```
SwiftshitApp.swift          — @main, WindowGroup, StateObject
        │
        ▼
ContentView.swift           — NavigationSplitView (Sidebar ↔ Detail)
        │
        ├─── SidebarView.swift     — кнопка выбора папки, имя папки, список треков
        │
        └─── DetailView.swift      — переключает 4 состояния:
               ├── EmptyStateView     — папка не выбрана
               ├── LoadingStateView   — загрузка метаданных
               ├── NoTracksStateView  — папка пуста
               ├── SelectTrackStateView — треки есть, но ни один не играет
               └── PlayerView         — обложка, скруббер, кнопки

MusicPlayerViewModel.swift  — ViewModel + модель Track + AVPlayer
PlayerView.swift            — обложка, прогресс, кнопки управления
```

## Файлы

| Файл | Строк | Назначение |
|------|-------|------------|
| `SwiftshitApp.swift` | 15 | Точка входа, минимальный размер окна 800×500 |
| `MusicPlayerViewModel.swift` | 372 | ViewModel: очередь, плеер, метаданные, букмарки |
| `ContentView.swift` | 90 | `NavigationSplitView` + 4 state-вьюхи для detail |
| `SidebarView.swift` | 103 | Выбор папки, имя папки, `List` треков |
| `PlayerView.swift` | 208 | Обложка, слайдер, 5 кнопок + `TimeFormatter` |

## Ключевые технологии

### AVFoundation
- **AVPlayer** для воспроизведения
- `addPeriodicTimeObserver` (0.25 с) для обновления `currentTime`
- `AVPlayerItemDidPlayToEndTime` для автоматического перехода на следующий трек
- **Async API** (macOS 13+): `asset.load(.commonMetadata)`, `item.load(.stringValue)` — без блокировки главного потока

### Sandbox / Security-Scoped Bookmarks
- `NSOpenPanel` с `canChooseDirectories = true`
- `url.bookmarkData(options: .withSecurityScope)` — сохранение доступа между запусками
- `URL(resolvingBookmarkData:)` — восстановление на старте
- `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()` — балансировка вызовов

### Очередь и управление
- **OrderedTracks** — оригинальный список (сортировка по имени файла)
- **ShuffledTracks** — перемешанный; при включении shuffle текущий трек остаётся первым, остальные тасуются
- **RepeatMode**: `.off` → `.one` → `.all` → `.off` (цикл)
- **Previous**: если прошло > 3 с — перемотка в начало, иначе предыдущий трек
- **Next**: учитывает repeat mode

## Интерфейс

### Sidebar (левая панель, ~280 px)
1. **Кнопка «Выбрать папку»** с иконкой папки
2. **Имя выбранной папки**
3. **Список треков**: название, исполнитель, длительность
4. Текущий трек подсвечен акцентным цветом + иконка динамика

### Detail (правая панель)
1. **Обложка альбома** (260×260, скругление + тень; при отсутствии — SF Symbol `music.note`)
2. **Название трека** (title2, semibold)
3. **Исполнитель** (body, secondary)
4. **Слайдер прогресса** с метками времени
5. **Кнопки**: Shuffle, Previous, Play/Pause (Space), Next, Repeat — с иконками SF Symbols

### Состояния (плейсхолдеры)
- Папка не выбрана — `music.note` + текст
- Загрузка — `ProgressView` + текст
- Нет аудиофайлов — `exclamationmark.magnifyingglass` + текст
- Треки есть, ничего не играет — `music.note.list` + текст

## Системные требования

- **macOS 13** (Ventura) и новее — `NavigationSplitView`, `async/await`, `AVAsyncProperty`
- **Xcode 15+**
- **Swift 6** (strict concurrency)

## Установка

1. Xcode → File → New → Project → macOS → App (SwiftUI)
2. Удалить шаблонные `.swift` файлы
3. Перетащить 5 файлов из `barkmusic/` в проект
4. (Опционально) Включить App Sandbox в Signing & Capabilities
5. Build & Run (⌘R)

## Примечания

- Поддерживаются только `.mp3` и `.m4a` (рекурсивный поиск)
- Метаданные (title, artist, artwork) извлекаются из ID3 / iTunes-тегов через `AVMetadataItem`
- При отсутствии тегов: title = имя файла, artist = «Неизвестный исполнитель»
- Темы macOS (светлая/тёмная) поддерживаются через системные цвета
