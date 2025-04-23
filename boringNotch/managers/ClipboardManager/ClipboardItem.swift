//
//  ClipboardItem.swift
//  boringNotch
//
//  Created on 2025-04-22.
//

import Foundation
import AppKit

/// Represents the type of content stored in a clipboard item
public enum ClipboardItemType: String, Codable {
    case text
    case image
    case file
}

/// Represents a single clipboard item with metadata and content
public struct ClipboardItem: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public var type: ClipboardItemType
    public var isPinned: Bool
    
    // Content will be stored differently based on type
    public var textContent: String?
    public var imageFilePath: String?
    public var fileURL: URL?
    public var fileType: String?
    public var fileName: String?
    
    // Custom search term for easier searching
    public var searchTerm: String?
    
    // Computed property for preview text (for text items)
    public var previewText: String {
        return textContent?.prefix(100).description ?? ""
    }
    
    // Computed property for formatted timestamp
    public var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    // Initialize with text content
    public init(textContent: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.type = .text
        self.isPinned = false
        self.textContent = textContent
    }
    
    // Initialize with image
    public init(image: NSImage, filePath: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.type = .image
        self.isPinned = false
        self.imageFilePath = filePath
    }
    
    // Initialize with file URL
    public init(fileURL: URL) {
        self.id = UUID()
        self.timestamp = Date()
        self.type = .file
        self.isPinned = false
        self.fileURL = fileURL
        self.fileName = fileURL.lastPathComponent
        self.fileType = fileURL.pathExtension
    }
    
    // Initialize with image path (for previews)
    public init(imagePath: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.type = .image
        self.isPinned = false
        self.imageFilePath = imagePath
    }
    
    // Initialize with file info (for previews)
    public init(fileName: String, fileType: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.type = .file
        self.isPinned = false
        self.fileName = fileName
        self.fileType = fileType
    }
    
    // Custom initializer for creating from pasteboard content
    public static func fromPasteboard(pasteboard: NSPasteboard) -> ClipboardItem? {
        // Check for text content
        if let text = pasteboard.string(forType: .string) {
            return ClipboardItem(textContent: text)
        }
        
        // Check for image content
        if let image = NSImage(pasteboard: pasteboard) {
            // Create a temporary file path for the image
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = UUID().uuidString + ".png"
            let filePath = tempDir.appendingPathComponent(fileName).path
            
            // Save the image to the temporary file
            if let tiffData = image.tiffRepresentation,
               let bitmapImage = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                try? pngData.write(to: URL(fileURLWithPath: filePath))
                return ClipboardItem(image: image, filePath: filePath)
            }
        }
        
        // Check for file URLs
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !fileURLs.isEmpty {
            return ClipboardItem(fileURL: fileURLs[0])
        }
        
        return nil
    }
    
    // Check if this item has the same content as another item
    public func hasSameContent(as other: ClipboardItem) -> Bool {
        // Different types can't have the same content
        if self.type != other.type {
            return false
        }
        
        // Compare content based on type
        let contentMatches: Bool
        switch self.type {
        case .text:
            contentMatches = self.textContent == other.textContent
        case .image:
            // For images, we compare file paths if they're the same
            // A more robust solution would compare image data
            contentMatches = self.imageFilePath == other.imageFilePath
        case .file:
            // For files, compare URLs
            if let selfURL = self.fileURL, let otherURL = other.fileURL {
                contentMatches = selfURL == otherURL
            } else {
                // If URLs aren't available, compare names and types
                contentMatches = self.fileName == other.fileName && self.fileType == other.fileType
            }
        }
        
        // If content matches, we consider it the same item regardless of search term
        // This prevents duplicates when editing search terms
        return contentMatches
    }
}
