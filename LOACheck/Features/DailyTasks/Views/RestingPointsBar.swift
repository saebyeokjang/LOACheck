//
//  RestingPointsBar.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/24/25.
//

import SwiftUI

struct RestingPointsBar: View {
    var current: Int
    var maximum: Int
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 포인트 텍스트 표시
            HStack {
                Text("휴식보너스")
                    .font(.caption2)
                    .foregroundColor(Color.textSecondary)
                
                Spacer()
                
                Text("\(current)/\(maximum)")
                    .font(.caption2)
                    .foregroundColor(Color.textSecondary)
            }
            
            // 프로그레스 바
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.2))
                        .frame(height: 4)
                    
                    // 채워진 부분
                    RoundedRectangle(cornerRadius: 2)
                        .fill(getBarColor())
                        .frame(width: calculateWidth(geometry.size.width), height: 4)
                }
            }
            .frame(height: 4)
        }
    }
    
    // 채워진 너비 계산
    private func calculateWidth(_ totalWidth: CGFloat) -> CGFloat {
        let percentage = CGFloat(current) / CGFloat(maximum)
        return totalWidth * min(percentage, 1.0)
    }
    
    // 포인트 양에 따른 색상 변경
    private func getBarColor() -> Color {
        let percentage = Double(current) / Double(maximum)
        switch percentage {
        case 0..<0.25:
            return colorScheme == .dark ? Color.blue.opacity(0.8) : Color.blue
        case 0.25..<0.5:
            return colorScheme == .dark ? Color.teal.opacity(0.8) : Color.teal
        case 0.5..<0.75:
            return colorScheme == .dark ? Color.green.opacity(0.8) : Color.green
        case 0.75...1.0:
            return colorScheme == .dark ? Color.orange.opacity(0.8) : Color.orange
        default:
            return colorScheme == .dark ? Color.blue.opacity(0.8) : Color.blue
        }
    }
}
