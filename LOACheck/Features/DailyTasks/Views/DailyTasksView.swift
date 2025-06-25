//
//  DailyTasksView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/21/25.
//

import SwiftUI

struct DailyTasksView: View {
    var tasks: [DailyTask]
    var character: CharacterModel
    var isActiveView: Bool = true
    
    @AppStorage("dailyTasksSectionExpanded") private var isSectionExpanded = true
    @State private var showRestingPointsInfo = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var sortedTasks: [DailyTask] {
        // 에포나 의뢰 제외하고 표시
        let filteredTasks = tasks.filter { $0.type != .eponaQuest }
        
        return filteredTasks.sorted { task1, task2 in
            let order: [DailyTask.TaskType] = [.chaosGate, .guardianRaid]
            let index1 = order.firstIndex(of: task1.type) ?? Int.max
            let index2 = order.firstIndex(of: task2.type) ?? Int.max
            return index1 < index2
        }
    }
    
    private var chaosContentName: String {
        return character.level >= 1640 ? "쿠르잔 전선" : "카오스 던전"
    }
    
    private var alertMessage: String {
        let message = """
        컨텐츠 미완료 시 다음 날 오전 6시에 휴식보너스가 충전됩니다
        
        • \(chaosContentName): 미완료 시 20포인트
        클리어 시 40포인트 소모
        
        • 가디언 토벌: 미완료 시 10포인트
        클리어 시 20포인트 소모
        
        휴식보너스 사용 시
        추가 보상을 획득할 수 있습니다
        """
        return message
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("일일 숙제")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color.textPrimary)
                
                Spacer()
                
                Button(action: {
                    showRestingPointsInfo = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                        Text("휴식보너스")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .padding(8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(DefaultButtonStyle())
                
                Button(action: {
                    isSectionExpanded.toggle()
                }) {
                    Image(systemName: isSectionExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                        .frame(width: 24, height: 24)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(DefaultButtonStyle())
            }
            
            if isSectionExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .background(Color.dividerColor)
                    
                    LazyVStack(spacing: 8) {
                        ForEach(sortedTasks) { task in
                            TaskRowView(task: task, character: character)
                            
                            if task != sortedTasks.last {
                                Divider()
                                    .background(Color.dividerColor)
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 5, x: 0, y: 2)
        .alert(isPresented: $showRestingPointsInfo) {
            Alert(
                title: Text("휴식보너스 시스템"),
                message: Text(alertMessage),
                dismissButton: .default(Text("확인"))
            )
        }
        .allowsHitTesting(isActiveView)
    }
}
