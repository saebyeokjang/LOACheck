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
   @State private var manualCharacters: [CharacterModel] = []
   @State private var searchText = ""
   @State private var isRefreshing = false
   @State private var showAlert = false
   @State private var alertMessage = ""
   
   // 골드 획득 캐릭터 수 제한
   private let maxGoldEarners = 256
   
   var filteredCharacters: [CharacterModel] {
       if searchText.isEmpty {
           return manualCharacters
       } else {
           return manualCharacters.filter { $0.name.localizedCaseInsensitiveContains(searchText) ||
               $0.characterClass.localizedCaseInsensitiveContains(searchText) ||
               $0.server.localizedCaseInsensitiveContains(searchText) }
       }
   }
   
   var body: some View {
       NavigationStack {
           List {
               Section() {
                   ForEach(filteredCharacters) { character in
                       CharacterRow(character: character, maxGoldEarners: maxGoldEarners, goldEarnerCount: goldEarnerCount)
                   }
                   .onDelete(perform: deleteCharacters)
               }
               
               StatisticsSection(
                   characters: manualCharacters,
                   maxGoldEarners: maxGoldEarners,
                   goldEarnerCount: goldEarnerCount
               )
           }
           .navigationTitle("캐릭터 관리")
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
           .onAppear {
               loadCharacters()
           }
           .onChange(of: searchText) { oldValue, newValue in
               // 검색어 변경 시 처리할 내용이 있다면 여기 추가
           }
           .searchable(text: $searchText, prompt: "캐릭터 검색")
       }
   }
   
   // 캐릭터 데이터 수동 로딩
   private func loadCharacters() {
       do {
           var descriptor = FetchDescriptor<CharacterModel>()
           descriptor.sortBy = [SortDescriptor(\CharacterModel.level, order: .reverse)]
           manualCharacters = try modelContext.fetch(descriptor)
       } catch {
           print("캐릭터 로드 오류: \(error)")
           alertMessage = "캐릭터 로드 중 오류가 발생했습니다: \(error.localizedDescription)"
           showAlert = true
       }
   }
   
   // 골드 획득 캐릭터 수
   private var goldEarnerCount: Int {
       manualCharacters.filter { $0.isGoldEarner }.count
   }
   
   // 캐릭터 삭제
   private func deleteCharacters(at offsets: IndexSet) {
       for index in offsets {
           modelContext.delete(filteredCharacters[index])
       }
       
       // 변경사항 저장 및 동기화 표시
       try? modelContext.save()
       DataSyncManager.shared.markLocalChanges()
       
       // 캐릭터 리스트 다시 로드
       loadCharacters()
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
                   // 캐릭터 리스트 다시 로드
                   loadCharacters()
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
       Section(header: Text("통계")) {
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
               Text("\(goldEarnerCount)개")
                   .foregroundColor(.secondary)
           }
       }
   }
}
