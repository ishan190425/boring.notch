//
//  ClipboardManager.swift
//  boringNotch
//
//  Created on 2025-04-22.
//

import Foundation
import AppKit
import Combine

// Note: In a real project, these would be properly imported through module structure
// The IDE might show errors, but the code should compile correctly

public class ClipboardManager: ObservableObject {
    // Published properties for UI updates
    @Published var clipboardItems: [ClipboardItem] = []
    @Published var pinnedItems: [ClipboardItem] = []
    @Published var isLoading: Bool = false
    
    // Private properties
    private let fileManager = FileManager.default
    private let storageDirectory: URL
    private var clipboardChangeTimer: Timer?
    private var lastChangeCount: Int = 0
    
    // Flag to prevent duplication when copying from our own history
    private var isInternalCopy: Bool = false
    private var internalCopyResetTimer: Timer?
    
    // Memory management
    private let maxItemsInMemory: Int = 50
    private let batchSize: Int = 20
    private var hasMoreItemsToLoad: Bool = true
    private var oldestLoadedTimestamp: Date = Date()
    
    // Initialization
    public init() {
        // Setup storage directory
        let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let boringNotchDirectory = appSupportDirectory.appendingPathComponent("BoringNotch")
        storageDirectory = boringNotchDirectory.appendingPathComponent("ClipboardHistory")
        
        // Create directories if needed
        try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        
        // Load initial items
        loadInitialItems()
        
        // Start monitoring clipboard
        startMonitoring()
    }
    
    // MARK: - Clipboard Monitoring
    
