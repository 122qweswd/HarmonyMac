//
//  Untitled.swift
//  MutualInfection
//
//  Created by 1234 on 2025/10/9.
//

import LTSSDK
class FeedbackUploader{
    func upload(contact: String,des: String,pic: String,report: String,time: String,log: String,appleUserID: String)
    {
        LTSSDK.setLogLevel(.debug)
        let params = LTSConfigParams()
        params.region = "cn-east-3"//云日志服务的区域
        params.projectId = "32fc626687e44ee5a51a0885afb5ce32"//账号的项目ID
        params.groupId = "4dc3544f-5c09-4413-9be9-aa03b70a2cc6"//LTS的日志组ID
        params.streamId = "3e9c65c4-75e9-404e-9f4c-737e13b65226"//LTS的日志流ID
        params.accessKey = "HPUAIA5MJT9N7DKQMEWT"
        params.secretKey = "kFAsFkI3w4bqTMl4GV7DDDYgFJn1vb19Gslh7K0c"
        let lts = LTSSDK(config:params)
        lts.reportImmediately(["content": "联系方式："+contact+" ｜ 问题描述："+des+" ｜ 发送错误报告："+report+" | 版本号："+appVersion+" ("+appBuildVersion+") ｜ 发生时间："+time+"｜ 上传日志："+log+" | appleUserID："+appleUserID+" | 上传图片："+pic+""], labels: ["contact": ""+contact+""])
    }
}
