//
//  ThemeManager.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/21/25.
//

import SwiftUI

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    var colorScheme: ColorScheme? {
        return isDarkMode ? .dark : .light
    }
}
