//
//  GemResultRow.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/31/25.
//

import SwiftUI
import SwiftData

struct GemResultRow: View {
    var item: AuctionItem
        @Environment(\.colorScheme) private var colorScheme
        
        // 보석 레벨에 따른 색상 결정
        private func getGemColor(level: Int) -> Color {
            switch level {
            case 10:
                return Color.ancientGrade
            case 8...9:
                return Color.relicGrade
            case 5...7:
                return Color.legendaryGrade
            case 3...4:
                return Color.epicGrade
            case 1...2:
                return Color.rareGrade
            default:
                return Color.gray
            }
        }
        
        // 보석 이름에서 레벨 추출 (예: "10레벨 겁화의 보석" -> 10)
        private func extractGemLevel() -> Int {
            guard let levelStr = item.name.components(separatedBy: "레벨").first?.trimmingCharacters(in: .whitespaces),
                  let level = Int(levelStr) else {
                return 0
            }
            return level
        }
        
        // 보석 타입 확인 (겁화 또는 작열)
        private func isRedGem() -> Bool {
            return item.name.contains("겁화")
        }
        
        var body: some View {
            HStack(spacing: 12) {
                // 보석 아이콘 (레벨별 테두리 색상 적용)
                AsyncImage(url: URL(string: item.icon)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    // 다크모드에서 보석 색상이 더 잘 보이도록 조정
                    Image(systemName: "circle.hexagongrid.fill")
                        .foregroundColor(isRedGem() ?
                            (colorScheme == .dark ? .red.opacity(0.7) : .red) :
                            (colorScheme == .dark ? .blue.opacity(0.7) : .blue))
                }
                .frame(width: 48, height: 48)
                // 다크모드에 맞게 배경색 투명도 조정
                .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.black.opacity(0.05))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        // 다크모드에서 테두리가 더 잘 보이도록 투명도 조정
                        .stroke(getGemColor(level: extractGemLevel()).opacity(colorScheme == .dark ? 0.8 : 1.0), lineWidth: 2)
                )
                
                // 보석 이름 - 다크모드에서 더 잘 보이도록 불투명도 조정
                Text(item.name)
                    .font(.headline)
                    .foregroundColor(getGemColor(level: extractGemLevel()).opacity(colorScheme == .dark ? 0.9 : 1.0))
                
                Spacer()
                
                // 가격 정보 (즉시구매가) - 다크모드에서도 잘 보이도록 컬러 조정
                Text("\(item.auctionInfo.buyPrice ?? item.auctionInfo.bidStartPrice) G")
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .orange.opacity(0.9) : .orange)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            // 배경색을 Color.white에서 Color.cardBackground로 변경
            .background(Color.cardBackground)
            .cornerRadius(8)
            // 다크모드에 맞게 그림자 조정
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 2, x: 0, y: 1)
        }
    }
