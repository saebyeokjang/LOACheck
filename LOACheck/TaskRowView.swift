//
//  TaskRowView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/21/25.
//

import SwiftUI
import SwiftData

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
            
            // 시간 정보 제거
        }
        .padding(.vertical, 4)
    }
}

struct DailyTasksView: View {
    var tasks: [DailyTask]
    
    private var sortedTasks: [DailyTask] {
        tasks.sorted { task1, task2 in
            let order: [DailyTask.TaskType] = [.eponaQuest, .chaosGate, .guardianRaid]
            let index1 = order.firstIndex(of: task1.type) ?? Int.max
            let index2 = order.firstIndex(of: task2.type) ?? Int.max
            return index1 < index2
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("일일 숙제")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            Divider()
            
            ForEach(sortedTasks) { task in
                TaskRowView(task: task)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
