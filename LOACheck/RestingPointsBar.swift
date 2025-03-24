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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 포인트 텍스트 표시
            HStack {
                Text("휴식보너스")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(current)/\(maximum)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // 프로그레스 바
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 배경
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
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
        case 0..<0.25: return .blue
        case 0.25..<0.5: return .teal
        case 0.5..<0.75: return .green
        case 0.75...1.0: return .orange
        default: return .blue
        }
    }
}
