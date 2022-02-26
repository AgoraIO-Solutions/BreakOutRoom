//
//  RtmSyncManager+Handle.swift
//  SyncManager
//
//  Created by ZYP on 2021/11/15.
//

import Foundation
import AgoraRtmKit

/// 哪些行为会有回调事件？
/// 1. sceneRef.delete() 没有回调事件
/// 2. AgoraSyncManager.deleteScenes["id"] 删除房间列表的一个房间 监听subscribe key == nil 有onDeleted事件
/// 3. sceneRef.update(key) 更新房间信息 只有update事件
/// 4. syncRef.collection(className: "member").add(data: ["userName" : "UserName"])
/// 监听syncRef.collection(className: "member").document().subscribe(key: nil) 有齐全的事件

extension RtmSyncManager {
    func notifyObserver(channel: AgoraRtmChannel, attributes: [AgoraRtmChannelAttribute]) {
        Log.info(text: "--- notifyObserver start ---", tag: "RtmSyncManager")
        
        /// 1. defaultChannel 会有缓存  没有的话走update
        /// 2. collection 会有缓存
        /// 3. scene.id+key、scene.id 没有缓存 都走update
        
        if channels[channelName] == channel { /** 1. defaultChannel **/
            if let cache = self.cachedAttrs[channel] { /** cache 存在的情况下，计算需要回调的事件 **/
                Log.info(text: "--- [defaultChannel, has cache]", tag: "RtmSyncManager")
                guard let tempChannel = channels[sceneName] else {
                    Log.errorText(text: "can not find scene channel", tag: "RtmSyncManager")
                    return
                }
                let onCreateBlock = onCreateBlocks[tempChannel]
                let onUpdateBlock = onUpdatedBlocks[tempChannel]
                let onDeleteBlock = onDeletedBlocks[tempChannel]
                
                invokeEvent(cache: cache,
                            attributes: attributes,
                            onCreateBlock: onCreateBlock,
                            onUpdateBlock: onUpdateBlock,
                            onDeleteBlock: onDeleteBlock)
                cachedAttrs[channel] = attributes
                return
            }
            
            /** cache 不存在的情况下，onOpdate **/
            Log.info(text: "--- [defaultChannel, no cache]", tag: "RtmSyncManager")
            guard let tempChannel = channels[sceneName] else {
                Log.errorText(text: "can not find scene channel", tag: "RtmSyncManager")
                return
            }
            if let onUpdateBlock = onUpdatedBlocks[tempChannel] {
                for arrt in attributes {
                    Log.info(text: "--- invoke onUpdateBlock", tag: "RtmSyncManager")
                    onUpdateBlock(arrt.toAttribute())
                }
            }
            cachedAttrs[channel] = attributes
            return
        }
        
        if let cache = self.cachedAttrs[channel] { /** 2. collection **/
            Log.info(text: "--- [collection]", tag: "RtmSyncManager")
            let onCreateBlock = onCreateBlocks[channel]
            let onUpdateBlock = onUpdatedBlocks[channel]
            let onDeleteBlock = onDeletedBlocks[channel]
            
            invokeEvent(cache: cache,
                        attributes: attributes,
                        onCreateBlock: onCreateBlock,
                        onUpdateBlock: onUpdateBlock,
                        onDeleteBlock: onDeleteBlock)
            cachedAttrs[channel] = attributes
            return
        }
        
        if let onUpdateBlock = onUpdatedBlocks[channel] { /** 3. scene.id or scene.id + key **/
            Log.info(text: "--- [scene.id or scene.id + key]", tag: "RtmSyncManager")
            for arrt in attributes {
                Log.info(text: "--- invoke onUpdateBlock", tag: "RtmSyncManager")
                onUpdateBlock(arrt.toAttribute())
            }
            return
        }
        
        Log.info(text: "--- notifyObserver do empty ---", tag: "RtmSyncManager")
    }
    
    fileprivate func invokeEvent(cache: [AgoraRtmChannelAttribute],
                                 attributes: [AgoraRtmChannelAttribute],
                                 onCreateBlock: OnSubscribeBlock?,
                                 onUpdateBlock: OnSubscribeBlock?,
                                 onDeleteBlock: OnSubscribeBlock?) {
        
        Log.info(text: "--- onCreateBlock is \(onCreateBlock == nil ? "nil" : "not nil")", tag: "RtmSyncManager")
        Log.info(text: "--- onUpdateBlock is \(onUpdateBlock == nil ? "nil" : "not nil")", tag: "RtmSyncManager")
        Log.info(text: "--- onDeleteBlock is \(onDeleteBlock == nil ? "nil" : "not nil")", tag: "RtmSyncManager")
        
        var onlyA = [IObject]()
        var onlyB = [IObject]()
        var both = [IObject]()
        var temp = [String : AgoraRtmChannelAttribute]()
        
        for i in cache {
            temp[i.key] = i
        }
        
        for b in attributes {
            if let i = temp[b.key] {
                if b.value != i.value {
                    both.append(b.toAttribute())
                }
                temp.removeValue(forKey: b.key)
            }
            else{
                onlyB.append(b.toAttribute())
            }
        }
        
        for i in temp.values {
            onlyA.append(i.toAttribute())
        }
        
        if let onUpdateBlockTemp = onUpdateBlock {
            for i in both {
                Log.info(text: "--- invoke onUpdateBlock", tag: "RtmSyncManager")
                onUpdateBlockTemp(i)
            }
        }
        
        if let onCreateBlockTemp = onCreateBlock {
            for i in onlyB {
                Log.info(text: "--- invoke onCreateBlock", tag: "RtmSyncManager")
                onCreateBlockTemp(i)
            }
        }
        
        if let onDeleteBlockTemp = onDeleteBlock {
            for i in onlyA {
                Log.info(text: "--- invoke onDeleteBlock", tag: "RtmSyncManager")
                onDeleteBlockTemp(i)
            }
        }
    }
}



