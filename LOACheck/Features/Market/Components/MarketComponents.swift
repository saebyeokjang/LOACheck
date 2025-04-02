//
//  MarketComponents.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/28/25.
//

import SwiftUI
import SwiftData

// 검색 필터 섹션 컴포넌트
struct SearchFilterSection<Content: View>: View {
    var title: String
    @State var isExpanded: Bool
    let content: Content
    
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
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            
            // 확장된 컨텐츠
            if isExpanded {
                content
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Color.gray.opacity(0.05))
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
