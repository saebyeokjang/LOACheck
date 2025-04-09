//
//  SignInView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/8/25.
//

import SwiftUI
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseFirestore

struct SignInView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var currentNonce: String?
    @Environment(\.colorScheme) var colorScheme
    
    struct IdentifiableError: Error, Identifiable {
        let id = UUID()
        let error: Error
    }
    
    @State private var localError: IdentifiableError?
    
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            // 헤더 이미지 및 제목
            VStack(spacing: 20) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)
                
                Text("LOA Check")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("로그인하여 친구와 진행 상황을 공유하세요")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // 로그인 버튼들
            VStack(spacing: 20) {
                // Apple 로그인 버튼
                SignInWithAppleButton(.signIn) { request in
                    // 요청 설정
                    let nonce = randomNonceString()
                    currentNonce = nonce
                    request.requestedScopes = [.email, .fullName]
                    request.nonce = sha256(nonce)
                } onCompletion: { result in
                    // 결과 처리
                    switch result {
                    case .success(let authResult):
                        switch authResult.credential {
                        case let appleCredential as ASAuthorizationAppleIDCredential:
                            if let idToken = appleCredential.identityToken,
                               let nonce = currentNonce,
                               let tokenString = String(data: idToken, encoding: .utf8) {
                                
                                // Firebase 인증 처리
                                Task {
                                    let success = await authManager.signInWithApple(
                                        idToken: tokenString,
                                        nonce: nonce
                                    )
                                    
                                    if success {
                                        // 직접 Firestore에 사용자 정보 저장
                                        let db = Firestore.firestore()
                                        if let userId = Auth.auth().currentUser?.uid,
                                           let displayName = Auth.auth().currentUser?.displayName,
                                           let email = Auth.auth().currentUser?.email {
                                            
                                            try? await db.collection("users").document(userId).setData([
                                                "displayName": displayName,
                                                "email": email,
                                                "lastActive": FieldValue.serverTimestamp()
                                            ], merge: true)
                                            
                                            print("사용자 정보 저장 성공: \(userId)")
                                        }
                                        
                                        DispatchQueue.main.async {
                                            isPresented = false
                                        }
                                    }
                                }
                            }
                        default:
                            break
                        }
                    case .failure(let error):
                        print("Apple Sign In failed: \(error.localizedDescription)")
                    }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .cornerRadius(8)
                
                // 비회원 사용 버튼
                Button(action: {
                    isPresented = false
                }) {
                    Text("비회원으로 계속하기")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // 개인정보 처리방침 및 이용약관
            VStack(spacing: 5) {
                Text("로그인 시 이용약관 및 개인정보 처리방침에 동의하게 됩니다.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 5) {
                    Link("이용약관", destination: URL(string: "https://yourapp.com/terms")!)
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Link("개인정보 처리방침", destination: URL(string: "https://yourapp.com/privacy")!)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.bottom)
        }
        .padding()
        .alert(item: $localError) { identifiableError in
            Alert(
                title: Text("로그인 오류"),
                message: Text(identifiableError.error.localizedDescription),
                dismissButton: .default(Text("확인"))
            )
        }
        .onReceive(authManager.$error) { newError in
            if let newError = newError {
                // IdentifiableError로 래핑
                localError = IdentifiableError(error: newError)
            } else {
                localError = nil
            }
        }
    }
    
    // 무작위 nonce 생성
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError(
                        "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
                    )
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    // SHA256 해시 생성
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    // 인증 에러를 표시하기 위한 계산된 바인딩
    private var authError: Binding<Error?> {
        Binding<Error?>(
            get: { authManager.error },
            set: { authManager.error = $0 }
        )
    }
}

struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView(isPresented: .constant(true))
            .environmentObject(AuthManager.shared)
    }
}
