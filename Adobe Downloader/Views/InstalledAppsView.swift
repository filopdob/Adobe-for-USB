import SwiftUI

struct InstalledAppInfo: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let bundleId: String
    let version: String
    let path: URL
    let productId: String?
    let latestVersion: String?
    let updateAvailable: Bool
}

@MainActor
final class InstalledAppsViewModel: ObservableObject {
    @Published var installedApps: [InstalledAppInfo] = []
    @Published var isScanning = false
    @Published var errorMessage: String?
    
    func refresh(directoryPath: String) {
        guard !directoryPath.isEmpty else {
            installedApps = []
            errorMessage = String(localized: "请先设置下载/安装目录")
            return
        }
        
        isScanning = true
        errorMessage = nil
        
        Task {
            let apps = await scanInstalledApps(in: URL(fileURLWithPath: directoryPath))
            installedApps = apps
            isScanning = false
        }
    }
    
    func updateApp(_ app: InstalledAppInfo) async {
        guard let productId = app.productId,
              let latestVersion = app.latestVersion else { return }
        
        let hasActiveTask = globalNetworkManager.downloadTasks.contains { task in
            task.productId == productId && task.status.isActive
        }
        if hasActiveTask { return }
        
        do {
            try await globalNetworkManager.startUpdateDownload(productId: productId, version: latestVersion)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func scanInstalledApps(in directory: URL) async -> [InstalledAppInfo] {
        var results: [InstalledAppInfo] = []
        let fileManager = FileManager.default
        
        let baseDepth = directory.pathComponents.count
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .nameKey]
        
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }
        
        while let fileURL = enumerator.nextObject() as? URL {
            let depth = fileURL.pathComponents.count - baseDepth
            if depth > 3 {
                enumerator.skipDescendants()
                continue
            }
            
            guard fileURL.pathExtension == "app" else { continue }
            
            guard let bundle = Bundle(url: fileURL),
                  let info = bundle.infoDictionary else { continue }
            
            let name = (info["CFBundleDisplayName"] as? String)
                ?? (info["CFBundleName"] as? String)
                ?? fileURL.deletingPathExtension().lastPathComponent
            let bundleId = bundle.bundleIdentifier ?? fileURL.lastPathComponent
            let version = (info["CFBundleShortVersionString"] as? String)
                ?? (info["CFBundleVersion"] as? String)
                ?? "unknown"
            
            let productMatch = findLatestProductMatch(displayName: name)
            let latestVersion = productMatch?.version
            let productId = productMatch?.id
            
            let updateAvailable: Bool
            if let latest = latestVersion {
                updateAvailable = compareVersion(version, latest) == .orderedAscending
            } else {
                updateAvailable = false
            }
            
            let appInfo = InstalledAppInfo(
                name: name,
                bundleId: bundleId,
                version: version,
                path: fileURL,
                productId: productId,
                latestVersion: latestVersion,
                updateAvailable: updateAvailable
            )
            results.append(appInfo)
        }
        
        return results.sorted { $0.name < $1.name }
    }
    
    private func findLatestProductMatch(displayName: String) -> (id: String, version: String)? {
        let matches = globalProducts.filter {
            $0.displayName.caseInsensitiveCompare(displayName) == .orderedSame
        }
        guard !matches.isEmpty else { return nil }
        
        let latest = matches.max { compareVersion($0.version, $1.version) == .orderedAscending }
        if let latest = latest {
            return (latest.id, latest.version)
        }
        return nil
    }
    
    private func compareVersion(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let lhsParts = lhs.split { !$0.isNumber && $0 != "." }.joined().split(separator: ".")
        let rhsParts = rhs.split { !$0.isNumber && $0 != "." }.joined().split(separator: ".")
        let maxCount = max(lhsParts.count, rhsParts.count)
        
        for i in 0..<maxCount {
            let left = i < lhsParts.count ? Int(lhsParts[i]) ?? 0 : 0
            let right = i < rhsParts.count ? Int(rhsParts[i]) ?? 0 : 0
            if left < right { return .orderedAscending }
            if left > right { return .orderedDescending }
        }
        return .orderedSame
    }
}

struct InstalledAppsView: View {
    @Binding var searchText: String
    @StateObject private var viewModel = InstalledAppsViewModel()
    @ObservedObject private var storage = StorageData.shared
    
    var body: some View {
        VStack(spacing: 12) {
            InstalledAppsHeader(
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
                        InstalledAppRow(
                            app: app,
                            onUpdate: { Task { await viewModel.updateApp(app) } }
                        )
                    }
                    
                    if filteredApps.isEmpty {
                        Text("未找到已安装的 Adobe 应用")
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
    
    private var filteredApps: [InstalledAppInfo] {
        if searchText.isEmpty { return viewModel.installedApps }
        return viewModel.installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "选择安装目录")
        panel.canCreateDirectories = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK {
            storage.defaultDirectory = panel.url?.path ?? ""
            storage.useDefaultDirectory = true
        }
    }
    
}

private struct InstalledAppsHeader: View {
    let directoryPath: String
    let isScanning: Bool
    let onPickDirectory: () -> Void
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("已安装")
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
            
            Text("这里会从你选择的目录中识别已安装的 Adobe 应用，并对比可用的新版本。")
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

private struct InstalledAppRow: View {
    let app: InstalledAppInfo
    let onUpdate: () -> Void
    
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
                Text("\(String(localized: "当前")): \(app.version)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                if let latest = app.latestVersion {
                    Text("\(String(localized: "最新")): \(latest)")
                        .font(.system(size: 12))
                        .foregroundColor(app.updateAvailable ? .orange : .secondary)
                }
            }
            
            Button(action: onUpdate) {
                Text(app.updateAvailable ? String(localized: "更新") : String(localized: "最新"))
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 60)
            }
            .buttonStyle(BeautifulButtonStyle(baseColor: app.updateAvailable ? .blue : .gray))
            .disabled(!app.updateAvailable)
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
}
