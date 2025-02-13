//
//  PhotoHelper.swift
//  MyPhoto
//
//  Created by 张凡 on 2025/2/13.
//

import Foundation
import Photos
import UIKit

/// 照片助手
class PhotoHelper {
    static let shared = PhotoHelper()
    
    private init() {}
    
    /// 获取相册中的所有媒体资源
    /// - Parameters:
    ///   - mediaTypes: 媒体类型数组，默认为 [.image, .video]
    ///   - ascending: 是否按创建时间升序排列，默认为 false（即默认按时间倒序）
    ///   - currentAssets: 当前已有的资源，默认为 nil
    ///   - completion: 加载完成回调
    func fetchAllAssets(mediaTypes: [PHAssetMediaType] = [.image, .video], ascending: Bool = false, completion: @escaping ([PHAsset]) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .authorized:
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: ascending)]
            
            // 获取所有指定类型的资源
            let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
            var assets = [PHAsset]()
            fetchResult.enumerateObjects { (asset, _, _) in
                if mediaTypes.contains(asset.mediaType) {
                    assets.append(asset)
                }
            }
            
            DispatchQueue.main.async {
                completion(assets)
            }
            
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { newStatus in
                if newStatus == .authorized {
                    self.fetchAllAssets(mediaTypes: mediaTypes, ascending: ascending, completion: completion)
                } else {
                    DispatchQueue.main.async {
                        completion([])
                    }
                }
            }
            
        default:
            DispatchQueue.main.async {
                completion([])
            }
        }
    }
    
    /// 加载图片
    /// - Parameters:
    ///   - asset: 图片资源
    ///   - targetSize: 目标尺寸
    ///   - completion: 加载完成回调
    func loadImage(for asset: PHAsset, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) -> PHImageRequestID? {
        let scaledSize = CGSize(width: targetSize.width, height: targetSize.height)
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        
        return PHImageManager.default().requestImage(for: asset, targetSize: scaledSize, contentMode: .aspectFill, options: options) { image, _ in
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
    
    /// 加载高清大图
    /// - Parameters:
    ///   - asset: 图片资源
    ///   - targetSize: 目标尺寸
    ///   - completion: 加载完成回调
    func loadHighQualityImage(for asset: PHAsset, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) -> PHImageRequestID? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat // 高质量模式
        options.resizeMode = .exact // 精确尺寸
        options.isNetworkAccessAllowed = true // 允许从网络加载
        
        return PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, _ in
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
}