    /// Start monitoring the system clipboard for changes
    public func startMonitoring() {
        // Get initial change count
        lastChangeCount = NSPasteboard.general.changeCount
        
        // Setup timer to check for clipboard changes
        clipboardChangeTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboardChanges()
        }
    }
    
    /// Stop monitoring the system clipboard
    public func stopMonitoring() {
        clipboardChangeTimer?.invalidate()
        clipboardChangeTimer = nil
    }
    
    /// Check if the clipboard has changed and handle new content
    private func checkClipboardChanges() {
        let currentChangeCount = NSPasteboard.general.changeCount
        
        // If the change count has increased, the clipboard content has changed
        if currentChangeCount > lastChangeCount {
            lastChangeCount = currentChangeCount
            
            // Skip handling if this is an internal copy operation
            if !isInternalCopy {
                handleClipboardChange()
            }
        }
    }
    
    /// Handle new clipboard content
    private func handleClipboardChange() {
        // Get content from pasteboard
        let pasteboard = NSPasteboard.general
        
        // Try to create a ClipboardItem from the pasteboard content
        if let newItem = ClipboardItem.fromPasteboard(pasteboard: pasteboard) {
            // Check if we already have this item (avoid duplicates)
            let isDuplicate = clipboardItems.contains { existingItem in
                existingItem.hasSameContent(as: newItem)
            }
            
            if !isDuplicate {
                // Add to memory
                DispatchQueue.main.async {
                    self.clipboardItems.insert(newItem, at: 0)
                    
                    // Trim memory cache if needed
                    if self.clipboardItems.count > self.maxItemsInMemory {
                        self.clipboardItems = Array(self.clipboardItems.prefix(self.maxItemsInMemory))
                    }
                }
                
                // Save to disk
                saveItem(newItem)
            }
        }
    }
    
    // MARK: - Data Management
    
    /// Load initial items from disk
    private func loadInitialItems() {
        isLoading = true
        
        // Load pinned items first
        pinnedItems = loadPinnedItems()
        
        // Load recent items
        clipboardItems = loadItems(limit: maxItemsInMemory, offset: 0)
        
        // Update oldest timestamp for pagination
        if let oldestItem = clipboardItems.last {
            oldestLoadedTimestamp = oldestItem.timestamp
        }
        
        isLoading = false
    }
    
    /// Load more items when scrolling
    public func loadMoreItems() {
        guard !isLoading && hasMoreItemsToLoad else { return }
        
        isLoading = true
        
        // Load next batch of items
        let newItems = loadItems(before: oldestLoadedTimestamp, limit: batchSize)
        
        // If we got fewer items than requested, we've reached the end
        if newItems.count < batchSize {
            hasMoreItemsToLoad = false
        }
        
        // Update oldest timestamp for next pagination
        if let oldestItem = newItems.last {
            oldestLoadedTimestamp = oldestItem.timestamp
        }
        
        // Append to existing items
        DispatchQueue.main.async {
            self.clipboardItems.append(contentsOf: newItems)
            self.isLoading = false
        }
    }
    
    // MARK: - Item Actions
    
    /// Copy an item back to the system clipboard
    public func copyToClipboard(item: ClipboardItem) {
        // Set the internal copy flag to prevent duplication
        isInternalCopy = true
        
        // Cancel any existing reset timer
        internalCopyResetTimer?.invalidate()
        
        // Set a timer to reset the flag after a short delay
        internalCopyResetTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.isInternalCopy = false
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch item.type {
        case .text:
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .image:
            if let filePath = item.imageFilePath, let image = NSImage(contentsOfFile: filePath) {
                pasteboard.writeObjects([image])
            }
        case .file:
            if let fileURL = item.fileURL {
                pasteboard.writeObjects([fileURL as NSURL])
            }
        }
    }
    
    /// Delete an item from history
    public func deleteItem(item: ClipboardItem) {
        // Remove from memory
        DispatchQueue.main.async {
            self.clipboardItems.removeAll { $0.id == item.id }
            self.pinnedItems.removeAll { $0.id == item.id }
        }
        
        // Remove from disk
        let itemFilePath = storageDirectory.appendingPathComponent("\(item.id.uuidString).json")
        try? fileManager.removeItem(at: itemFilePath)
        
        // Also remove any associated image files
        if item.type == .image, let imagePath = item.imageFilePath {
            try? fileManager.removeItem(at: URL(fileURLWithPath: imagePath))
        }
    }
    
    /// Toggle pin status for an item
    public func togglePin(item: ClipboardItem) {
        // Find the item in our collections
        if let index = clipboardItems.firstIndex(where: { $0.id == item.id }) {
            // Toggle pin status
            var updatedItem = clipboardItems[index]
            updatedItem.isPinned.toggle()
            
            // Update in memory
            DispatchQueue.main.async {
                self.clipboardItems[index] = updatedItem
                
                // Update pinned items collection
                if updatedItem.isPinned {
                    self.pinnedItems.append(updatedItem)
                } else {
                    self.pinnedItems.removeAll { $0.id == updatedItem.id }
                }
            }
            
            // Update on disk
            saveItem(updatedItem)
        }
    }
    
    /// Update search term for an item
    public func updateSearchTerm(item: ClipboardItem, newSearchTerm: String?) {
        // Find the item in our collections
        if let index = clipboardItems.firstIndex(where: { $0.id == item.id }) {
            // Update search term
            var updatedItem = clipboardItems[index]
            updatedItem.searchTerm = newSearchTerm
            
            // Update in memory
            DispatchQueue.main.async {
                self.clipboardItems[index] = updatedItem
                
                // Also update in pinned items if it exists there
                if let pinnedIndex = self.pinnedItems.firstIndex(where: { $0.id == item.id }) {
                    self.pinnedItems[pinnedIndex] = updatedItem
                }
            }
            
            // Update on disk
            saveItem(updatedItem)
        }
    }
    
    // MARK: - Persistence
    
    /// Save an item to disk
    private func saveItem(_ item: ClipboardItem) {
        let encoder = JSONEncoder()
        
        do {
            let data = try encoder.encode(item)
            let itemFilePath = storageDirectory.appendingPathComponent("\(item.id.uuidString).json")
            try data.write(to: itemFilePath)
            
            // If it's pinned, also save to pinned directory
            if item.isPinned {
                let pinnedDirectory = storageDirectory.appendingPathComponent("Pinned")
                try? fileManager.createDirectory(at: pinnedDirectory, withIntermediateDirectories: true)
                let pinnedFilePath = pinnedDirectory.appendingPathComponent("\(item.id.uuidString).json")
                try data.write(to: pinnedFilePath)
            }
        } catch {
            print("Error saving clipboard item: \(error)")
        }
    }
    
    /// Load items from disk with pagination
    private func loadItems(limit: Int, offset: Int) -> [ClipboardItem] {
        do {
            // Get all item files
            let fileURLs = try fileManager.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles)
            
            // Filter for JSON files and sort by modification date (newest first)
            let sortedFiles = fileURLs.filter { $0.pathExtension == "json" }
                .sorted { (url1, url2) -> Bool in
                    let date1 = try? url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                    let date2 = try? url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                    return date1 ?? Date() > date2 ?? Date()
                }
            
            // Apply pagination
            let paginatedFiles = sortedFiles.dropFirst(offset).prefix(limit)
            
            // Load and decode each file
            return paginatedFiles.compactMap { fileURL in
                do {
                    let data = try Data(contentsOf: fileURL)
                    let decoder = JSONDecoder()
                    return try decoder.decode(ClipboardItem.self, from: data)
                } catch {
                    print("Error loading clipboard item: \(error)")
                    return nil
                }
            }
        } catch {
            print("Error loading clipboard items: \(error)")
            return []
        }
    }
    
    /// Load items before a specific date (for pagination)
    private func loadItems(before date: Date, limit: Int) -> [ClipboardItem] {
        do {
            // Get all item files
            let fileURLs = try fileManager.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles)
            
            // Filter for JSON files and sort by modification date (newest first)
            let sortedFiles = fileURLs.filter { $0.pathExtension == "json" }
                .sorted { (url1, url2) -> Bool in
                    let date1 = try? url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                    let date2 = try? url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                    return date1 ?? Date() > date2 ?? Date()
                }
            
            // Filter for items before the given date
            let filteredFiles = sortedFiles.filter { fileURL in
                if let modDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                    return modDate < date
                }
                return false
            }.prefix(limit)
            
            // Load and decode each file
            return filteredFiles.compactMap { fileURL in
                do {
                    let data = try Data(contentsOf: fileURL)
                    let decoder = JSONDecoder()
                    return try decoder.decode(ClipboardItem.self, from: data)
                } catch {
                    print("Error loading clipboard item: \(error)")
                    return nil
                }
            }
        } catch {
            print("Error loading clipboard items: \(error)")
            return []
        }
    }
    
    /// Load pinned items from disk
    private func loadPinnedItems() -> [ClipboardItem] {
        let pinnedDirectory = storageDirectory.appendingPathComponent("Pinned")
        
        do {
            // Create pinned directory if it doesn't exist
            if !fileManager.fileExists(atPath: pinnedDirectory.path) {
                try fileManager.createDirectory(at: pinnedDirectory, withIntermediateDirectories: true)
                return []
            }
            
            // Get all pinned item files
            let fileURLs = try fileManager.contentsOfDirectory(at: pinnedDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            
            // Filter for JSON files
            let jsonFiles = fileURLs.filter { $0.pathExtension == "json" }
            
            // Load and decode each file
            return jsonFiles.compactMap { fileURL in
                do {
                    let data = try Data(contentsOf: fileURL)
                    let decoder = JSONDecoder()
                    return try decoder.decode(ClipboardItem.self, from: data)
                } catch {
                    print("Error loading pinned clipboard item: \(error)")
                    return nil
                }
            }
        } catch {
            print("Error loading pinned clipboard items: \(error)")
            return []
        }
    }
    
    // MARK: - Cleanup
    
    /// Clear all clipboard history
    public func clearHistory() {
        // Clear memory
        DispatchQueue.main.async {
            self.clipboardItems.removeAll()
            self.pinnedItems.removeAll()
        }
        
        // Clear disk storage
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            for fileURL in fileURLs {
                try fileManager.removeItem(at: fileURL)
            }
            
            // Recreate directories
            let pinnedDirectory = storageDirectory.appendingPathComponent("Pinned")
            try fileManager.createDirectory(at: pinnedDirectory, withIntermediateDirectories: true)
        } catch {
            print("Error clearing clipboard history: \(error)")
        }
    }
    
    /// Cleanup old items to manage storage
    public func cleanupOldItems(olderThan days: Int) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        // Find old items
        let oldItems = clipboardItems.filter { !$0.isPinned && $0.timestamp < cutoffDate }
        
        // Delete each old item
        for item in oldItems {
            deleteItem(item: item)
        }
    }
}