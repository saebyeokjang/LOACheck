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
    @State private var showRestingEditor: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 작업 제목과 완료 상태
            HStack {
                // 체크박스 - 모든 작업 타입에 대해 하나의 체크박스 사용
                Button(action: {
                    toggleTask()
                }) {
                    ZStack {
                        Circle()
                            .strokeBorder(getCheckColor(), lineWidth: 1.5)
                            .background(Circle().fill(getCheckFillColor()))
                            .frame(width: 30, height: 30)
                        
                        // 에포나 의뢰는 숫자 표시, 나머지는 체크 표시
                        if task.type == .eponaQuest {
                            if task.completionCount > 0 {
                                Text("\(task.completionCount)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(getCheckColor())
                            }
                        } else if task.completionCount > 0 {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(getCheckColor())
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // 작업 이름
                Text(task.type.rawValue)
                    .font(.headline)
                    .foregroundColor(task.completionCount == task.type.maxCompletionCount ? .secondary : .primary)
                
                // 에포나 의뢰의 경우 완료 횟수 표시
                if task.type == .eponaQuest {
                    Text("(\(task.completionCount)/\(task.type.maxCompletionCount))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 휴식보너스 아이콘 (포인트가 소모될 수 있는 경우)
                if task.restingPoints >= task.type.pointsPerCompletion && task.completionCount < task.type.maxCompletionCount {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
            }
            
            // 휴식보너스 포인트 바
            HStack {
                // 휴식보너스 포인트 아이콘
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                
                // 프로그레스 바
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 배경
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                        
                        // 채워진 부분
                        RoundedRectangle(cornerRadius: 2)
                            .fill(getBarColor())
                            .frame(width: calculateWidth(geometry.size.width), height: 6)
                    }
                }
                .frame(height: 6)
                
                // 포인트 텍스트 및 편집 버튼
                HStack(spacing: 4) {
                    Text("\(task.restingPoints)/\(task.type.maxRestingPoints)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    // 편집 버튼
                    Button(action: {
                        showRestingEditor = true
                    }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showRestingEditor) {
            RestingPointsEditorView(task: task)
        }
    }
    
    // 체크 색상 결정
    private func getCheckColor() -> Color {
        if task.completionCount == task.type.maxCompletionCount {
            return .green
        } else if task.completionCount > 0 {
            return .blue
        } else {
            return .gray
        }
    }
    
    // 체크 배경색 결정
    private func getCheckFillColor() -> Color {
        if task.completionCount == task.type.maxCompletionCount {
            return .green.opacity(0.1)
        } else if task.completionCount > 0 {
            return .blue.opacity(0.1)
        } else {
            return .clear
        }
    }
    
    // 작업 토글
    private func toggleTask() {
        let currentCount = task.completionCount
        let maxCount = task.type.maxCompletionCount
        
        // 에포나 의뢰는 0→1→2→3→0으로 순환
        if task.type == .eponaQuest {
            if currentCount >= maxCount {
                // 최대 완료 상태에서 미완료로 돌아감
                // 모든 단계의 휴게 포인트 반환
                for i in 0..<currentCount {
                    task.returnRestingPoints(forStep: i)
                }
                task.completionCount = 0
            } else {
                // 다음 단계로 완료 상태 증가
                let usedRestingPoints = task.consumeRestingPoints()
                
                task.completionCount += 1
                task.lastCompletedAt = Date()
            }
        } else {
            // 일반 작업은 토글 (0→1→0)
            if currentCount == 0 {
                // 완료로 변경
                let usedRestingPoints = task.consumeRestingPoints()
                
                task.completionCount = task.type.maxCompletionCount
                task.lastCompletedAt = Date()
            } else {
                // 미완료로 변경하면서 사용했던 휴게 포인트 반환
                task.returnRestingPoints(forStep: 0)
                
                task.completionCount = 0
                task.lastCompletedAt = nil
            }
        }
    }
    
    // 채워진 너비 계산
    private func calculateWidth(_ totalWidth: CGFloat) -> CGFloat {
        let percentage = CGFloat(task.restingPoints) / CGFloat(task.type.maxRestingPoints)
        return totalWidth * min(percentage, 1.0)
    }
    
    // 포인트 양에 따른 색상 변경
    private func getBarColor() -> Color {
        let percentage = Double(task.restingPoints) / Double(task.type.maxRestingPoints)
        switch percentage {
        case 0..<0.25: return .blue
        case 0.25..<0.5: return .teal
        case 0.5..<0.75: return .green
        case 0.75...1.0: return .orange
        default: return .blue
        }
    }
}

struct DailyTasksView: View {
    var tasks: [DailyTask]
    @State private var showRestingPointsInfo = false
    
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
                
                // 휴게 포인트 설명 버튼
                Button(action: {
                    showRestingPointsInfo = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                        Text("휴식보너스")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }
            
            Divider()
            
            ForEach(sortedTasks) { task in
                TaskRowView(task: task)
                
                if task != sortedTasks.last {
                    Divider()
                        .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .alert(isPresented: $showRestingPointsInfo) {
            Alert(
                title: Text("휴식보너스 시스템"),
                message: Text("컨텐츠 미완료 시 다음 날 오전 6시에 휴식보너스가 충전됩니다\n\n" +
                             "• 에포나 의뢰: 미완료 1회당 10포인트\n클리어 시 1회당 20포인트 소모\n\n" +
                             "• 쿠르잔 전선: 미완료 시 20포인트\n클리어 시 40포인트 소모\n\n" +
                             "• 가디언 토벌: 미완료 시 10포인트\n클리어 시 20포인트 소모\n\n" +
                             "휴식보너스 사용 시\n추가 보상을 획득할 수 있습니다"),
                dismissButton: .default(Text("확인"))
            )
        }
    }
}
