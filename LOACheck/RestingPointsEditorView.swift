//
//  RestingPointsEditorView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/24/25.
//

import SwiftUI
import SwiftData

struct RestingPointsEditorView: View {
    @Bindable var task: DailyTask
    @Environment(\.dismiss) private var dismiss
    @State private var editedPoints: Int
    
    // 편집 가능한 최소/최대 값
    private let minPoints = 0
    private var maxPoints: Int { task.type.maxRestingPoints }
    
    // slider step 값
    private var stepValue: Int {
        switch task.type {
        case .eponaQuest: return 10
        case .chaosGate: return 20
        case .guardianRaid: return 10
        }
    }
    
    init(task: DailyTask) {
        self.task = task
        // 초기값 설정
        _editedPoints = State(initialValue: task.restingPoints)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // 컨텐츠 종류 표시
                VStack(spacing: 8) {
                    Text(task.type.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("휴식보너스 편집")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                // 포인트 정보
                VStack(spacing: 20) {
                    // 슬라이더 및 수치 표시
                    VStack(spacing: 8) {
                        HStack {
                            Text("현재 포인트:")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("\(editedPoints)")
                                .font(.headline)
                                .foregroundColor(.blue)
                                .frame(width: 60, alignment: .trailing)
                        }
                        
                        // 슬라이더
                        Slider(
                            value: Binding<Double>(
                                get: { Double(editedPoints) },
                                set: { editedPoints = Int($0) - Int($0) % stepValue }
                            ),
                            in: Double(minPoints)...Double(maxPoints),
                            step: Double(stepValue)
                        )
                        .accentColor(.blue)
                    }
                    
                    // 전체 게이지 표시
                    VStack(spacing: 8) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // 배경
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 20)
                                
                                // 채워진 부분
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(getBarColor())
                                    .frame(width: calculateWidth(geometry.size.width), height: 20)
                                
                                // 퍼센트 텍스트
                                Text("\(Int(Double(editedPoints) / Double(maxPoints) * 100))%")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .frame(height: 20)
                    }
                    
                    // 버튼 그룹
                    HStack(spacing: 20) {
                        // 0으로 초기화
                        Button(action: {
                            editedPoints = 0
                        }) {
                            Text("0으로 설정")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                        
                        // 절반으로 설정
                        Button(action: {
                            let half = (maxPoints / 2) / stepValue * stepValue
                            editedPoints = half
                        }) {
                            Text("절반으로 설정")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                        }
                        
                        // 최대로 설정
                        Button(action: {
                            editedPoints = maxPoints
                        }) {
                            Text("최대로 설정")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                
                // 컨텐츠 정보
                VStack(alignment: .leading, spacing: 8) {
                    Text("휴식보너스 정보")
                        .font(.headline)
                    
                    Divider()
                    
                    let info = getTaskInfo()
                    
                    InfoRow(
                        label: "최대 포인트",
                        value: "\(maxPoints)"
                    )
                    
                    InfoRow(
                        label: "미완료 시 적립",
                        value: "\(info.incompletePoints)포인트" + (task.type == .eponaQuest ? " (회당)" : "")
                    )
                    
                    InfoRow(
                        label: "컨텐츠 완료 시 소모",
                        value: "\(info.completionPoints)포인트" + (task.type == .eponaQuest ? " (회당)" : "")
                    )
                    
                    InfoRow(
                        label: "최대 완료 횟수",
                        value: "\(task.type.maxCompletionCount)회"
                    )
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        // 수정된 포인트 저장
                        task.restingPoints = editedPoints
                        dismiss()
                    }
                }
            }
        }
    }
    
    // 휴식보너스 정보 반환
    private func getTaskInfo() -> (incompletePoints: Int, completionPoints: Int) {
        switch task.type {
        case .eponaQuest:
            return (10, 20)
        case .chaosGate:
            return (20, 40)
        case .guardianRaid:
            return (10, 20)
        }
    }
    
    // 채워진 너비 계산
    private func calculateWidth(_ totalWidth: CGFloat) -> CGFloat {
        let percentage = CGFloat(editedPoints) / CGFloat(maxPoints)
        return totalWidth * min(percentage, 1.0)
    }
    
    // 포인트 양에 따른 색상 변경
    private func getBarColor() -> Color {
        let percentage = Double(editedPoints) / Double(maxPoints)
        switch percentage {
        case 0..<0.25: return .blue
        case 0.25..<0.5: return .teal
        case 0.5..<0.75: return .green
        case 0.75...1.0: return .orange
        default: return .blue
        }
    }
}

// 정보 행 컴포넌트
struct InfoRow: View {
    var label: String
    var value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
}
