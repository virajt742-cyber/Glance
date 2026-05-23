import WidgetKit
import SwiftUI

struct GlanceEntry: TimelineEntry {
    let date: Date
    let photoUrl: String
    let senderName: String
    let timestamp: String
    let image: UIImage?
    let isPlaceholder: Bool
    let isError: Bool
}

// ─── Timeline Provider ───────────────────────────────────────────────
struct Provider: TimelineProvider {
    // Shared container suite name
    private let suiteName = "group.com.glance.app"
    
    init() {
        // Configure URLCache: 10MB memory, 50MB disk
        let cache = URLCache(memoryCapacity: 10 * 1024 * 1024,
                             diskCapacity: 50 * 1024 * 1024,
                             diskPath: "glance_widget_cache")
        URLCache.shared = cache
    }
    
    func placeholder(in context: Context) -> GlanceEntry {
        GlanceEntry(
            date: Date(),
            photoUrl: "",
            senderName: "Locket",
            timestamp: "Just now",
            image: nil,
            isPlaceholder: true,
            isError: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (GlanceEntry) -> ()) {
        let sharedDefaults = UserDefaults(suiteName: suiteName)
        let senderName = sharedDefaults?.string(forKey: "glance_sender_name") ?? "Friend"
        let photoUrl = sharedDefaults?.string(forKey: "glance_photo_url") ?? ""
        let timestamp = sharedDefaults?.string(forKey: "glance_timestamp") ?? "Recently"
        
        let entry = GlanceEntry(
            date: Date(),
            photoUrl: photoUrl,
            senderName: senderName,
            timestamp: timestamp,
            image: nil,
            isPlaceholder: photoUrl.isEmpty,
            isError: false
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let sharedDefaults = UserDefaults(suiteName: suiteName)
        let senderName = sharedDefaults?.string(forKey: "glance_sender_name") ?? "Friend"
        let photoUrl = sharedDefaults?.string(forKey: "glance_photo_url") ?? ""
        let timestamp = sharedDefaults?.string(forKey: "glance_timestamp") ?? "Recently"
        let photoId = sharedDefaults?.string(forKey: "glance_photo_id") ?? ""
        
        if photoUrl.isEmpty {
            let entry = GlanceEntry(date: Date(), photoUrl: "", senderName: senderName, timestamp: timestamp, image: nil, isPlaceholder: true, isError: false)
            completion(Timeline(entries: [entry], policy: .atEnd))
            return
        }
        
        guard let url = URL(string: photoUrl) else {
            let entry = GlanceEntry(date: Date(), photoUrl: photoUrl, senderName: senderName, timestamp: timestamp, image: nil, isPlaceholder: false, isError: true)
            completion(Timeline(entries: [entry], policy: .atEnd))
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0 // Strict 10-second timeout
        
        // Deduplication Check
        let lastSeenPhotoId = sharedDefaults?.string(forKey: "last_seen_photo_id") ?? ""
        if !photoId.isEmpty && photoId == lastSeenPhotoId {
            if let cachedResponse = URLCache.shared.cachedResponse(for: request),
               let cachedImage = UIImage(data: cachedResponse.data) {
                let entry = GlanceEntry(date: Date(), photoUrl: photoUrl, senderName: senderName, timestamp: timestamp, image: cachedImage, isPlaceholder: false, isError: false)
                completion(Timeline(entries: [entry], policy: .atEnd))
                return
            }
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            var image: UIImage? = nil
            var isError = false
            
            if let data = data, let downloadedImage = UIImage(data: data) {
                image = downloadedImage
                if !photoId.isEmpty {
                    sharedDefaults?.setValue(photoId, forKey: "last_seen_photo_id")
                }
            } else {
                // If download fails, check cache
                if let cachedResponse = URLCache.shared.cachedResponse(for: request),
                   let cachedImage = UIImage(data: cachedResponse.data) {
                    image = cachedImage
                } else {
                    isError = true
                    if let err = error {
                        print("GlanceWidgetProvider Error: Failed to download image - \(err.localizedDescription)")
                    }
                }
            }
            
            let entry = GlanceEntry(
                date: Date(),
                photoUrl: photoUrl,
                senderName: senderName,
                timestamp: timestamp,
                image: image,
                isPlaceholder: false,
                isError: isError
            )
            
            completion(Timeline(entries: [entry], policy: .atEnd))
        }
        task.resume()
    }
}

// ─── SwiftUI Widget Views ────────────────────────────────────────────
struct GlanceWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .accessoryCircular:
            LockScreenCircularView(entry: entry)
        case .accessoryRectangular:
            LockScreenRectangularView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// ─── Small Home Widget ───────────────────────────────────────────────
struct SmallWidgetView: View {
    let entry: GlanceEntry
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // Background Photo
                if entry.isPlaceholder {
                    Color(red: 0.05, green: 0.05, blue: 0.05)
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.amber)
                        Text("No photos yet")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if entry.isError {
                    // Fallback to background color on error
                    Color(red: 0.1, green: 0.1, blue: 0.1)
                    VStack(spacing: 6) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                        Text("Weak connection")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                        Text("Tap to reload")
                            .font(.system(size: 9))
                            .foregroundColor(.amber)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let image = entry.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                
                // Dark bottom gradient overlay
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                    begin: .top,
                    end: .bottom
                )
                .frame(height: 50)
                
                // Sender label & time
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.senderName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    Text(entry.timestamp)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding([.leading, .bottom], 12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            // Deep link placeholder so taps open app
            .widgetURL(URL(string: "glance://camera"))
        }
    }
}

// ─── Medium Home Widget ──────────────────────────────────────────────
struct MediumWidgetView: View {
    let entry: GlanceEntry
    
    var body: some View {
        HStack(spacing: 0) {
            // Left half: Photo
            SmallWidgetView(entry: entry)
                .frame(maxWidth: .infinity)
            
            // Right half: Caption & quick status info
            VStack(alignment: .leading, spacing: 6) {
                Text("Glance Feed")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.amber)
                
                Text(entry.senderName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Shared a photo")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
                
                Text(entry.timestamp)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(16)
            .frame(width: 150)
            .background(Color(red: 0.08, green: 0.08, blue: 0.08))
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// ─── Lock Screen Circular Widget ─────────────────────────────────────
struct LockScreenCircularView: View {
    let entry: GlanceEntry
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if entry.isPlaceholder || entry.isError {
                Image(systemName: "camera.fill")
                    .font(.system(size: 18))
            } else if let image = entry.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(Circle())
            } else {
                Image(systemName: "photo.fill")
                    .font(.system(size: 18))
            }
        }
    }
}

// ─── Lock Screen Rectangular Widget ──────────────────────────────────
struct LockScreenRectangularView: View {
    let entry: GlanceEntry
    
    var body: some View {
        HStack(spacing: 8) {
            // Mini Thumbnail
            ZStack {
                if entry.isPlaceholder || entry.isError {
                    Image(systemName: "camera")
                        .font(.system(size: 14))
                } else if let image = entry.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .cornerRadius(6)
                }
            }
            .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.senderName)
                    .font(.system(size: 12, weight: .bold))
                Text(entry.timestamp)
                    .font(.system(size: 10))
                    .opacity(0.7)
            }
        }
    }
}

// ─── Color Helper Extension ──────────────────────────────────────────
extension Color {
    static let amber = Color(red: 0.96, green: 0.65, blue: 0.14)
}

// ─── Widget Configuration ────────────────────────────────────────────
@main
struct GlanceWidget: Widget {
    let kind: String = "GlanceHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            GlanceWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Glance Widget")
        .description("Instantly see photos shared by your closest friends right on your home screen.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}
