//
//  PhotoAsset.swift
//  AnyImageKit
//
//  Created by 刘栋 on 2019/9/16.
//  Copyright © 2019-2021 AnyImageProject.org. All rights reserved.
//

import UIKit
import Photos

public class PhotoAsset: Asset<PHAsset> {
    
    var _images: [ImageKey: UIImage] = [:]
    var videoDidDownload: Bool = false
    
    var state: State = .unchecked
    var selectedNum: Int = 1
    
    init(phAsset: PHAsset, selectOption: PickerSelectOption) {
        super.init(resource: phAsset, mediaType: MediaType(phAsset: phAsset, selectOption: selectOption))
    }
}

extension PhotoAsset {
    
    /// 输出图像
    public var image: UIImage {
        return _image ?? .init()
    }
    
    var _image: UIImage? {
        return (_images[.output] ?? _images[.edited]) ?? _images[.initial]
    }
    
    var isReady: Bool {
        switch mediaType {
        case .photo, .photoGIF, .photoLive:
            return _image != nil
        case .video:
            return videoDidDownload
        }
    }
    
    var isCamera: Bool {
        return false
    }
    
    static let cameraItemIdx: Int = -1
}

// MARK: - State
extension PhotoAsset {
    
    enum State: Equatable {
        
        case unchecked
        case normal
        case selected
        case disable(AssetDisableCheckRule)
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.unchecked, unchecked):
                return true
            case (.normal, normal):
                return true
            case (.selected, selected):
                return true
            case (.disable, disable):
                return true
            default:
                return false
            }
        }
    }
    
    var isUnchecked: Bool {
        return state == .unchecked
    }
    
    var isSelected: Bool {
        get {
            return state == .selected
        }
        set {
            state = newValue ? .selected : .normal
        }
    }
    
    var isDisable: Bool {
        switch state {
        case .disable(_):
            return true
        default:
            return false
        }
    }
}

// MARK: - Disable Check
extension PhotoAsset {

    func check(disable rules: [AssetDisableCheckRule]) {
        guard isUnchecked else { return }
        for rule in rules {
            if rule.isDisable(for: self) {
                state = .disable(rule)
                return
            }
        }
        state = .normal
    }
}

// MARK: - Original Photo
extension PhotoAsset {
    
    /// Fetch Photo Data 获取原图数据
    /// - Note: Only for `MediaType` Photo, GIF, LivePhoto 仅用于媒体类型为照片、GIF、实况
    /// - Parameter options: Photo Data Fetch Options 原图获取选项
    /// - Parameter completion: Photo Data Fetch Completion 原图获取结果回调
    @discardableResult
    public func fetchPhotoData(options: PhotoDataFetchOptions = .init(), completion: @escaping PhotoDataFetchCompletion) -> PHImageRequestID {
        guard phAsset.mediaType == .image else {
            completion(.failure(.invalidMediaType), 0)
            return 0
        }
        return ExportTool.requestPhotoData(for: phAsset, options: options, completion: completion)
    }
    
    /// Fetch Photo URL 获取原图路径
    /// - Note: Only for `MediaType` Photo, PhotoGIF 仅用于媒体类型为照片、GIF
    /// - Parameter options: Photo URL Fetch Options 原图路径获取选项
    /// - Parameter completion: Photo URL Fetch Completion 原图路径获取结果回调
    @discardableResult
    public func fetchPhotoURL(options: PhotoURLFetchOptions = .init(), completion: @escaping PhotoURLFetchCompletion) -> PHImageRequestID {
        guard phAsset.mediaType == .image else {
            completion(.failure(.invalidMediaType), 0)
            return 0
        }
        return ExportTool.requestPhotoURL(for: phAsset, options: options, completion: completion)
    }
}

// MARK: - Video
extension PhotoAsset {
    
    /// Fetch Video 获取视频，用于播放
    /// - Note: Only for `MediaType` Video 仅用于媒体类型为视频
    /// - Parameter options: Video Fetch Options 视频获取选项
    /// - Parameter completion: Video Fetch Completion 视频获取结果回调
    @discardableResult
    public func fetchVideo(options: VideoFetchOptions = .init(), completion: @escaping VideoFetchCompletion) -> PHImageRequestID {
        guard phAsset.mediaType == .video else {
            completion(.failure(.invalidMediaType), 0)
            return 0
        }
        return ExportTool.requestVideo(for: phAsset, options: options, completion: completion)
    }
    
    /// Fetch Video URL 获取视频路径，用于传输
    /// - Note: Only for `MediaType` Video 仅用于媒体类型为视频
    /// - Parameter options: Video URL Fetch Options 视频路径获取选项
    /// - Parameter completion: Video URL Fetch Completion 视频路径获取结果回调
    @discardableResult
    public func fetchVideoURL(options: VideoURLFetchOptions = .init(), completion: @escaping VideoURLFetchCompletion) -> PHImageRequestID {
        guard phAsset.mediaType == .video else {
            completion(.failure(.invalidMediaType), 0)
            return 0
        }
        return ExportTool.requestVideoURL(for: phAsset, options: options, completion: completion)
    }
}

extension PhotoAsset {
    
    enum ImageKey: String, Hashable {
        
        case initial
        case edited
        case output
    }
}
