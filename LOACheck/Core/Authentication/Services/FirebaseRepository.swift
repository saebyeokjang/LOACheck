//
//  FirebaseRepository.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/8/25.
//

import Foundation
import FirebaseFirestore
import SwiftData

/// Firebase와 상호작용하는 데이터 저장소
class FirebaseRepository {
    static let shared = FirebaseRepository()
    
    private let db = Firestore.firestore()
    private var userDataListener: ListenerRegistration?
    
    private init() {}
    
    // MARK: - 캐릭터 데이터 관련
    
    /// 사용자의 모든 캐릭터 저장
    func saveCharacters(_ characters: [CharacterModel]) async throws {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw FirebaseError.notAuthenticated
        }
        
        let batch = db.batch()
        
        // 캐릭터 컬렉션 참조
        let charactersRef = db.collection("users").document(userId).collection("characters")
        
        // 기존 모든 캐릭터 문서 삭제 요청 추가
        try await deleteAllCharacters(userId)
        
        // 새 캐릭터 추가
        for character in characters {
            let docRef = charactersRef.document(character.name)
            
            // 일일 숙제 및 레이드 데이터를 포함한 캐릭터 데이터 생성
            var characterData: [String: Any] = [
                "name": character.name,
                "server": character.server,
                "characterClass": character.characterClass,
                "level": character.level,
                "isHidden": character.isHidden,
                "isGoldEarner": character.isGoldEarner,
                "lastUpdated": character.lastUpdated,
                "additionalGoldMap": character.additionalGoldMap
            ]
            
            if let imageURL = character.imageURL {
                characterData["imageURL"] = imageURL
            }
            
            // 일일 숙제 추가
            var dailyTasksData: [[String: Any]] = []
            if let dailyTasks = character.dailyTasks {
                for task in dailyTasks {
                    let taskData: [String: Any] = [
                        "type": task.type.rawValue,
                        "completionCount": task.completionCount,
                        "restingPoints": task.restingPoints,
                        "usedRestingPoint1": task.usedRestingPoint1,
                        "usedRestingPoint2": task.usedRestingPoint2,
                        "usedRestingPoint3": task.usedRestingPoint3
                    ]
                    dailyTasksData.append(taskData)
                }
            }
            characterData["dailyTasks"] = dailyTasksData
            
            // 레이드 관문 추가
            var raidGatesData: [[String: Any]] = []
            if let raidGates = character.raidGates {
                for gate in raidGates {
                    let gateData: [String: Any] = [
                        "raid": gate.raid,
                        "gate": gate.gate,
                        "difficulty": gate.difficulty,
                        "goldReward": gate.goldReward,
                        "isCompleted": gate.isCompleted,
                        "additionalGold": gate.additionalGold
                    ]
                    raidGatesData.append(gateData)
                }
            }
            characterData["raidGates"] = raidGatesData
            
            // 배치에 쓰기 작업 추가
            batch.setData(characterData, forDocument: docRef)
        }
        
