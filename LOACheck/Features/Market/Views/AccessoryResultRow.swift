//
//  AccessoryResultRow.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/28/25.
//

import SwiftUI
import SwiftData

// 장신구 검색 결과 행 컴포넌트 (수정)
struct AccessoryResultRow: View {
    var item: AuctionItem
    
    // 효과 등급 색상 결정을 위한 헬퍼 함수
    private func getEffectTierColor(effect: ItemOption) -> Color {
        let tier = EngraveEffectManager.shared.getEffectTier(
            name: effect.optionName,
            value: effect.value
        )
        return tier.color
    }
    
    // 스탯 색상 결정을 위한 헬퍼 함수
    private func getStatColor(stat: ItemOption, partType: String, upgradeLevel: Int) -> Color {
        if stat.type == "5" || stat.type == "STAT" {
            let percentage = StatManager.shared.calculateStatPercentage(
                partType: partType,
                upgradeLevel: upgradeLevel,
                statValue: Int(stat.value)
            )
            return StatManager.shared.getColorForStatPercentage(percentage)
        }
        return getEffectTierColor(effect: stat)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 아이템 상단 정보 (아이콘, 이름, 가격)
            HStack(spacing: 12) {
                VStack(spacing: 0) {
                    AsyncImage(url: URL(string: item.icon)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(2) // 내부 패딩 추가
                    } placeholder: {
                        Image(systemName: "diamond.fill")
                            .foregroundColor(.orange)
                    }
                    .frame(width: 52, height: 48) // 프레임 크기 증가
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(6, corners: [.topLeft, .topRight])
                    
                    // 품질 표시
                    let qualityValue = item.quality ?? 0
                    Text("\(qualityValue)")
                        .font(.system(size: 10))
                        .fontWeight(.bold)
                        .padding(.vertical, 1)
                        .frame(width: 52) // 아이콘과 동일한 너비
                        .background(getQualityColor(qualityValue))
                        .foregroundColor(.white)
                        .cornerRadius(6, corners: [.bottomLeft, .bottomRight])
                }
                .padding(2)
                
                // 아이템 이름 및 거래 횟수
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundColor(Color.ancientGrade)
                    
                    if let tradeCount = item.tradeAllowCount {
                        Text("거래 가능 횟수: \(tradeCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 가격 정보
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(item.auctionInfo.buyPrice ?? item.auctionInfo.bidStartPrice) G")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Text(item.auctionInfo.buyPrice != nil ? "즉시 구매가" : "최저 입찰가")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 스탯 정보 (체력, 기본특성)
            HStack {
                // 체력 스탯
                if let healthOption = item.options.first(where: { $0.type == "5" && $0.optionName.contains("체력") }) {
                    StatView(name: "체력", value: Int(healthOption.value))
                }
                
                Spacer()
                
                // 기본 특성들 (힘/민첩/지능)
                // UpgradeLevel 가져오기
                let upgradeLevel = item.auctionInfo.upgradeLevel ?? 0
                
                // 부위 타입 가져오기
                let partType = StatManager.shared.getPartTypeFromName(item.name)
                
                // 기본 특성 필터링 및 표시
                let statOptions = item.options.filter {
                    ($0.type == "5" || $0.type == "STAT") && !$0.optionName.contains("체력")
                }
                
                ForEach(Array(statOptions.enumerated()), id: \.offset) { index, stat in
                    let statValue = Int(stat.value)
                    let statColor = getStatColor(stat: stat, partType: partType, upgradeLevel: upgradeLevel)
                    
                    StatView(
                        name: self.getStatShortName(stat.optionName),
                        value: statValue,
                        color: statColor
                    )
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(4)
            
            // 연마효과 정보
            let upgradeEffects = item.options.filter { $0.type == "ACCESSORY_UPGRADE" }
            if !upgradeEffects.isEmpty {
                HStack(spacing: 8) {
                    // enumerated()를 사용하여 인덱스를 ID로 활용
                    ForEach(Array(upgradeEffects.enumerated()), id: \.offset) { index, effect in
                        let effectColor = getEffectTierColor(effect: effect)
                        
                        VStack(spacing: 2) {
                            // 공백 제거
                            Text(effect.optionName.trimmingCharacters(in: .whitespaces))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            if effect.isValuePercentage {
                                Text("+\(String(format: "%.2f", effect.value))%")
                                    .font(.caption2)
                                    .foregroundColor(effectColor)
                                    .fontWeight(.bold)
                            } else {
                                Text("+\(Int(effect.value))")
                                    .font(.caption)
                                    .foregroundColor(effectColor)
                                    .fontWeight(.bold)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(effectColor.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
    }
    
    // 품질에 따른 색상 반환
    private func getQualityColor(_ quality: Int) -> Color {
        switch quality {
        case 0..<10: return .red
        case 10..<30: return .yellow
        case 30..<70: return .green
        case 70..<90: return .blue
        case 90..<100: return .purple
        case 100: return Color(red: 1.0, green: 0.5, blue: 0.0)
        default: return .gray
        }
    }
    
    // 스탯 이름 축약
    private func getStatShortName(_ fullName: String) -> String {
        if fullName.contains("힘") { return "힘" }
        if fullName.contains("민첩") { return "민첩" }
        if fullName.contains("지능") { return "지능" }
        return fullName
    }
}
