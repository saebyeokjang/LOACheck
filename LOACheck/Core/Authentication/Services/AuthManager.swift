//
//  AuthManager.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/8/25.
//

import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn

/// Firebase 인증을 관리하는 클래스
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    // 인증 상태를 관찰할 수 있는 Published 속성
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: User?
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    // 최초 로그인 여부 (데이터 마이그레이션 용도)
    @Published var isFirstTimeLogin: Bool = false
    
    // 대표 캐릭터 이름 저장용 속성
    @Published var representativeCharacter: String = ""
    
    private var authStateHandler: AuthStateDidChangeListenerHandle?
    
    private init() {
        // 대표 캐릭터 이름 로드 - 기본 값은 전역 설정에서 가져옴
        loadRepresentativeCharacter()
        
        setupFirebase()
        setupAuthStateListener()
    }
    
    // Firebase 초기화
    private func setupFirebase() {
        // 앱이 이미 설정되었는지 확인 (중복 초기화 방지)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }
    
    // 대표 캐릭터 로드 함수 추가
    private func loadRepresentativeCharacter() {
        // 현재 로그인된 사용자가 있다면 사용자별 설정 우선
        if let currentUserUid = Auth.auth().currentUser?.uid {
            let userRepChar = UserDefaults.standard.string(forKey: "representativeCharacter_\(currentUserUid)") ?? ""
            if !userRepChar.isEmpty {
                self.representativeCharacter = userRepChar
                return
            }
        }
        
        // 사용자별 설정이 없다면 전역 설정 사용
        self.representativeCharacter = UserDefaults.standard.string(forKey: "representativeCharacter") ?? ""
    }
    
    // 인증 상태 변경 리스너 설정
    private func setupAuthStateListener() {
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] (_, firebaseUser) in
            guard let self = self else { return }
            
            Task {
                await MainActor.run {
                    if let firebaseUser = firebaseUser {
                        self.currentUser = User(from: firebaseUser)
                        self.isLoggedIn = true
                        
                        // 사용자별 대표 캐릭터 로드 - 기존 값이 있으면 유지
                        let userRepChar = UserDefaults.standard.string(forKey: "representativeCharacter_\(firebaseUser.uid)") ?? ""
                        if !userRepChar.isEmpty {
                            self.representativeCharacter = userRepChar
                        } else if self.representativeCharacter.isEmpty {
                            // 현재 값이 비어있고 사용자별 설정도 없을 때만 전역 설정 사용
                            let globalRepChar = UserDefaults.standard.string(forKey: "representativeCharacter") ?? ""
                            if !globalRepChar.isEmpty {
                                self.representativeCharacter = globalRepChar
                                // 사용자별 설정에도 저장
                                UserDefaults.standard.set(globalRepChar, forKey: "representativeCharacter_\(firebaseUser.uid)")
                            }
                        }
                        
                        if UserDefaults.standard.object(forKey: "hasCompletedInitialSync_\(firebaseUser.uid)") == nil {
                            self.isFirstTimeLogin = true
                        }
                        
                        // 친구 서비스 리스너 설정
                        FriendsService.shared.handleAuthStateChanged(isLoggedIn: true)
                    } else {
                        self.currentUser = nil
                        self.isLoggedIn = false
                        
                        // 친구 서비스 리스너 해제
                        FriendsService.shared.handleAuthStateChanged(isLoggedIn: false)
                    }
                }
            }
        }
    }
    
    // MARK: - 공용 속성 및 메서드
    
    // 현재 사용자 ID 반환
    var userId: String {
        return currentUser?.id ?? ""
    }
    
    // 사용자 표시명 반환
    var displayName: String {
        if !representativeCharacter.isEmpty {
            return representativeCharacter
        }
        return currentUser?.displayName ?? "사용자"
    }
    
    // 사용자 이메일 반환
    var email: String {
        return currentUser?.email ?? ""
    }
    
    // 동기 버전 - 새로운 비동기 메서드를 호출하는 방식으로 변경
    func setRepresentativeCharacter(_ characterName: String) {
        // 이전 대표 캐릭터 이름 저장
        let oldCharacterName = self.representativeCharacter
        
        // 새 대표 캐릭터 이름 설정 (로컬)
        self.representativeCharacter = characterName
        
        // 전역 설정에 저장
        UserDefaults.standard.set(characterName, forKey: "representativeCharacter")
        
        // 사용자별 설정에 저장
        if isLoggedIn, let uid = currentUser?.id {
            UserDefaults.standard.set(characterName, forKey: "representativeCharacter_\(uid)")
            
            // 서버 업데이트는 비동기로 진행
            Task {
                do {
                    let _ = try await setRepresentativeCharacterAsync(characterName: characterName)
                } catch {
                    Logger.error("서버 대표 캐릭터 설정 실패", error: error)
                }
            }
        }
    }
    
    func setRepresentativeCharacterAsync(characterName: String) async throws -> Bool {
        // 다른 사용자가 이미 사용 중인지 확인
        if !characterName.isEmpty && isLoggedIn {
            let isInUse = try await FirebaseRepository.shared.isCharacterNameAlreadyInUse(characterName)
            if isInUse {
                // 이미 사용 중이면 실패 반환
                Logger.warning("대표 캐릭터 '\(characterName)'는 이미 다른 사용자가 사용 중입니다")
                return false
            }
        }
        
        // 사용자별 설정에 저장
        if isLoggedIn, let uid = currentUser?.id {
            // 즉시 값을 다시 읽어 검증 (디버깅용)
            let savedValue = UserDefaults.standard.string(forKey: "representativeCharacter_\(uid)") ?? ""
            Logger.debug("사용자별 대표 캐릭터 저장 확인: \(savedValue)")
            
            // Firestore 업데이트 및 characterNames 컬렉션에도 함께 등록
            do {
                let db = Firestore.firestore()
                
                // 1. 현재 사용자의 기존 characterNames 검색 및 삭제
                let snapshot = try await db.collection("characterNames")
                    .whereField("userId", isEqualTo: uid)
                    .getDocuments()
                
                // 기존 등록된 캐릭터들 삭제 (배치 처리)
                if !snapshot.documents.isEmpty {
                    let batch = db.batch()
                    for doc in snapshot.documents {
                        // 모든 캐릭터 문서 삭제
                        batch.deleteDocument(doc.reference)
                    }
                    try await batch.commit()
                    Logger.debug("기존 characterNames 엔트리 \(snapshot.documents.count)개 삭제 완료")
                }
                
                // 2. users 컬렉션의 displayName 업데이트
                try await db.collection("users").document(uid).updateData([
                    "displayName": characterName
                ])
                
                // 3. 대표 캐릭터 상세 정보만 저장
                try await FirebaseRepository.shared.storeCharacterDetails(characterName: characterName)
                
                // 4. 현재 사용자 객체 업데이트
                if var updatedUser = self.currentUser {
                    updatedUser.displayName = characterName
                    await MainActor.run {
                        self.currentUser = updatedUser
                    }
                }
                
                // 5. 친구들의 친구 목록에서 나의 displayName 업데이트
                let friendsSnapshot = try await db.collection("users")
                    .document(uid)
                    .collection("friends")
                    .getDocuments()
                
                if !friendsSnapshot.documents.isEmpty {
                    let batch = db.batch()
                    
                    for friendDoc in friendsSnapshot.documents {
                        if let friendId = friendDoc.data()["userId"] as? String {
                            // 친구의 친구 목록에서 나의 문서 참조
                            let friendRef = db.collection("users")
                                .document(friendId)
                                .collection("friends")
                                .document(uid)
                            
                            // 내 displayName 업데이트
                            batch.updateData(["displayName": characterName], forDocument: friendRef)
                        }
                    }
                    
                    // 배치 커밋
                    try await batch.commit()
                    Logger.debug("친구들의 친구 목록에서 displayName 업데이트 완료: \(characterName)")
                }
                
                Logger.debug("Firestore displayName 직접 업데이트 성공: '\(characterName)' (characterNames 포함)")
                return true
            } catch {
                Logger.error("Firestore displayName 직접 업데이트 실패: \(error.localizedDescription)")
                throw error
            }
        }
        
        // 로컬 저장만 된 경우도 성공으로 간주
        return true
    }
    
    // 캐릭터 상세 정보와 함께 대표 캐릭터 설정
    func setRepresentativeCharacterWithDetails(
        characterName: String,
        server: String,
        characterClass: String,
        level: Double
    ) async throws -> Bool {
        // 다른 사용자가 이미 사용 중인지 확인
        if !characterName.isEmpty && isLoggedIn {
            let isInUse = try await FirebaseRepository.shared.isCharacterNameAlreadyInUse(characterName)
            if isInUse {
                // 이미 사용 중이면 실패 반환
                Logger.warning("대표 캐릭터 '\(characterName)'는 이미 다른 사용자가 사용 중입니다")
                return false
            }
        }
        
        // 사용자별 설정에 저장
        if isLoggedIn, let uid = currentUser?.id {
            // 즉시 값을 다시 읽어 검증 (디버깅용)
            let savedValue = UserDefaults.standard.string(forKey: "representativeCharacter_\(uid)") ?? ""
            Logger.debug("사용자별 대표 캐릭터 저장 확인: \(savedValue)")
            
            // Firestore 업데이트 및 characterNames 컬렉션에도 함께 등록
            do {
                let db = Firestore.firestore()
                
                // 1. 현재 사용자의 기존 characterNames 검색 및 삭제
                let snapshot = try await db.collection("characterNames")
                    .whereField("userId", isEqualTo: uid)
                    .getDocuments()
                
                // 기존 등록된 캐릭터들 삭제 (배치 처리)
                if !snapshot.documents.isEmpty {
                    let batch = db.batch()
                    for doc in snapshot.documents {
                        // 모든 캐릭터 문서 삭제
                        batch.deleteDocument(doc.reference)
                    }
                    try await batch.commit()
                    Logger.debug("기존 characterNames 엔트리 \(snapshot.documents.count)개 삭제 완료")
                }
                
                // 2. users 컬렉션의 displayName 업데이트
                try await db.collection("users").document(uid).updateData([
                    "displayName": characterName
                ])
                
                // 3. 새 캐릭터 정보 저장 (상세 정보 포함)
                let characterDoc = db.collection("characterNames").document(characterName)
                try await characterDoc.setData([
                    "userId": uid,
                    "timestamp": FieldValue.serverTimestamp(),
                    "server": server,
                    "characterClass": characterClass,
                    "level": level
                ])
                
                // 4. 현재 사용자 객체 업데이트
                if var updatedUser = self.currentUser {
                    updatedUser.displayName = characterName
                    await MainActor.run {
                        self.currentUser = updatedUser
                    }
                }
                
                // 5. 친구들의 친구 목록에서 나의 displayName 업데이트
                let friendsSnapshot = try await db.collection("users")
                    .document(uid)
                    .collection("friends")
                    .getDocuments()
                
                if !friendsSnapshot.documents.isEmpty {
                    let batch = db.batch()
                    
                    for friendDoc in friendsSnapshot.documents {
                        if let friendId = friendDoc.data()["userId"] as? String {
                            // 친구의 친구 목록에서 나의 문서 참조
                            let friendRef = db.collection("users")
                                .document(friendId)
                                .collection("friends")
                                .document(uid)
                            
                            // 내 displayName 업데이트
                            batch.updateData(["displayName": characterName], forDocument: friendRef)
                        }
                    }
                    
                    // 배치 커밋
                    try await batch.commit()
                    Logger.debug("친구들의 친구 목록에서 displayName 업데이트 완료: \(characterName)")
                }
                
                Logger.debug("Firestore displayName 직접 업데이트 성공: '\(characterName)' (characterNames 포함)")
                return true
            } catch {
                Logger.error("Firestore displayName 직접 업데이트 실패: \(error.localizedDescription)")
                throw error
            }
        }
        
        // 로컬 저장만 된 경우도 성공으로 간주
        return true
    }
    
    // 대표 캐릭터 이름으로 표시 이름 업데이트
    func updateDisplayNameToRepCharacter() {
        guard isLoggedIn, !representativeCharacter.isEmpty, let uid = currentUser?.id else { return }
        
        Task {
            do {
                let db = Firestore.firestore()
                
                // 1. 현재 사용자의 기존 characterNames 검색 및 삭제
                let snapshot = try await db.collection("characterNames")
                    .whereField("userId", isEqualTo: uid)
                    .getDocuments()
                
                // 기존 등록된 캐릭터들 삭제 (배치 처리)
                if !snapshot.documents.isEmpty {
                    let batch = db.batch()
                    for doc in snapshot.documents {
                        // 모든 캐릭터 문서 삭제
                        batch.deleteDocument(doc.reference)
                    }
                    try await batch.commit()
                    Logger.debug("기존 characterNames 엔트리 정리 완료")
                }
                
                // 2. Firestore에 표시 이름 업데이트
                try await db.collection("users").document(uid).updateData([
                    "displayName": representativeCharacter
                ])
                
                // 3. 대표 캐릭터 상세 정보만 저장
                try await FirebaseRepository.shared.storeCharacterDetails(characterName: representativeCharacter)
                
                // 4. 현재 사용자 객체 업데이트
                if var updatedUser = currentUser {
                    updatedUser.displayName = representativeCharacter
                    await MainActor.run {
                        self.currentUser = updatedUser
                    }
                }
                
                // 5. 친구들의 친구 목록에서 나의 displayName 업데이트
                let friendsSnapshot = try await db.collection("users")
                    .document(uid)
                    .collection("friends")
                    .getDocuments()
                
                if !friendsSnapshot.documents.isEmpty {
                    let batch = db.batch()
                    
                    for friendDoc in friendsSnapshot.documents {
                        if let friendId = friendDoc.data()["userId"] as? String {
                            // 친구의 친구 목록에서 나의 문서 참조
                            let friendRef = db.collection("users")
                                .document(friendId)
                                .collection("friends")
                                .document(uid)
                            
                            // 내 displayName 업데이트
                            batch.updateData(["displayName": representativeCharacter], forDocument: friendRef)
                        }
                    }
                    
                    // 배치 커밋
                    try await batch.commit()
                    Logger.debug("친구들의 친구 목록에서 displayName 업데이트 완료: \(representativeCharacter)")
                }
                
                Logger.debug("사용자 표시 이름이 '\(representativeCharacter)'(으)로 업데이트되었습니다. (characterNames 포함)")
            } catch {
                Logger.error("사용자 표시 이름 업데이트 실패", error: error)
            }
        }
    }
    
    func updateFirestoreDisplayName() async -> Bool {
        guard isLoggedIn, let uid = currentUser?.id, !representativeCharacter.isEmpty else {
            return false
        }
        
        do {
            // 비동기 메서드로 처리
            return try await setRepresentativeCharacterAsync(characterName: representativeCharacter)
        } catch {
            Logger.error("Firestore displayName 직접 업데이트 실패: \(error.localizedDescription)")
            return false
        }
    }
    
    // 로그아웃
    func signOut() async -> Bool {
        do {
            try Auth.auth().signOut()
            return true
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            return false
        }
    }
    
    // 계정 삭제
    func deleteAccount() async -> Bool {
        guard let user = Auth.auth().currentUser else { return false }
        
        do {
            try await user.delete()
            return true
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            return false
        }
    }
    
    // MARK: - Apple 로그인
    
    func signInWithApple(idToken: String, nonce: String) async -> Bool {
        await MainActor.run {
            self.isLoading = true
        }
        
        do {
            let credential = OAuthProvider.credential(
                withProviderID: "apple.com",
                idToken: idToken,
                rawNonce: nonce
            )
            
            let result = try await Auth.auth().signIn(with: credential)
            
            // 로그인 성공 후 처리
            await handleSuccessfulLogin(user: result.user)
            
            await MainActor.run {
                self.currentUser = User(from: result.user)
                self.isLoggedIn = true
                self.isLoading = false
            }
            
            return true
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
            return false
        }
    }
    
    // MARK: - Google 로그인
    func signInWithGoogle() async -> Bool {
        await MainActor.run {
            self.isLoading = true
        }
        
        do {
            let result = try await signInWithGoogleInternal()
            
            // 구글 인증 정보 가져오기
            guard let idToken = result.user.idToken?.tokenString else {
                throw NSError(domain: "AuthManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "No ID token"])
            }
            
            // Firebase에 구글 인증 정보로 로그인
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
            let authResult = try await Auth.auth().signIn(with: credential)
            
            // 로그인 성공 후 처리
            await handleSuccessfulLogin(user: authResult.user)
            
            // 유저 정보 저장
            await MainActor.run {
                self.currentUser = User(from: authResult.user)
                self.isLoggedIn = true
                self.isLoading = false
            }
            
            return true
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
            return false
        }
    }
    
    @MainActor
    private func signInWithGoogleInternal() async throws -> GIDSignInResult {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            throw NSError(domain: "AuthManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No window scene found"])
        }
        
        guard let rootViewController = windowScene.windows.first?.rootViewController else {
            throw NSError(domain: "AuthManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No root view controller found"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { signInResult, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let signInResult = signInResult else {
                    continuation.resume(throwing: NSError(domain: "AuthManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "No sign in result"]))
                    return
                }
                
                continuation.resume(returning: signInResult)
            }
        }
    }
    
    // 로그인 성공 후 처리 (Apple/Google 공통)
    private func handleSuccessfulLogin(user: FirebaseAuth.User) async {
        // 대표 캐릭터 이름 불러오기
        let userRepChar = UserDefaults.standard.string(forKey: "representativeCharacter_\(user.uid)") ?? ""
        let globalRepChar = UserDefaults.standard.string(forKey: "representativeCharacter") ?? ""
        
        // 우선순위: 사용자별 설정 > 전역 설정 > 기본값
        let displayName: String
        if !userRepChar.isEmpty {
            displayName = userRepChar
            await MainActor.run {
                self.representativeCharacter = userRepChar
            }
        } else if !globalRepChar.isEmpty {
            displayName = globalRepChar
            // 사용자별 설정 저장
            UserDefaults.standard.set(globalRepChar, forKey: "representativeCharacter_\(user.uid)")
            await MainActor.run {
                self.representativeCharacter = globalRepChar
            }
        } else {
            displayName = user.displayName ?? "사용자"
        }
        
        // Firestore에 사용자 프로필 저장
        let db = Firestore.firestore()
        do {
            try await db.collection("users").document(user.uid).setData([
                "displayName": displayName,
                "email": user.email ?? "",
                "lastActive": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            Logger.error("사용자 프로필 저장 실패", error: error)
        }
    }
    
    // 에러 메시지 초기화
    func clearError() {
        self.error = nil
    }
    
    // 인증 관련 상태 최초 로그인 플래그 초기화
    func markInitialSyncComplete() {
        guard let userId = currentUser?.id else { return }
        UserDefaults.standard.set(true, forKey: "hasCompletedInitialSync_\(userId)")
        isFirstTimeLogin = false
    }
}
