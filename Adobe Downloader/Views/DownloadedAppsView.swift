import SwiftUI

struct DownloadedAppInfo: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let productId: String?
    let version: String?
    let path: URL
    let size: Int64
    let modifiedDate: Date?
    let features: [String]
}

@MainActor
final class DownloadedAppsViewModel: ObservableObject {
    @Published var downloadedApps: [DownloadedAppInfo] = []
    @Published var isScanning = false
    @Published var errorMessage: String?
    
    func refresh(directoryPath: String) {
        guard !directoryPath.isEmpty else {
            downloadedApps = []
            errorMessage = String(localized: "请先设置下载/安装目录")
            return
        }
        
        isScanning = true
        errorMessage = nil
        
        Task {
            let apps = await scanDownloadedApps(in: URL(fileURLWithPath: directoryPath))
            downloadedApps = apps
            isScanning = false
        }
    }
    
    private func scanDownloadedApps(in directory: URL) async -> [DownloadedAppInfo] {
        var results: [DownloadedAppInfo] = []
        let fileManager = FileManager.default
        
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        for entry in contents {
            let driverPath = entry.appendingPathComponent("driver.xml")
            guard fileManager.fileExists(atPath: driverPath.path) else { continue }
            
            let (productId, version) = parseDriverXML(at: driverPath)
            let name = productId.flatMap { findProduct(id: $0)?.displayName }
                ?? entry.lastPathComponent
            
            let size = folderSize(at: entry)
            let modifiedDate = (try? entry.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            let features = parseFeatures(in: entry, productId: productId)
            
            results.append(DownloadedAppInfo(
                name: name,
                productId: productId,
                version: version,
                path: entry,
                size: size,
                modifiedDate: modifiedDate,
                features: features
            ))
        }
        
        return results.sorted { $0.name < $1.name }
    }
    
    private func parseDriverXML(at url: URL) -> (String?, String?) {
        guard let data = try? Data(contentsOf: url),
              let doc = try? XMLDocument(data: data) else { return (nil, nil) }
        
        let productId = try? doc.nodes(forXPath: "//SAPCode").first?.stringValue
        let version = try? doc.nodes(forXPath: "//BuildVersion").first?.stringValue
        return (productId, version)
    }
    
    private func parseFeatures(in directory: URL, productId: String?) -> [String] {
        guard let productId = productId else { return [] }
        let jsonURL = directory.appendingPathComponent(productId).appendingPathComponent("application.json")
        guard let jsonData = try? Data(contentsOf: jsonURL),
              let appInfo = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let modules = appInfo["Modules"] as? [String: Any],
              let moduleArray = modules["Module"] as? [[String: Any]] else {
            return []
        }
        
        let names = moduleArray.compactMap { $0["DisplayName"] as? String }
        return Array(names.prefix(6))
    }
    
    private func folderSize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey])
            total += Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
        }
        return total
    }
}

struct DownloadedAppsView: View {
    @Binding var searchText: String
    @StateObject private var viewModel = DownloadedAppsViewModel()
    @ObservedObject private var storage = StorageData.shared
    
    var body: some View {
        VStack(spacing: 12) {
            DownloadedAppsHeader(
                directoryPath: storage.defaultDirectory,
                isScanning: viewModel.isScanning,
                onPickDirectory: pickDirectory,
                onRefresh: { viewModel.refresh(directoryPath: storage.defaultDirectory) }
            )
            
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach(filteredApps) { app in
                        DownloadedAppRow(app: app)
                    }
                    
                    if filteredApps.isEmpty {
                        Text("未找到已下载的 Adobe 安装包")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .padding(.top, 40)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }
        }
        .onAppear {
            viewModel.refresh(directoryPath: storage.defaultDirectory)
        }
        .onChange(of: storage.defaultDirectory) { newValue in
            viewModel.refresh(directoryPath: newValue)
        }
    }
    
    private var filteredApps: [DownloadedAppInfo] {
        if searchText.isEmpty { return viewModel.downloadedApps }
        return viewModel.downloadedApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "选择下载目录")
        panel.canCreateDirectories = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK {
            storage.defaultDirectory = panel.url?.path ?? ""
            storage.useDefaultDirectory = true
        }
    }
}

private struct DownloadedAppsHeader: View {
    let directoryPath: String
    let isScanning: Bool
    let onPickDirectory: () -> Void
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("已下载")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Button(action: onRefresh) {
                    Label(isScanning ? String(localized: "扫描中...") : String(localized: "刷新"), systemImage: "arrow.clockwise")
                }
                .buttonStyle(BeautifulButtonStyle(baseColor: Color.blue.opacity(0.8)))
                .disabled(isScanning)
            }
            
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .foregroundColor(.secondary)
                Text(formatPath(directoryPath))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button(action: onPickDirectory) {
                    Label(String(localized: "选择目录"), systemImage: "folder.badge.plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(BeautifulButtonStyle(baseColor: Color.green.opacity(0.8)))
            }
            
            Text("此列表基于你选择的下载目录，展示包体大小、时间与可选功能。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 6)
    }
    
    private func formatPath(_ path: String) -> String {
        if path.isEmpty { return String(localized: "未设置") }
        return path
    }
}

private struct DownloadedAppRow: View {
    let app: DownloadedAppInfo
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.system(size: 14, weight: .medium))
                Text(app.path.path)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if let version = app.version {
                    Text("\(String(localized: "版本")): \(version)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Text(formatSize(app.size))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                if let date = app.modifiedDate {
                    Text(formatDate(date))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            if !app.features.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("功能")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(app.features.joined(separator: ", "))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .frame(width: 180, alignment: .leading)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private func formatSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
