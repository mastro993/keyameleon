//
//  Button+Extension.swift
//  Keyameleon
//
//  Created by Federico Mastrini on 26/09/2026.
//

import SwiftUI

extension Button where Label == Image {
    init(systemImage: String, action: @escaping @MainActor () -> Void) {
        self.init(action: action) {
            Image(systemName: systemImage)
        }
    }
}
