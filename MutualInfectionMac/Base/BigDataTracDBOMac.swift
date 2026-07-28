//
//  BigDataTracDBOMac.swift
//  MutualInfection
//
//  Created by 1234 on 2025/11/16.
//

import Foundation
import WCDBSwift

class BigDataTracDBOMac {
    private let database: Database
    private let dataBaseName: String = "dfx.db"
    private let dataTableName: String = "dfxTable"
    
    init() {
        do{
            let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? NSTemporaryDirectory()
            let dbPath = (documents as NSString).appendingPathComponent(dataBaseName)
            database = Database(at: dbPath)
        }catch{
            ShareAPI.shared().log(3,"dfx init error")
        }
    }
    func getAllDfxData()->[DfxModel]{
        do{
            try database.create(table: dataTableName, of: DfxModel.self)
            let allObjects: [DfxModel] = try database.getObjects(fromTable: dataTableName)
            return allObjects
        }catch{
            ShareAPI.shared().log(3,"dfx getAllDfxData error")
            let model = DfxModel()
            let allObjects = [model]
            return allObjects
        }
    }
    func insertDfxData(data: String){
        do{
            let model = DfxModel()
            model.id = UUID().uuidString
            model.dfx = data
            try database.create(table: dataTableName, of: DfxModel.self)
            try database.insert(model, intoTable: dataTableName)
        }catch{
            ShareAPI.shared().log(3,"dfx insertDfxData error [\(data)]")
        }
    }
    func deleteDfxData(id: String){
        do{
            try database.create(table: dataTableName, of: DfxModel.self)
            try database.delete(fromTable: dataTableName,
                                where: DfxModel.Properties.id == id)
        }catch{
            ShareAPI.shared().log(3,"dfx deleteDfxData error")
        }
    }
    func dfxDataAutoPost() {
        Gloable.dfxAutoFlag = false
        let dataList=getAllDfxData()
        let dfxDBO=BigDataTracDBOMac()
        let bigDataTrac = BigDataTracMac()
        for ele in dataList {
            Task {
                do {
                    if NetworkMonitorConnectMac.shared.isReachable {
                        //有网络
                        guard let dfxString = ele.dfx else {
                            return
                        }
                        guard let idString = ele.id else {
                            return
                        }
                        try await bigDataTrac.sendPostRequest(content: dfxString)
                        deleteDfxData(id: idString)
                    }
                }catch {
                    ShareAPI.shared().log(3,"dfxDataAutoPost error")
                }
            }
        }
        Gloable.dfxAutoFlag = true
    }
}
class DfxModel: TableCodable {
    var id: String? = nil
    var dfx: String? = nil
    enum CodingKeys: String, CodingTableKey {
        typealias Root = DfxModel
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        case id
        case dfx
    }
}
