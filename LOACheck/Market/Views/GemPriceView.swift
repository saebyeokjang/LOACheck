//
//  GemPriceView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/28/25.
//

import SwiftUI
import SwiftData

struct GemPriceView: View {
    var onRefresh: (Date) -> Void
    @AppStorage("apiKey") private var apiKey: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showAlert = false
    
    // 보석 필터 상태
    @State private var selectedGemLevel = 7
    @State private var selectedType = 0 // 0: 전체, 1: 멸화, 2: 홍염
    @State private var gemResults: [AuctionItem] = []
    
    // 보석 레벨 선택 옵션
    let gemLevels = [5, 6, 7, 8, 9, 10]
    
    var body: some View {
        VStack {
            if isLoading {
                // 로딩 화면
                ProgressView("보석 시세 불러오는 중...")
                    .padding()
            } else if let error = errorMessage {
                // 에러 화면
                ErrorView(message: error) {
                    // 재시도 버튼 액션
                    loadGemData()
                }
            } else {
                // 보석 필터 섹션
                VStack(spacing: 16) {
                    // 보석 레벨 선택
                    HStack {
                        Text("보석 레벨:")
                            .font(.headline)
                        
                        Spacer()
                        
                        ForEach(gemLevels, id: \.self) { level in
                            Button(action: { selectedGemLevel = level }) {
                                Text("\(level)")
                                    .font(.headline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedGemLevel == level ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedGemLevel == level ? .white : .primary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // 보석 타입 선택
                    Picker("보석 타입", selection: $selectedType) {
                        Text("전체").tag(0)
                        Text("멸화").tag(1)
                        Text("홍염").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    Divider()
                    
                    if gemResults.isEmpty {
                        VStack {
                            Button(action: loadGemData) {
                                Text("보석 시세 불러오기")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)
                            
                            Spacer()
                                .frame(height: 50)
                            
                            Text("보석 시세 데이터가 없습니다\n보석 시세 불러오기 버튼을 눌러주세요")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    } else {
                        // 결과 목록
                        List {
                            ForEach(filteredGemResults) { item in
                                GemResultRow(item: item)
                            }
                        }
                        .listStyle(PlainListStyle())
                        .refreshable {
                            await refreshGemData()
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: loadGemData) {
                    Label("새로고침", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("알림"),
                message: Text(errorMessage ?? ""),
                dismissButton: .default(Text("확인"))
            )
        }
        .onAppear {
            loadGemData()
        }
    }
    
    // 선택된 필터에 따라 결과 필터링
    var filteredGemResults: [AuctionItem] {
        gemResults.filter { item in
            // 타입 필터링 (전체인 경우 모두 표시)
            let typeMatch = selectedType == 0 ||
                (selectedType == 1 && item.name.contains("멸화")) ||
                (selectedType == 2 && item.name.contains("홍염"))
            
            return typeMatch
        }
    }
    
    // 보석 데이터 로드
    private func loadGemData() {
        guard !apiKey.isEmpty else {
            errorMessage = "API 키가 설정되지 않았습니다. 설정 탭에서 API 키를 입력해주세요."
            showAlert = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // API 호출 시뮬레이션 (실제 구현에서는 실제 API 호출로 대체)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            let currentDate = Date()
            onRefresh(currentDate)
            
            // 임시 결과 생성 (실제 API 응답으로 대체 필요)
            self.gemResults = self.generateSampleGemResults()
        }
    }
    
    // 당겨서 새로고침
    private func refreshGemData() async {
        guard !apiKey.isEmpty else {
            errorMessage = "API 키가 설정되지 않았습니다. 설정 탭에서 API 키를 입력해주세요."
            showAlert = true
            return
        }
        
        // 비동기 데이터 로드 시뮬레이션
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        await MainActor.run {
            let currentDate = Date()
            onRefresh(currentDate)
            gemResults = generateSampleGemResults()
        }
    }
    
    // 샘플 보석 데이터 생성 (실제 구현 시 제거)
    private func generateSampleGemResults() -> [AuctionItem] {
        var results: [AuctionItem] = []
        
        // 보석 스킬 목록
        let melGemSkills = ["블레이드 블러드", "마운틴 크래쉬", "도끼 스톰", "역습", "스핀 커터", "소울 이터", "초월 구슬"]
        let honGemSkills = ["대지 강타", "차지 스팅어", "데스 칼라", "천벌", "블루 홀", "배쉬", "엘리멘탈 슬래쉬"]
        
        // 멸화 보석 추가
        for skill in melGemSkills {
            let options = [
                ItemOption(
                    type: "GEM_EFFECT",
                    optionName: "\(skill)의 피해 증가",
                    value: Double(selectedGemLevel * 3),
                    isPenalty: false
                )
            ]
            
            let item = AuctionItem(
                name: "레벨 \(selectedGemLevel) 멸화의 보석",
                grade: "고대",
                tier: 3,
                icon: "https://cdn-lostark.game.onstove.com/efui_iconatlas/gem_red.png",
                auctionInfo: AuctionInfo(
                    startPrice: (selectedGemLevel == 7) ? Int.random(in: 1500...2500) * 100 :
                               (selectedGemLevel == 8) ? Int.random(in: 4000...6000) * 100 :
                               (selectedGemLevel == 9) ? Int.random(in: 12000...18000) * 100 :
                               (selectedGemLevel == 10) ? Int.random(in: 35000...50000) * 100 :
                               Int.random(in: 500...1000) * 100,
                    buyPrice: nil,
                    bidPrice: Int.random(in: 1000...100000) * 10,
                    endDate: Date().addingTimeInterval(86400),
                    bidCount: Int.random(in: 0...5),
                    bidStartPrice: Int.random(in: 1000...100000) * 10
                ),
                options: options
            )
            results.append(item)
        }
        
        // 홍염 보석 추가
        for skill in honGemSkills {
            let options = [
                ItemOption(
                    type: "GEM_EFFECT",
                    optionName: "\(skill)의 재사용 대기시간 감소",
                    value: Double(selectedGemLevel * 2),
                    isPenalty: false
                )
            ]
            
            let item = AuctionItem(
                name: "레벨 \(selectedGemLevel) 홍염의 보석",
                grade: "고대",
                tier: 3,
                icon: "https://cdn-lostark.game.onstove.com/efui_iconatlas/gem_blue.png",
                auctionInfo: AuctionInfo(
                    startPrice: (selectedGemLevel == 7) ? Int.random(in: 1500...2500) * 100 :
                               (selectedGemLevel == 8) ? Int.random(in: 4000...6000) * 100 :
                               (selectedGemLevel == 9) ? Int.random(in: 12000...18000) * 100 :
                               (selectedGemLevel == 10) ? Int.random(in: 35000...50000) * 100 :
                               Int.random(in: 500...1000) * 100,
                    buyPrice: nil,
                    bidPrice: Int.random(in: 1000...100000) * 10,
                    endDate: Date().addingTimeInterval(86400),
                    bidCount: Int.random(in: 0...5),
                    bidStartPrice: Int.random(in: 1000...100000) * 10
                ),
                options: options
            )
            results.append(item)
        }
        
        // 가격순 정렬
        return results.sorted { $0.auctionInfo.bidStartPrice < $1.auctionInfo.bidStartPrice }
    }
}
