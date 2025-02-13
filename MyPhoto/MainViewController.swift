//
//  MainViewController.swift
//  MyPhoto
//
//  Created by 张凡 on 2025/2/13.
//

import UIKit
import SnapKit
import Photos

/// 主视图控制器 - 展示相册中的所有照片
class MainViewController: UIViewController {

    private let cellIdentifier = "PhotoCell"
    private var photos: [PHAsset] = []
    private let itemSize = (screenW - smallSpace * CGFloat(photoNum + 1)) / CGFloat(photoNum)
    private var imageRequestIDs = [IndexPath: PHImageRequestID]()
    private var needsRefresh = false // 标记是否需要刷新
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: itemSize, height: itemSize)
        layout.minimumLineSpacing = smallSpace
        layout.minimumInteritemSpacing = smallSpace
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .white
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: cellIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.prefetchDataSource = self
        return collectionView
    }()
    
    private lazy var bottomBar: UIToolbar = {
        let toolbar = UIToolbar()
        toolbar.barTintColor = .white
        
        let albumButton = UIBarButtonItem(title: "相册", style: .plain, target: self, action: #selector(handleAlbumButtonTap))
        let otherButton = UIBarButtonItem(title: "其他", style: .plain, target: self, action: #selector(handleOtherButtonTap))
        let fixedSpace = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        fixedSpace.width = 20 // 设置按钮之间的间距
        
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            albumButton,
            fixedSpace,
            otherButton,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        ]
        return toolbar
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadPhotos()
        
        // 监听相册变化
        PHPhotoLibrary.shared().register(self)
        
        // 监听 App 进入前台
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    deinit {
        // 移除监听
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // 取消所有未完成的图片请求
        imageRequestIDs.values.forEach { PHImageManager.default().cancelImageRequest($0) }
        imageRequestIDs.removeAll()
    }
    
    private func setupUI() {
        view.addSubview(collectionView)
        view.addSubview(bottomBar)
        
        collectionView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.bottom.equalTo(bottomBar.snp.top)
        }
        
        bottomBar.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(80)
        }
    }
    
    private func loadPhotos(shouldScrollToBottom: Bool = true) {
        PhotoHelper.shared.fetchAllAssets(mediaTypes: [.image, .video], ascending: true) { [weak self] photos in
            self?.photos = photos
            self?.collectionView.reloadData()
            
            DispatchQueue.main.async {
                // 仅在需要时滑动到底部
                if !photos.isEmpty && shouldScrollToBottom {
                    let lastIndex = IndexPath(item: photos.count - 1, section: 0)
                    self?.collectionView.scrollToItem(at: lastIndex, at: .bottom, animated: false)
                }
                
                // 延迟一小段时间，确保布局完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.loadHighQualityImagesForVisibleCells()
                }
            }
        }
    }
    
    @objc private func handleAlbumButtonTap() {
        // 滑动到列表底部
        if !photos.isEmpty {
            let lastIndex = IndexPath(item: photos.count - 1, section: 0)
            collectionView.scrollToItem(at: lastIndex, at: .bottom, animated: true)
            
            // 延迟一小段时间，确保滑动完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.loadHighQualityImagesForVisibleCells()
            }
        }
    }
    
    @objc private func handleOtherButtonTap() {
        // 处理其他按钮点击
        print("其他按钮被点击")
    }
    
    @objc private func handleAppWillEnterForeground() {
        // 如果标记需要刷新，则重新加载照片，但不滑动到底部
        if needsRefresh {
            needsRefresh = false
            loadPhotos(shouldScrollToBottom: false)
        }
    }
}

// 实现 PHPhotoLibraryChangeObserver 协议
extension MainViewController: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        // 标记需要刷新
        needsRefresh = true
    }
}

class PhotoCell: UICollectionViewCell {
    let imageView = UIImageView()
    private let durationLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 设置视频时长标签
        durationLabel.textColor = .white
        durationLabel.font = UIFont.systemFont(ofSize: 12)
        durationLabel.textAlignment = .right
        durationLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        durationLabel.layer.cornerRadius = 3
        durationLabel.layer.masksToBounds = true
        contentView.addSubview(durationLabel)
        durationLabel.snp.makeConstraints { make in
            make.right.bottom.equalToSuperview().offset(-5)
            make.height.equalTo(20)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        durationLabel.text = nil
    }
    
    func configure(with asset: PHAsset) {
        if asset.mediaType == .video {
            let duration = Int(round(asset.duration))
            let minutes = duration / 60
            let seconds = duration % 60
            durationLabel.text = String(format: "%02d:%02d", minutes, seconds)
            durationLabel.isHidden = false
        } else {
            durationLabel.isHidden = true
        }
    }
}

extension MainViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! PhotoCell
        
        let asset = photos[indexPath.item]
        cell.configure(with: asset)
        
        // 加载图片
        let requestID = PhotoHelper.shared.loadImage(for: asset, targetSize: CGSize(width: itemSize, height: itemSize)) { image in
            cell.imageView.image = image
            self.imageRequestIDs.removeValue(forKey: indexPath)
        }
        
        if let requestID = requestID {
            imageRequestIDs[indexPath] = requestID
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            let asset = photos[indexPath.item]
            let requestID = PhotoHelper.shared.loadImage(for: asset, targetSize: CGSize(width: itemSize, height: itemSize)) { _ in }
            if let requestID = requestID {
                imageRequestIDs[indexPath] = requestID
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            if let requestID = imageRequestIDs[indexPath] {
                PHImageManager.default().cancelImageRequest(requestID)
                imageRequestIDs.removeValue(forKey: indexPath)
            }
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        loadHighQualityImagesForVisibleCells()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            loadHighQualityImagesForVisibleCells()
        }
    }

    private func loadHighQualityImagesForVisibleCells() {
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        
        for indexPath in visibleIndexPaths {
            let asset = photos[indexPath.item]
            let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell
            
            // 使用新方法加载高清大图
            let requestID = PhotoHelper.shared.loadHighQualityImage(for: asset, targetSize: CGSize(width: itemSize * 2, height: itemSize * 2)) { image in
                cell?.imageView.image = image
                self.imageRequestIDs.removeValue(forKey: indexPath)
            }
            
            if let requestID = requestID {
                imageRequestIDs[indexPath] = requestID
            }
        }
    }
}
