//
//  AppleLoginHandler.swift
//  MutualInfection
//
//  Created by 1234 on 2025/10/20.
//

import AuthenticationServices

class AppleLoginHandler: NSObject {
    static let shared = AppleLoginHandler()
    private var completion: ((String?, Error?) -> Void)?
    
    func requestAppleIDLogin(completion: @escaping (String?, Error?) -> Void) {
        self.completion = completion
        
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = []
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }
}

extension AppleLoginHandler: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController,
                               didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            completion?(nil, NSError(domain: "AppleLoginError", code: -1, userInfo: nil))
            return
        }
        completion?(credential.user, nil)
    }
    
    func authorizationController(controller: ASAuthorizationController,
                               didCompleteWithError error: Error) {
        completion?(nil, error)
    }
}
