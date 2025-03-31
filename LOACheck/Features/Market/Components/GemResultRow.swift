//
//  GemResultRow.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/31/25.
//

import SwiftUI
import SwiftData

// 보석 결과 행 컴포넌트
struct GemResultRow: View {
    var item: AuctionItem
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: item.icon)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: "circle.hexagongrid.fill")
                    .foregroundColor(item.name.contains("멸화") ? .red : .blue)
            }
            .frame(width: 40, height: 40)
            .background(Color.black.opacity(0.05))
            .cornerRadius(6)
            
            // 보석 정보
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                
                // 보석 효과
                if let effect = item.options.first {
                    HStack(spacing: 4) {
                        Text(effect.optionName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(effect.value))%")
                            .font(.caption)
                            .foregroundColor(item.name.contains("멸화") ? .red : .blue)
                            .fontWeight(.bold)
                    }
                }
            }
            
            Spacer()
            
            // 가격 정보
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(item.auctionInfo.startPrice.formattedGold) G")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 8)
    }
}