        // 배치 커밋
        try await batch.commit()
    }
    
    /// 모든 캐릭터 삭제
    private func deleteAllCharacters(_ userId: String) async throws {
        let charactersRef = db.collection("users").document(userId).collection("characters")
        let snapshot = try await charactersRef.getDocuments()
        
        if snapshot.documents.isEmpty {
            return
        }
        
        let batch = db.batch()
        snapshot.documents.forEach { doc in
            batch.deleteDocument(doc.reference)
        }
        
        try await batch.commit()
    }
    
    /// 사용자의 모든 캐릭터 가져오기
    func fetchCharacters() async throws -> [CharacterModel] {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw FirebaseError.notAuthenticated
        }
        
        let charactersRef = db.collection("users").document(userId).collection("characters")
        let snapshot = try await charactersRef.getDocuments()
        
        var characters: [CharacterModel] = []
        
        for document in snapshot.documents {
            let data = document.data()
            
            // 기본 캐릭터 정보 추출
            let name = data["name"] as? String ?? ""
            let server = data["server"] as? String ?? ""
            let characterClass = data["characterClass"] as? String ?? ""
            let level = data["level"] as? Double ?? 0.0
            let imageURL = data["imageURL"] as? String
            let isHidden = data["isHidden"] as? Bool ?? false
            let isGoldEarner = data["isGoldEarner"] as? Bool ?? false
            
            // 캐릭터 모델 생성
            let character = CharacterModel(
                name: name,
                server: server,
                characterClass: characterClass,
                level: level,
                imageURL: imageURL,
                isHidden: isHidden,
                isGoldEarner: isGoldEarner
            )
            
            // 추가 골드 맵 설정
            if let additionalGoldMap = data["additionalGoldMap"] as? String {
                character.additionalGoldMap = additionalGoldMap
            }
            
            // 일일 숙제 데이터 설정
            if let dailyTasksData = data["dailyTasks"] as? [[String: Any]] {
                var dailyTasks: [DailyTask] = []
                
                for taskData in dailyTasksData {
                    if let typeString = taskData["type"] as? String,
                       let type = DailyTask.TaskType(rawValue: typeString) {
                        
                        let completionCount = taskData["completionCount"] as? Int ?? 0
                        let restingPoints = taskData["restingPoints"] as? Int ?? 0
                        
                        let task = DailyTask(type: type, completionCount: completionCount, restingPoints: restingPoints)
                        
                        // 휴식 포인트 사용 정보 설정
                        task.usedRestingPoint1 = taskData["usedRestingPoint1"] as? Int ?? 0
                        task.usedRestingPoint2 = taskData["usedRestingPoint2"] as? Int ?? 0
                        task.usedRestingPoint3 = taskData["usedRestingPoint3"] as? Int ?? 0
                        
                        dailyTasks.append(task)
                    }
                }
                
                character.dailyTasks = dailyTasks
            }
            
            // 레이드 관문 데이터 설정
            if let raidGatesData = data["raidGates"] as? [[String: Any]] {
                var raidGates: [RaidGate] = []
                
                for gateData in raidGatesData {
                    if let raid = gateData["raid"] as? String,
                       let gate = gateData["gate"] as? Int,
                       let difficulty = gateData["difficulty"] as? String,
                       let goldReward = gateData["goldReward"] as? Int {
                        
                        let isCompleted = gateData["isCompleted"] as? Bool ?? false
                        
                        let raidGate = RaidGate(
                            raid: raid,
                            gate: gate,
                            difficulty: difficulty,
                            goldReward: goldReward,
                            isCompleted: isCompleted
                        )
                        
                        if let additionalGold = gateData["additionalGold"] as? Int {
                            raidGate.additionalGold = additionalGold
                        }
                        
                        raidGates.append(raidGate)
                    }
                }
                
                character.raidGates = raidGates
            }
            
            characters.append(character)
        }
        
        return characters
    }
    
    // MARK: - 친구 관련
    
    // 캐릭터 이름으로 사용자 검색 (기본 메소드)
    func searchUserByCharacterName(_ characterName: String) async throws -> User? {
        print("📱 캐릭터 검색 시작: \(characterName)")
        
        let db = Firestore.firestore()
        let characterNamesRef = db.collection("characterNames").document(characterName)
        
        let document = try await characterNamesRef.getDocument()
        
        guard document.exists, let data = document.data(),
              let userId = data["userId"] as? String else {
            print("❌ 캐릭터 검색 실패: 캐릭터 정보 없음")
            return nil
        }
        
        print("✅ 캐릭터 검색 성공: \(characterName), 사용자 ID: \(userId)")
        
        // 사용자 정보 가져오기
        let userRef = db.collection("users").document(userId)
        let userDoc = try await userRef.getDocument()
        
        if let userData = userDoc.data(),
           let displayName = userData["displayName"] as? String,
           let email = userData["email"] as? String {
            print("✅ 사용자 정보 조회 성공: \(displayName)")
            return User(id: userId, displayName: displayName, email: email)
        }
        
        print("❌ 사용자 정보 조회 실패: \(userId)")
        return nil
    }
    
    // 캐릭터 이름으로 사용자 및 캐릭터 상세 정보 검색 (새 메소드)
    func searchUserAndCharacterDetails(_ characterName: String) async throws -> (User?, CharacterModel?) {
        print("📱 캐릭터 및 상세 정보 검색 시작: \(characterName)")
        
        let db = Firestore.firestore()
        let characterNamesRef = db.collection("characterNames").document(characterName)
        
        let document = try await characterNamesRef.getDocument()
        
        guard document.exists, let data = document.data(),
              let userId = data["userId"] as? String else {
            print("❌ 캐릭터 검색 실패: 캐릭터 정보 없음")
            return (nil, nil)
        }
        
        // 캐릭터 정보 추출
        let server = data["server"] as? String ?? ""
        let characterClass = data["characterClass"] as? String ?? ""
        let level = data["level"] as? Double ?? 0.0
        
        // 캐릭터 모델 생성
        let characterModel = CharacterModel(
            name: characterName,
            server: server,
            characterClass: characterClass,
            level: level
        )
        
        print("✅ 캐릭터 검색 성공: \(characterName), 사용자 ID: \(userId)")
        
        // 사용자 정보 가져오기
        let userRef = db.collection("users").document(userId)
        let userDoc = try await userRef.getDocument()
        
        if let userData = userDoc.data(),
           let displayName = userData["displayName"] as? String,
           let email = userData["email"] as? String {
            print("✅ 사용자 정보 조회 성공: \(displayName)")
            let user = User(id: userId, displayName: displayName, email: email)
            return (user, characterModel)
        }
        
        print("❌ 사용자 정보 조회 실패: \(userId)")
        return (nil, characterModel)  // 사용자 정보는 없지만 캐릭터 정보는 반환
    }
    
    // 친구 요청 보내기
    func sendFriendRequest(to characterName: String) async throws {
        guard let currentUserId = AuthManager.shared.currentUser?.id else {
            throw FirebaseError.notAuthenticated
        }
        
        let currentUserName = AuthManager.shared.displayName
        
        // 1. 캐릭터 이름으로 사용자 ID 찾기
        let targetUser = try await searchUserByCharacterName(characterName)
        guard let targetUserId = targetUser?.id else {
            throw FirebaseError.documentNotFound
        }
        
        // 자기 자신에게 요청 방지
        if targetUserId == currentUserId {
            throw FirebaseError.dataError
        }
        
        let db = Firestore.firestore()
        let batch = db.batch()
        
        // 친구 요청 참조
        let receivedRequestRef = db.collection("users")
            .document(targetUserId)
            .collection("friendRequests")
            .document(currentUserId)
        
        let sentRequestRef = db.collection("users")
            .document(currentUserId)
            .collection("sentRequests")
            .document(targetUserId)
        
        // 요청 데이터 구성
        let requestData: [String: Any] = [
            "fromUserId": currentUserId,
            "fromUserName": currentUserName,
            "toUserId": targetUserId,
            "status": "pending",
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        // 이미 친구인지 확인
        let friendRef = db.collection("users")
            .document(currentUserId)
            .collection("friends")
            .document(targetUserId)
        
        let friendDoc = try await friendRef.getDocument()
        
        if friendDoc.exists {
            throw FirebaseError.dataError
        }
        
        // 이미 요청한 적 있는지 확인
        let sentRequestDoc = try await sentRequestRef.getDocument()

        if sentRequestDoc.exists {
            let data: [String: Any]? = sentRequestDoc.data()
            if let status = data?["status"] as? String, status == "pending" {
                throw FirebaseError.dataError
            }
        }
        
        // 배치에 쓰기 작업 추가
        batch.setData(requestData, forDocument: receivedRequestRef)
        batch.setData(requestData, forDocument: sentRequestRef)
        
        // 배치 커밋
        try await batch.commit()
    }
    
    /// 친구 요청 수락
    func acceptFriendRequest(from userId: String) async throws {
        guard let currentUserId = AuthManager.shared.currentUser?.id else {
            throw FirebaseError.notAuthenticated
        }
        
        // 트랜잭션 시작
        try await db.runTransaction { transaction, errorPointer in
            // 요청 문서 참조
            let requestRef = self.db.collection("users").document(currentUserId).collection("friendRequests").document(userId)
            
            // 상대방 정보 가져오기
            guard let requestDoc = try? transaction.getDocument(requestRef),
                  let requestData = requestDoc.data(),
                  let fromUserName = requestData["fromUserName"] as? String else {
                return nil
            }
            
            // 내 정보
            let currentUserName = AuthManager.shared.displayName
            
            // 내 친구 목록에 추가
            let myFriendRef = self.db.collection("users").document(currentUserId).collection("friends").document(userId)
            transaction.setData([
                "userId": userId,
                "displayName": fromUserName,
                "timestamp": FieldValue.serverTimestamp()
            ], forDocument: myFriendRef)
            
            // 상대방 친구 목록에 추가
            let theirFriendRef = self.db.collection("users").document(userId).collection("friends").document(currentUserId)
            transaction.setData([
                "userId": currentUserId,
                "displayName": currentUserName,
                "timestamp": FieldValue.serverTimestamp()
            ], forDocument: theirFriendRef)
            
            // 요청 상태 업데이트
            transaction.updateData(["status": "accepted"], forDocument: requestRef)
            
            // 상대방의 발신 요청 상태 업데이트
            let sentRequestRef = self.db.collection("users").document(userId).collection("sentRequests").document(currentUserId)
            transaction.updateData(["status": "accepted"], forDocument: sentRequestRef)
            
            return nil
        }
    }
    
    /// 친구 요청 거절
    func rejectFriendRequest(from userId: String) async throws {
        guard let currentUserId = AuthManager.shared.currentUser?.id else {
            throw FirebaseError.notAuthenticated
        }
        
        // 내 수신 요청에서 제거
        try await db.collection("users").document(currentUserId).collection("friendRequests").document(userId).delete()
        
        // 상대방의 발신 요청 상태 업데이트
        let sentRequestRef = db.collection("users").document(userId).collection("sentRequests").document(currentUserId)
        try await sentRequestRef.updateData(["status": "rejected"])
    }
    
    /// 친구 삭제
    func removeFriend(userId: String) async throws {
        guard let currentUserId = AuthManager.shared.currentUser?.id else {
            throw FirebaseError.notAuthenticated
        }
        
        // 내 친구 목록에서 삭제
        try await db.collection("users").document(currentUserId).collection("friends").document(userId).delete()
        
        // 상대방 친구 목록에서도 삭제
        try await db.collection("users").document(userId).collection("friends").document(currentUserId).delete()
    }
    
    /// 친구 요청 목록 가져오기
    func fetchFriendRequests() async throws -> [FriendRequest] {
        guard let currentUserId = AuthManager.shared.currentUser?.id else {
            throw FirebaseError.notAuthenticated
        }
        
        let requestsRef = db.collection("users").document(currentUserId).collection("friendRequests")
        let snapshot = try await requestsRef.whereField("status", isEqualTo: "pending").getDocuments()
        
        return snapshot.documents.compactMap { doc -> FriendRequest? in
            let data = doc.data()
            
            guard let fromUserId = data["fromUserId"] as? String,
                  let fromUserName = data["fromUserName"] as? String else {
                return nil
            }
            
            return FriendRequest(
                id: doc.documentID,
                fromUserId: fromUserId,
                fromUserName: fromUserName,
                timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
    }
    
    /// 친구 목록 가져오기
    func fetchFriends() async throws -> [Friend] {
        guard let currentUserId = AuthManager.shared.currentUser?.id else {
            throw FirebaseError.notAuthenticated
        }
        
        let friendsRef = db.collection("users").document(currentUserId).collection("friends")
        let snapshot = try await friendsRef.getDocuments()
        
        return snapshot.documents.compactMap { doc -> Friend? in
            let data = doc.data()
            
            guard let userId = data["userId"] as? String,
                  let displayName = data["displayName"] as? String else {
                return nil
            }
            
            return Friend(
                id: doc.documentID,
                userId: userId,
                displayName: displayName,
                timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
    }
    
    /// 친구의 캐릭터 데이터 가져오기
    func fetchFriendCharacters(friendUserId: String) async throws -> [CharacterModel] {
        let charactersRef = db.collection("users").document(friendUserId).collection("characters")
        let snapshot = try await charactersRef.getDocuments()
        
        var characters: [CharacterModel] = []
        
        for document in snapshot.documents {
            let data = document.data()
            
            // 기본 캐릭터 정보 추출
            let name = data["name"] as? String ?? ""
            let server = data["server"] as? String ?? ""
            let characterClass = data["characterClass"] as? String ?? ""
            let level = data["level"] as? Double ?? 0.0
            let imageURL = data["imageURL"] as? String
            let isHidden = data["isHidden"] as? Bool ?? false
            let isGoldEarner = data["isGoldEarner"] as? Bool ?? false
            
            // 숨겨진 캐릭터는 제외
            if isHidden {
                continue
            }
            
            // 캐릭터 모델 생성
            let character = CharacterModel(
                name: name,
                server: server,
                characterClass: characterClass,
                level: level,
                imageURL: imageURL,
                isHidden: isHidden,
                isGoldEarner: isGoldEarner
            )
            
            // 일일 숙제 데이터 설정
            if let dailyTasksData = data["dailyTasks"] as? [[String: Any]] {
                var dailyTasks: [DailyTask] = []
                
                for taskData in dailyTasksData {
                    if let typeString = taskData["type"] as? String,
                       let type = DailyTask.TaskType(rawValue: typeString) {
                        
                        let completionCount = taskData["completionCount"] as? Int ?? 0
                        let restingPoints = taskData["restingPoints"] as? Int ?? 0
                        
                        let task = DailyTask(type: type, completionCount: completionCount, restingPoints: restingPoints)
                        dailyTasks.append(task)
                    }
                }
                
                character.dailyTasks = dailyTasks
            }
            
            // 레이드 관문 데이터 설정
            if let raidGatesData = data["raidGates"] as? [[String: Any]] {
                var raidGates: [RaidGate] = []
                
                for gateData in raidGatesData {
                    if let raid = gateData["raid"] as? String,
                       let gate = gateData["gate"] as? Int,
                       let difficulty = gateData["difficulty"] as? String,
                       let goldReward = gateData["goldReward"] as? Int {
                        
                        let isCompleted = gateData["isCompleted"] as? Bool ?? false
                        
                        let raidGate = RaidGate(
                            raid: raid,
                            gate: gate,
                            difficulty: difficulty,
                            goldReward: goldReward,
                            isCompleted: isCompleted
                        )
                        
                        raidGates.append(raidGate)
                    }
                }
                
                character.raidGates = raidGates
            }
            
            characters.append(character)
        }
        
        return characters
    }
    
    // 캐릭터 상세 정보 저장 메소드
    func storeCharacterDetails(characterName: String) async throws {
        // 사용자 인증 확인
        guard let userId = AuthManager.shared.currentUser?.id else {
            Logger.error("캐릭터 상세 정보 저장 실패: 인증되지 않은 사용자")
            throw FirebaseError.notAuthenticated
        }
        
        // DB 참조
        let db = Firestore.firestore()
        
        // SwiftData에서 캐릭터 정보 찾기
        if let modelContext = DataSyncManager.shared.modelContext {
            do {
                let descriptor = FetchDescriptor<CharacterModel>(
                    predicate: #Predicate<CharacterModel> { $0.name == characterName }
                )
                
                let characters = try modelContext.fetch(descriptor)
                
                if let character = characters.first {
                    // 캐릭터 정보가 있으면 상세 정보 저장
                    try await db.collection("characterNames").document(characterName).setData([
                        "userId": userId,
                        "server": character.server,
                        "characterClass": character.characterClass,
                        "level": character.level,
                        "timestamp": FieldValue.serverTimestamp()
                    ], merge: true)
                    
                    Logger.debug("캐릭터 '\(characterName)' 상세 정보 저장 완료")
                } else {
                    // 캐릭터 정보가 없으면 기본 정보만 저장
                    try await db.collection("characterNames").document(characterName).setData([
                        "userId": userId,
                        "timestamp": FieldValue.serverTimestamp()
                    ], merge: true)
                    
                    Logger.debug("캐릭터 '\(characterName)' 기본 정보만 저장 (캐릭터 정보 없음)")
                }
            } catch {
                Logger.error("캐릭터 정보 조회 중 오류 발생", error: error)
                throw error
            }
        } else {
            // ModelContext가 없는 경우
            Logger.error("ModelContext가 없어 캐릭터 정보를 찾을 수 없음")
            
            // 기본 정보만 저장
            try await db.collection("characterNames").document(characterName).setData([
                "userId": userId,
                "timestamp": FieldValue.serverTimestamp()
            ], merge: true)
        }
    }
    
    // MARK: - 사용자 데이터 관리
    
    /// 사용자 프로필 정보 저장
    func saveUserProfile() async throws {
        guard let user = AuthManager.shared.currentUser else {
            print("❌ saveUserProfile 실패: 인증된 사용자 없음")
            throw FirebaseError.notAuthenticated
        }
        
        print("✅ saveUserProfile 시도: \(user.id), \(user.displayName)")
        
        let userData: [String: Any] = [
            "displayName": user.displayName,
            "email": user.email ?? "",
            "lastActive": FieldValue.serverTimestamp()
        ]
        
        do {
            try await db.collection("users").document(user.id).setData(userData, merge: true)
            print("✅ 사용자 프로필 저장 성공: \(user.id)")
        } catch {
            print("❌ 사용자 프로필 저장 실패: \(error.localizedDescription)")
            throw error
        }
    }
    
    // 데이터 리스너 설정 및 해제
    func setupUserDataListener(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = AuthManager.shared.currentUser?.id else {
            completion(.failure(FirebaseError.notAuthenticated))
            return
        }
        
        // 기존 리스너가 있으면 제거
        userDataListener?.remove()
        
        userDataListener = db.collection("users").document(userId)
            .addSnapshotListener { documentSnapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard documentSnapshot?.exists == true else {
                    // 사용자 문서가 없는 경우 생성
                    Task {
                        do {
                            try await self.saveUserProfile()
                            completion(.success(()))
                        } catch {
                            completion(.failure(error))
                        }
                    }
                    return
                }
                
                completion(.success(()))
            }
    }
    
    func removeUserDataListener() {
        userDataListener?.remove()
        userDataListener = nil
    }
}

// Firebase 관련 오류 정의
enum FirebaseError: Error, LocalizedError {
    case notAuthenticated
    case documentNotFound
    case dataError
    case forbidden
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "로그인이 필요합니다."
        case .documentNotFound:
            return "해당 캐릭터를 찾을 수 없습니다."
        case .dataError:
            return "이미 친구이거나 요청 중인 사용자입니다."
        case .forbidden:
            return "요청 권한이 없습니다."
        case .networkError(let error):
            return "네트워크 오류: \(error.localizedDescription)"
        }
    }
}
