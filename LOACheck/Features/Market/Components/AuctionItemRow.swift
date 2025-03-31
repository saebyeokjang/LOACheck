//
//  AuctionItemRow.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/31/25.
//

import SwiftUI
import SwiftData

// 경매 아이템 행 (각인서 목록용)
struct AuctionItemRow: View {
    var item: AuctionItem
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: item.icon)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: "book.fill")
                    .foregroundColor(.orange)
            }
            .frame(width: 40, height: 40)
            .background(Color.black.opacity(0.05))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.red.opacity(0.7), lineWidth: 2)
            )
            
            // 아이템 정보
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                
                // 각인 정보
                let engraveInfo = item.engraveInfo
                if !engraveInfo.isEmpty {
                    ForEach(Array(engraveInfo.keys.sorted()), id: \.self) { key in
                        if let value = engraveInfo[key] {
                            HStack(spacing: 4) {
                                Text(key)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("+\(Int(value))")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // 가격 정보
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(item.auctionInfo.bidStartPrice.formattedGold) G")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}
