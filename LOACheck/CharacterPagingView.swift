//
//  CharacterPagingView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/20/25.
//

import SwiftUI
import SwiftData

struct CharacterPagingView: View {
    @Environment(\.modelContext) private var modelContext
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
                if let weeklyRaids = character.weeklyRaids, !weeklyRaids.isEmpty {
                    WeeklyRaidsView(raids: weeklyRaids, character: character)
                }
                
                Spacer()
            }
            .padding(.bottom, 20)
        }
    }
}

struct CharacterHeaderView: View {
    var character: CharacterModel
    
    var body: some View {
        VStack(spacing: 12) {
            // 캐릭터 이미지
            if let imageURL = character.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 120, height: 120)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                    case .failure:
                        Image(systemName: "person.fill")
                            .font(.system(size: 60))
                            .frame(width: 120, height: 120)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Circle())
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 60))
                    .frame(width: 120, height: 120)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Circle())
            }
            
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

struct DailyTasksView: View {
    var tasks: [DailyTask]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("일일 숙제")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("매일 06:00 초기화")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            ForEach(tasks) { task in
                TaskRowView(task: task)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct TaskRowView: View {
    @Bindable var task: DailyTask
    
    var body: some View {
        HStack {
            Button(action: {
                task.isCompleted.toggle()
                if task.isCompleted {
                    task.lastCompletedAt = Date()
                }
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(task.isCompleted ? .green : .gray)
            }
            
            Text(task.type.rawValue)
                .strikethrough(task.isCompleted)
                .foregroundColor(task.isCompleted ? .secondary : .primary)
            
            Spacer()
            
            if let lastCompletedAt = task.lastCompletedAt {
                Text(lastCompletedAt, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct WeeklyRaidsView: View {
    var raids: [WeeklyRaid]
    var character: CharacterModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("주간 레이드")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("매주 수요일 06:00 초기화")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            if raids.isEmpty {
                Text("참여 가능한 레이드가 없습니다")
                    .foregroundColor(.secondary)
                    .padding(.vertical)
            } else {
                ForEach(raids) { raid in
                    RaidRowView(raid: raid, isGoldEarner: character.isGoldEarner)
                }
                
                // 골드 획득 캐릭터가 아닌 경우 알림 표시
                if !character.isGoldEarner && !raids.isEmpty {
                    Text("골드 획득 캐릭터로 지정되지 않아 골드를 획득할 수 없습니다")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct RaidRowView: View {
    @Bindable var raid: WeeklyRaid
    var isGoldEarner: Bool
    
    var body: some View {
        HStack {
            Button(action: {
                raid.isCompleted.toggle()
                if raid.isCompleted {
                    raid.lastCompletedAt = Date()
                }
            }) {
                Image(systemName: raid.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(raid.isCompleted ? .green : .gray)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(raid.name) (\(raid.difficulty))")
                    .strikethrough(raid.isCompleted)
                    .foregroundColor(raid.isCompleted ? .secondary : .primary)
                
                if isGoldEarner {
                    Text("\(raid.goldReward) 골드")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            if let lastCompletedAt = raid.lastCompletedAt {
                Text(lastCompletedAt, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
