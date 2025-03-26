//
//  CharacterListView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/20/25.
//

import SwiftUI
import SwiftData

struct CharacterListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var characters: [CharacterModel]
    
    init() {
        var descriptor = FetchDescriptor<CharacterModel>()
        descriptor.sortBy = [SortDescriptor(\CharacterModel.level, order: .reverse)]
        _characters = Query(descriptor)
    }
    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // 골드 획득 캐릭터 수 제한
    private let maxGoldEarners = 256
    
    var filteredCharacters: [CharacterModel] {
        if searchText.isEmpty {
            return characters
        } else {
            return characters.filter { $0.name.localizedCaseInsensitiveContains(searchText) ||
                                      $0.characterClass.localizedCaseInsensitiveContains(searchText) ||
                                      $0.server.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("캐릭터 관리")) {
                    ForEach(filteredCharacters) { character in
                        CharacterRow(character: character, maxGoldEarners: maxGoldEarners, goldEarnerCount: goldEarnerCount)
                    }
                    .onDelete(perform: deleteCharacters)
                }
                
                StatisticsSection(
                    characters: characters,
                    maxGoldEarners: maxGoldEarners,
                    goldEarnerCount: goldEarnerCount
                )
            }
            .searchable(text: $searchText, prompt: "이름, 직업, 서버 검색")
            .navigationTitle("캐릭터 관리")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: refreshCharacters) {
                        Label("새로고침", systemImage: "arrow.clockwise")
                    }
                    .disabled(isRefreshing)
                }
            }
            .overlay {
                if isRefreshing {
                    ProgressView("캐릭터 정보 갱신 중...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
            .alert("알림", isPresented: $showAlert) {
                Button("확인") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // 골드 획득 캐릭터 수
    private var goldEarnerCount: Int {
        characters.filter { $0.isGoldEarner }.count
    }
    
    // 캐릭터 삭제
    private func deleteCharacters(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredCharacters[index])
        }
    }
    
    // 캐릭터 정보 새로고침
    private func refreshCharacters() {
        guard let apiKey = UserDefaults.standard.string(forKey: "apiKey"), !apiKey.isEmpty else {
            alertMessage = "API 키가 설정되지 않았습니다. 설정 탭에서 API 키를 입력해주세요."
            showAlert = true
            return
        }
        
        isRefreshing = true
        
        Task {
            let result = await LostArkAPIService.shared.fetchCharacters(apiKey: apiKey, modelContext: modelContext)
            
            await MainActor.run {
                isRefreshing = false
                
                switch result {
                case .success(let count):
                    alertMessage = "캐릭터 정보를 성공적으로 불러왔습니다. (\(count)개)"
                case .failure(let error):
                    alertMessage = "오류가 발생했습니다: \(error.localizedDescription)"
                }
                
                showAlert = true
            }
        }
    }
}

// 통계 섹션 분리
struct StatisticsSection: View {
    let characters: [CharacterModel]
    let maxGoldEarners: Int
    let goldEarnerCount: Int
    
    var body: some View {
        Section(header: Text("통계"), footer: Text("골드 획득 캐릭터는 최대 \(maxGoldEarners)개까지 지정할 수 있습니다.")) {
            HStack {
                Text("전체 캐릭터")
                Spacer()
                Text("\(characters.count)개")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("표시 중인 캐릭터")
                Spacer()
                Text("\(characters.filter { !$0.isHidden }.count)개")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("골드 획득 캐릭터")
                Spacer()
                Text("\(goldEarnerCount)/\(maxGoldEarners)")
                    .foregroundColor(goldEarnerCount == maxGoldEarners ? .orange : .secondary)
            }
        }
    }
}
