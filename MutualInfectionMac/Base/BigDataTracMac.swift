//
//  BigDataTracMac.swift
//  MutualInfection
//
//  Created by 1234 on 2025/11/15.
//

import Foundation

class BigDataTracMac {
    let domainTocken : String = "iam.cn-east-3.myhuaweicloud.com"//Tocken域名
    let domainName : String = "hw15332372630"//IAM所属账号名
    let iamName : String = "A0271009"//IAM用户名
    let iamPsd : String = "eO_8rw0f7UJUws$7MSPEqHd"//IAM密码
    let region : String = "cn-east-3"//区域名
    let domainLts : String = "lts-access.cn-east-3.myhuaweicloud.com"//LTS域名
    let projectId : String = "32fc626687e44ee5a51a0885afb5ce32"//账号的项目ID
    let groupId : String = "92c8db2e-fbed-4bf6-95f5-b21c01f0b85f"//LTS的日志组ID
    let streamId : String = "c4ce26d2-6da7-4152-b940-e3fa513e6b41"//LTS的日志流ID
    
    func sendPostRequest(content: String) async throws {
        guard let url = URL(string: "https://"+domainTocken+"/v3/auth/tokens") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json;charset=utf8", forHTTPHeaderField: "Content-Type")
        let postData: [String: Any] = [
            "auth": [
                "identity": [
                    "methods": ["password"],
                    "password": [
                        "user": [
                            "domain": [
                                "name": domainName
                            ],
                            "name": iamName,
                            "password": iamPsd
                        ]
                    ]
                ],
                "scope": [
                    "project": [
                        "name": region
                    ]
                ]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: postData, options: [])

        // 使用await等待网络请求返回
        let (data, response) = try await URLSession.shared.data(for: request)


        // 处理响应
        if let httpResponse = response as? HTTPURLResponse {
            if let authToken = httpResponse.allHeaderFields["X-Subject-Token"] as? String {
                    let currentDate = Date()
                    let timeUTC = Int(currentDate.timeIntervalSince1970)*1000000000
                    guard let url = URL(string: "https://"+domainLts+"/v2/"+projectId+"/lts/groups/"+groupId+"/streams/"+streamId+"/tenant/contents") else {
                        throw URLError(.badURL)
                    }
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json;charset=utf8", forHTTPHeaderField: "Content-Type")
                    request.setValue(authToken, forHTTPHeaderField: "X-Auth-Token")
                    let postData: [String: Any] = [
                        "log_time_ns":timeUTC,
                        "contents": content,
                        "labels":[
                            "contact": UUID().uuidString
                        ]
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: postData, options: [])
                    let (data, response) = try await URLSession.shared.data(for: request)
                    if let responseString = String(data: data, encoding: .utf8) {
                            print("响应数据: \(responseString)")
                        }
                }
        }
    }
}
