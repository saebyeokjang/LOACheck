//
//  ThemeModifiers.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/21/25.
//

import SwiftUI

// MARK: - 카드 스타일 모디파이어
struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    
    var hasShadow: Bool = true
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(12)
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1),
                radius: hasShadow ? 5 : 0,
                x: 0,
                y: hasShadow ? 2 : 0
            )
    }
}

// MARK: - 리스트 아이템 스타일 모디파이어
struct ListItemStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(Color.cardBackground)
            .cornerRadius(8)
    }
}

// MARK: - 정보 라벨 스타일
struct InfoLabelStyle: ViewModifier {
    var color: Color = .blue
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(colorScheme == .dark ? color.opacity(0.15) : color.opacity(0.1))
            .cornerRadius(8)
    }
}

// MARK: - View 확장으로 편리하게 사용할 수 있도록 함
extension View {
    func cardStyle(hasShadow: Bool = true) -> some View {
        self.modifier(CardStyle(hasShadow: hasShadow))
    }
    
    func listItemStyle() -> some View {
        self.modifier(ListItemStyle())
    }
    
    func infoLabelStyle(color: Color = .blue) -> some View {
        self.modifier(InfoLabelStyle(color: color))
    }
    
    // 앱 배경색 적용
    func appBackgroundColor() -> some View {
        self.background(Color.backgroundPrimary)
            .edgesIgnoringSafeArea(.all)
    }
    
    // 다크모드/라이트모드 전환 애니메이션
    func themeTransition() -> some View {
        self.animation(.easeInOut(duration: 0.3), value: ThemeManager.shared.isDarkMode)
    }
}

// 특정 모서리만 둥글게 하기 위한 도형
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
