//
//  MarketComponents.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/28/25.
//

import SwiftUI
import SwiftData

// MARK: - 수정된 SearchFilterSection
struct SearchFilterSection<Content: View>: View {
    var title: String
    @State var isExpanded: Bool
    let content: Content
    @Environment(\.colorScheme) private var colorScheme
    
    init(title: String, isExpanded: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self._isExpanded = State(initialValue: isExpanded)
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더 (탭 가능)
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(Color.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(Color.textSecondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(colorScheme == .dark ? Color.gray.opacity(0.1) : Color.gray.opacity(0.05))
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            
            // 확장된 컨텐츠
            if isExpanded {
                content
                    .padding(.vertical, 12)
                    .background(Color.cardBackground) // 다크모드 대응
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(colorScheme == .dark ? Color.gray.opacity(0.1) : Color.gray.opacity(0.05))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}


// 필터 칩 컴포넌트
struct FilterChip: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}
