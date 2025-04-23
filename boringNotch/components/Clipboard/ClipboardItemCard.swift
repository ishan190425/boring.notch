//
//  ClipboardItemCard.swift
//  boringNotch
//
//  Created on 2025-04-22.
//

import SwiftUI
import AppKit

// Note: In a real project, these would be properly imported through module structure
// This is a workaround for the IDE issues

struct ClipboardItemCard: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onPin: () -> Void
    let onEditSearchTerm: () -> Void
    
    @State private var isHovering: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with timestamp and actions
            HStack {
                Text(item.formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                // Actions
                HStack(spacing: 12) {
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.white)
                    .help("Copy to clipboard")
                    
                    Button(action: onPin) {
                        Image(systemName: item.isPinned ? "pin.fill" : "pin")
                            .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(item.isPinned ? .yellow : .white)
                    .help(item.isPinned ? "Unpin" : "Pin")
                    
                    Button(action: onEditSearchTerm) {
                        Image(systemName: "tag")
                            .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(item.searchTerm != nil ? .blue : .white)
                    .help("Edit search term")
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.white)
                    .help("Delete")
                }
                .opacity(isHovering ? 1.0 : 0.0)
            }
            
            // Search term tag if it exists
            if let searchTerm = item.searchTerm, !searchTerm.isEmpty {
                HStack {
                    Text(searchTerm)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue.opacity(0.2))
                        )
                        .foregroundColor(.blue)
                        .onTapGesture {
                            onEditSearchTerm()
                        }
                }
            }
            
            // Content preview based on type
            contentPreview
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(item.isPinned ? Color.yellow.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
    
    @ViewBuilder
    var contentPreview: some View {
        switch item.type {
        case .text:
            if let text = item.textContent {
                Text(text.prefix(100))
                    .lineLimit(3)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(nsColor: .textBackgroundColor).opacity(0.3))
                    )
            } else {
                Text("Empty text")
                    .italic()
                    .foregroundColor(.gray)
            }
            
        case .image:
            if let imagePath = item.imageFilePath, let nsImage = NSImage(contentsOfFile: imagePath) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 100)
                    .cornerRadius(4)
            } else {
                Text("Image not available")
                    .italic()
                    .foregroundColor(.gray)
            }
            
        case .file:
            HStack {
                Image(systemName: "doc")
                    .font(.title)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text(item.fileName ?? "Unknown file")
                        .font(.body)
                        .foregroundColor(.white)
                    
                    if let fileType = item.fileType {
                        Text(fileType.uppercased())
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.3))
            )
        }
    }
}

struct ClipboardItemCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            // Text preview
            ClipboardItemCard(
                item: ClipboardItem(textContent: "This is a sample text clipboard item that might be quite long and need to be truncated in the preview."),
                onCopy: {},
                onDelete: {},
                onPin: {},
                onEditSearchTerm: {}
            )
            .frame(width: 300)
            
            // Image preview (would need a valid image path for actual preview)
            ClipboardItemCard(
                item: ClipboardItem(imagePath: "/path/to/image.png"),
                onCopy: {},
                onDelete: {},
                onPin: {},
                onEditSearchTerm: {}
            )
            .frame(width: 300)
            
            // File preview
            ClipboardItemCard(
                item: ClipboardItem(fileName: "document.pdf", fileType: "pdf"),
                onCopy: {},
                onDelete: {},
                onPin: {},
                onEditSearchTerm: {}
            )
            .frame(width: 300)
            
            // With search term
            ClipboardItemCard(
                item: {
                    var item = ClipboardItem(textContent: "Item with search term")
                    item.searchTerm = "Important"
                    return item
                }(),
                onCopy: {},
                onDelete: {},
                onPin: {},
                onEditSearchTerm: {}
            )
            .frame(width: 300)
        }
        .padding()
        .background(Color.black)
    }
}