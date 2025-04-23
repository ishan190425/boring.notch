//
//  BoringClipboard.swift
//  boringNotch
//
//  Created on 2025-04-22.
//

import SwiftUI
import AppKit
import Combine

// Import the ClipboardManager and ClipboardItem
// Note: In a real project, these would be properly imported through module structure
// This is a workaround for the IDE issues
// In a real project, you would use proper module imports

struct BoringClipboard: View {
    @StateObject private var clipboardManager = ClipboardManager()
    @State private var searchText: String = ""
    @State private var showSettings: Bool = false
    @State private var showClearConfirmation: Bool = false
    @State private var itemToEditSearchTerm: ClipboardItem? = nil
    @State private var editingSearchTerm: String = ""
    
    var body: some View {
        VStack(spacing: 12) {
            // Search and actions bar
            HStack {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    // Fix for search field not accepting input
                    TextField("Search clipboard", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.white)
                        .frame(height: 24)
                        .focusable(true)
                        .onSubmit {
                            // Force update filtered items when pressing return
                            let currentText = searchText
                            searchText = ""
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                searchText = currentText
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .textBackgroundColor).opacity(0.3))
                )
                
                Spacer()
                
                // Action buttons
                Button(action: {
                    showSettings.toggle()
                }) {
                    Image(systemName: "gear")
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Clipboard Settings")
                
                Button(action: {
                    showClearConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Clear Clipboard History")
                .alert(isPresented: $showClearConfirmation) {
                    Alert(
                        title: Text("Clear Clipboard History"),
                        message: Text("Are you sure you want to clear all clipboard history? This action cannot be undone."),
                        primaryButton: .destructive(Text("Clear")) {
                            clipboardManager.clearHistory()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Content area
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Pinned items section
                    if !filteredPinnedItems.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pinned")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                            
                            ForEach(filteredPinnedItems) { item in
                                ClipboardItemCard(
                                    item: item,
                                    onCopy: { copyItem(item) },
                                    onDelete: { deleteItem(item) },
                                    onPin: { togglePin(item) },
                                    onEditSearchTerm: { showEditSearchTermSheet(for: item) }
                                )
                                .padding(.horizontal, 16)
                            }
                        }
                        
                        Divider()
                            .background(Color.gray.opacity(0.3))
                            .padding(.vertical, 8)
                    }
                    
                    // Recent items section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                        
                        if filteredClipboardItems.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(filteredClipboardItems) { item in
                                ClipboardItemCard(
                                    item: item,
                                    onCopy: { copyItem(item) },
                                    onDelete: { deleteItem(item) },
                                    onPin: { togglePin(item) },
                                    onEditSearchTerm: { showEditSearchTermSheet(for: item) }
                                )
                                .padding(.horizontal, 16)
                            }
                            
                            // Load more indicator
                            if clipboardManager.isLoading {
                                ProgressView()
                                    .padding()
                            } else {
                                Button("Load More") {
                                    clipboardManager.loadMoreItems()
                                }
                                .buttonStyle(PlainButtonStyle())
                                .foregroundColor(.blue)
                                .padding()
                                .onAppear {
                                    // Auto-load more when reaching the end
                                    clipboardManager.loadMoreItems()
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $showSettings) {
            ClipboardSettingsView()
        }
        .sheet(item: $itemToEditSearchTerm, onDismiss: nil) { item in
            SearchTermEditView(
                searchTerm: item.searchTerm ?? "",
                onSave: { newSearchTerm in
                    updateSearchTerm(item, newSearchTerm: newSearchTerm)
                    itemToEditSearchTerm = nil
                },
                onCancel: {
                    itemToEditSearchTerm = nil
                }
            )
            .frame(width: 300, height: 150)
        }
    }
    
    // MARK: - Computed Properties
    
    var filteredClipboardItems: [ClipboardItem] {
        if searchText.isEmpty {
            return clipboardManager.clipboardItems.filter { !$0.isPinned }
        } else {
            let searchTermLowercased = searchText.lowercased()
            return clipboardManager.clipboardItems.filter { item in
                !item.isPinned && itemMatchesSearch(item, searchText: searchTermLowercased)
            }
        }
    }
    
    var filteredPinnedItems: [ClipboardItem] {
        if searchText.isEmpty {
            return clipboardManager.pinnedItems
        } else {
            let searchTermLowercased = searchText.lowercased()
            return clipboardManager.pinnedItems.filter { item in
                itemMatchesSearch(item, searchText: searchTermLowercased)
            }
        }
    }
    
    // MARK: - Helper Views
    
    var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clipboard")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No clipboard items")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Copy something to see it here")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Helper Methods
    
    private func copyItem(_ item: ClipboardItem) {
        clipboardManager.copyToClipboard(item: item)
    }
    
    private func deleteItem(_ item: ClipboardItem) {
        clipboardManager.deleteItem(item: item)
    }
    
    private func togglePin(_ item: ClipboardItem) {
        clipboardManager.togglePin(item: item)
    }
    
    private func showEditSearchTermSheet(for item: ClipboardItem) {
        editingSearchTerm = item.searchTerm ?? ""
        itemToEditSearchTerm = item
    }
    
    private func updateSearchTerm(_ item: ClipboardItem, newSearchTerm: String) {
        let trimmedSearchTerm = newSearchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        clipboardManager.updateSearchTerm(item: item, newSearchTerm: trimmedSearchTerm.isEmpty ? nil : trimmedSearchTerm)
    }
    
    private func itemMatchesSearch(_ item: ClipboardItem, searchText: String) -> Bool {
        // Search text is already lowercased by the caller
        
        // Check if the search term matches
        if let searchTerm = item.searchTerm,
           searchTerm.lowercased().contains(searchText) {
            return true
        }
        
        // Check content based on type
        switch item.type {
        case .text:
            return item.textContent?.lowercased().contains(searchText) ?? false
        case .file:
            return (item.fileName?.lowercased().contains(searchText) ?? false) ||
                   (item.fileType?.lowercased().contains(searchText) ?? false)
        case .image:
            // Images can't be searched by content, but we could match by date
            return item.formattedTimestamp.lowercased().contains(searchText)
        }
    }
}

// MARK: - Search Term Edit View

struct SearchTermEditView: View {
    @State private var searchTerm: String
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    init(searchTerm: String, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        _searchTerm = State(initialValue: searchTerm)
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Search Term")
                .font(.headline)
                .foregroundColor(.white)
            
            TextField("Search Term", text: $searchTerm)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(BorderlessButtonStyle())
                .foregroundColor(.gray)
                
                Spacer()
                
                Button("Save") {
                    onSave(searchTerm)
                }
                .buttonStyle(BorderlessButtonStyle())
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Settings View

struct ClipboardSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var maxHistoryDays: Double = 30
    @State private var autoCleanupEnabled: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Clipboard Settings")
                .font(.title)
                .foregroundColor(.white)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Auto cleanup settings
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Enable automatic cleanup", isOn: $autoCleanupEnabled)
                    .foregroundColor(.white)
                
                if autoCleanupEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Keep clipboard history for:")
                            .foregroundColor(.white)
                        
                        HStack {
                            Slider(value: $maxHistoryDays, in: 1...365, step: 1)
                            
                            Text("\(Int(maxHistoryDays)) days")
                                .foregroundColor(.white)
                                .frame(width: 70, alignment: .trailing)
                        }
                    }
                    .padding(.leading, 20)
                }
            }
            
            Spacer()
            
            HStack {
                Spacer()
                
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(BorderlessButtonStyle())
                .foregroundColor(.blue)
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

struct BoringClipboard_Previews: PreviewProvider {
    static var previews: some View {
        BoringClipboard()
            .frame(width: 400, height: 600)
            .background(Color.black)
    }
}
