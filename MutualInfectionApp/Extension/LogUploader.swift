//
//  Untitled.swift
//  MutualInfection
//
//  Created by 1234 on 2025/10/9.
//

//type:日志类型（debug,error,info）
//content:日志内容

import LTSSDK
class LogUploader{
    func upload(type: String,content: String)
    {
        LTSSDK.setLogLevel(.debug)
        let params = LTSConfigParams()
        params.region = "cn-east-3"//云日志服务的区域
        params.projectId = "32fc626687e44ee5a51a0885afb5ce32"//账号的项目ID
        params.groupId = "92c8db2e-fbed-4bf6-95f5-b21c01f0b85f"//LTS的日志组ID
        params.streamId = "c4ce26d2-6da7-4152-b940-e3fa513e6b41"//LTS的日志流ID
        params.accessKey = "HPUAIA5MJT9N7DKQMEWT"
        params.secretKey = "kFAsFkI3w4bqTMl4GV7DDDYgFJn1vb19Gslh7K0c"
        let lts = LTSSDK(config:params)
        lts.reportImmediately(["content": ""+content+""], labels: ["type": ""+type+""])
    }
}
