//
//  RemindersSettings.swift
//  boringNotch
//
//  Created on 4/21/2025.
//

import SwiftUI
import Defaults

struct RemindersSettings: View {
    @Default(.showReminders) var showReminders
    
    var body: some View {
        Form {
            Section {
                Defaults.Toggle("Show reminders", key: .showReminders)
            } header: {
                Text("General")
            }
        }
        .tint(Defaults[.accentColor])
        .navigationTitle("Reminders")
    }
}

#Preview {
    RemindersSettings()
}