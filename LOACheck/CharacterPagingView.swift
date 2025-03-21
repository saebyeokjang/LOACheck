//
//  CharacterPagingView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/20/25.
//

import SwiftUI
import SwiftData

struct CharacterPagingView: View {
    @Query var characters: [CharacterModel]
    
    init() {
        var descriptor = FetchDescriptor<CharacterModel>(predicate: #Predicate<CharacterModel> { !$0.isHidden })
        descriptor.sortBy = [SortDescriptor(\CharacterModel.level, order: .reverse)]
        _characters = Query(descriptor)
    }
    
    var body: some View {
        VStack {
            if characters.isEmpty {
                EmptyCharactersView()
            } else {
                TabView {
                    ForEach(characters) { character in
                        CharacterDetailView(character: character)
                            .padding(.horizontal)
                    }
                }
                .tabViewStyle(PageTabViewStyle())
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            }
        }
    }
}

struct EmptyCharactersView: View {
    @State private var isShowingSettings = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("표시할 캐릭터가 없습니다")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("API 키를 등록하여 캐릭터를 불러오거나\n숨김 처리된 캐릭터를 확인해보세요.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
            
            Button(action: {
                isShowingSettings = true
            }) {
                Text("설정으로 이동")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .navigationDestination(isPresented: $isShowingSettings) {
            SettingsView()
        }
    }
}

struct CharacterDetailView: View {
    var character: CharacterModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 캐릭터 정보 헤더
                CharacterHeaderView(character: character)
                
                // 일일 숙제 섹션
                if let dailyTasks = character.dailyTasks, !dailyTasks.isEmpty {
                    DailyTasksView(tasks: dailyTasks)
                }
                
                // 주간 레이드 섹션
                WeeklyRaidsView(character: character)
                
                Spacer()
            }
            .padding(.bottom, 20)
        }
    }
}

// 캐릭터 헤더 뷰 추가
struct CharacterHeaderView: View {
    var character: CharacterModel
    
    var body: some View {
        VStack(spacing: 12) {
            // 캐릭터 이름 및 정보
            Text(character.name)
                .font(.title)
                .fontWeight(.bold)
            
            Text("\(character.server) • \(character.characterClass)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("아이템 레벨: \(String(format: "%.2f", character.level))")
                .font(.headline)
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            
            // 골드 획득 캐릭터 표시
            if character.isGoldEarner {
                Text("골드 획득 캐릭터")
                    .font(.caption)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.yellow.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
