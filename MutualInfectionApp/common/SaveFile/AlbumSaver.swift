//
//  AlbumSaver.swift
//  MutualInfection
//
//  Created by mac on 2025/10/28.
//
import Photos

class AlbumSaver: NSObject {
    
    /// 获取或创建相册
    static func getOrCreateAlbum(albumName: String, completion: @escaping (PHAssetCollection?, Error?) -> Void) {
        
        // 首先尝试查找相册
        if let existingAlbum = findAlbum(albumName: albumName) {
            ShareAPI.shared().log(1, "[SaveFile] [AlbumSaver] 相册存在: \(albumName)")
            completion(existingAlbum, nil)
            return
        }
        
        // 相册不存在，创建新相册
        PHPhotoLibrary.shared().performChanges({
            let _ = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
        }) { success, error in
            if success {
                // 创建成功后再次查找
                let createdAlbum = self.findAlbum(albumName: albumName)
                ShareAPI.shared().log(1, "[SaveFile] [AlbumSaver] 相册创建成功: \(albumName)")
                completion(createdAlbum, nil)
            } else {
                ShareAPI.shared().log(3, "[SaveFile] [AlbumSaver] 相册创建失败: \(String(describing: error?.localizedDescription))")
                completion(nil, error)
            }
        }
    }
    
    /// 查找指定名称的相册
    static func findAlbum(albumName: String) -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        return collections.firstObject
    }
    
}
