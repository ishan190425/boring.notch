# Updated Clipboard Tab Implementation Plan

## 1. Fix Search Functionality

The current search implementation may not be working correctly. We need to:

1. Debug the search filtering logic in the BoringClipboard view
2. Ensure the search text is properly applied to filter both pinned and regular items
3. Make sure the UI updates when the search text changes

## 2. Add Custom Search Terms Feature

Add the ability for users to add custom search terms/tags to clipboard items:

### Data Model Updates

```swift
struct ClipboardItem: Identifiable, Codable {
    // Existing properties...
    
    // New property for custom search term
    var searchTerm: String?
    
    // Update hasSameContent method to include searchTerm in comparison
}
```

### UI Updates

1. Add a way to edit search terms:
   - Add an "Edit Tags" button to the ClipboardItemCard
   - Create a popover or sheet for editing the search term
   - Allow users to save the custom search term

2. Display the search term in the ClipboardItemCard:
   - Show a tag/badge with the search term if it exists
   - Make it visually distinct from the content preview

### Search Functionality Updates

1. Update the itemMatchesSearch method to include the custom search term:

```swift
private func itemMatchesSearch(_ item: ClipboardItem, searchText: String) -> Bool {
    let lowercasedSearch = searchText.lowercased()
    
    // Check if the search term matches
    if let searchTerm = item.searchTerm, 
       searchTerm.lowercased().contains(lowercasedSearch) {
        return true
    }
    
    // Existing search logic for content types...
}
```

## 3. Implementation Steps

1. Update the ClipboardItem model to include the searchTerm property
2. Update the ClipboardManager to handle saving and loading search terms
3. Update the ClipboardItemCard to display and allow editing of search terms
4. Fix the search functionality to properly filter items
5. Update the search logic to include search terms in the filtering

## 4. UI Mockup for Search Term Feature

```
+----------------------------------+
|           Clipboard Item         |
|                                  |
| [Content Preview]                |
|                                  |
| [Tag: CustomSearchTerm]          |
|                                  |
| Copy | Pin | Edit Tags | Delete  |
+----------------------------------+

+----------------------------------+
|         Edit Search Term         |
|                                  |
| Search Term:                     |
| [                      ]         |
|                                  |
|           [Save] [Cancel]        |
+----------------------------------+
```

This updated plan addresses both the search functionality issue and adds the ability to add custom search terms to clipboard items, making them easier to find later.