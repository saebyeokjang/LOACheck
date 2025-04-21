//
//  StatView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/31/25.
//

import SwiftUI

// 스탯 표시용 컴포넌트
struct StatView: View {
    var name: String
    var value: Int
    var color: Color = .blue
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(name)
                .font(.caption2)
                .foregroundColor(Color.textSecondary)
            
            Text("\(value)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(colorScheme == .dark ? color.opacity(0.15) : color.opacity(0.1))
        .cornerRadius(4)
    }
}
