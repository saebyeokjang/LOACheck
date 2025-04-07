//
//  StatView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/31/25.
//

import SwiftUI

// 스탯 표시용 작은 뷰
struct StatView: View {
    var name: String
    var value: Int
    var color: Color?
    
    var body: some View {
        HStack(spacing: 2) {
            Text(name.contains("최대") ? "체력" : name)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(value)")
                .font(.caption)
                .foregroundColor(color ?? .blue)
                .fontWeight(.bold)
        }
    }
}
