//
//  RoomController.swift
//  Classroom
//
//  Created by XC on 2021/4/21.
//

import Foundation
import UIKit
import RxSwift
import RxCocoa
import IGListKit
import Core
import Whiteboard

protocol RoomControlDelegate: AnyObject {
    func onTap(view: RoleVideoView)
}

class RoomController: BaseViewContoller, DialogDelegate, RoomDelegate {
    
    @IBOutlet weak var backView: UIButton!
    
    @IBOutlet weak var hostRootView: UIView!
    @IBOutlet weak var hostVideoView: UIView! {
        didSet {
            hosterVideoView.videoView = hostVideoView
        }
    }
    @IBOutlet weak var hostNameView: UILabel! {
        didSet {
            hosterVideoView.nameView = hostNameView
        }
    }
    @IBOutlet weak var hostMicView: UIImageView! {
        didSet {
            hosterVideoView.micView = hostMicView
        }
    }
    
    @IBOutlet weak var chatListView: UITableView!
    @IBOutlet weak var toolBarRootView: UIView!
    @IBOutlet weak var inputMessageRootView: UIView!
    @IBOutlet weak var inputMessageView: UITextField!
    @IBOutlet weak var WhiteboardContianer: UIView!
    private var showInputView: Bool = false
    
    private var hosterVideoView: RoleVideoView = RoleVideoView()
    private var hosterToolbar: HosterToolbar?
    
    var viewModel: RoomViewModel = RoomViewModel()
    var whiteSdk: WhiteSDK?
    
    private func renderToolbar() {
        if (hosterToolbar == nil) {
            hosterToolbar = HosterToolbar()
            if let hosterToolbar = hosterToolbar {
                toolBarRootView.addSubview(hosterToolbar)
                hosterToolbar.fill(view: toolBarRootView).active()
                hosterToolbar.delegate = self
                
                hosterToolbar.subcribeUIEvent()
                hosterToolbar.subcribeRoomEvent()
            }
        }
    }
    
    private func renderSpeakers() {
        hosterVideoView.member = viewModel.speakers.hoster
    }
    
    private func subcribeUIEvent() {
        backView.rx.tap
            .debounce(RxTimeInterval.microseconds(300), scheduler: MainScheduler.instance)
            .throttle(RxTimeInterval.seconds(1), scheduler: MainScheduler.instance)
            .concatMap { [unowned self] _ -> Observable<Bool> in
                if (self.viewModel.isManager) {
                    return self.showAlert(title: "Close room".localized, message: "Leaving the room ends the session and removes everyone".localized)
                } else if (self.viewModel.isSpeaker) {
                    return self.showAlert(title: "Leave room".localized, message: "离开直播间将自动停止连麦".localized)
                } else {
                    return Observable.just(true)
                }
            }
            .filter { close in
                return close
            }
            .concatMap { [unowned self] _ -> Observable<Result<Void>> in
                return self.viewModel.leaveRoom(action: .closeRoom)
                    .do(onSubscribe: {
                        self.show(processing: true)
                    }, onDispose: {
                        self.show(processing: false)
                    })
            }
            .filter { [unowned self] result in
                if (!result.success) {
                    self.show(message: result.message ?? "unknown error".localized, type: .error)
                }
                return result.success
            }
            .concatMap { [unowned self] _ in
                return self.dismiss()
            }
            .subscribe()
            .disposed(by: disposeBag)
        
        hosterVideoView.subcribeUIEvent()
        
        keyboardHeight()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [unowned self] height in
                if (self.showInputView) {
                    self.inputMessageRootView.isHidden = false
                    self.inputMessageRootView.removeAllConstraints()
                    self.inputMessageView.removeAllConstraints()
                    self.inputMessageRootView.marginTrailing(anchor: self.view.trailingAnchor)
                        .centerX(anchor: self.view.centerXAnchor)
                        .marginBottom(anchor: self.view.bottomAnchor, constant: height)
                        .active()
                    if (height == 0) {
                        self.inputMessageView
                            .marginLeading(anchor: self.inputMessageRootView.leadingAnchor, constant: 12)
                            .centerX(anchor: self.inputMessageRootView.centerXAnchor)
                            .marginTop(anchor: self.inputMessageRootView.topAnchor, constant: 12)
                            .marginBottom(anchor: self.view.safeAreaLayoutGuide.bottomAnchor, constant: 12)
                            .active()
                    } else {
                        self.inputMessageView
                            .fill(view: self.inputMessageRootView, leading: 12, top: 12, trailing: 12, bottom: 12)
                            .active()
                    }
                } else {
                    self.inputMessageRootView.isHidden = true
                    self.inputMessageRootView.removeAllConstraints()
                    self.inputMessageView.removeAllConstraints()
                    self.inputMessageRootView.marginTrailing(anchor: self.view.trailingAnchor)
                        .centerX(anchor: self.view.centerXAnchor)
                        .marginBottom(anchor: self.view.bottomAnchor, constant: 0)
                        .active()
                    self.inputMessageView
                        .fill(view: self.inputMessageRootView, leading: 12, top: 12, trailing: 12, bottom: 12)
                        .active()
                }
            })
            .disposed(by: disposeBag)
    }
    
    private func subcribeRoomEvent() {
        viewModel.roomMembersDataSource()
            .observe(on: MainScheduler.instance)
            .flatMap { [unowned self] result -> Observable<Result<Bool>> in
                let roomClosed = result.data
                if (roomClosed == true) {
                    return self.viewModel.leaveRoom(action: .leave).map { _ in result }
                } else {
                    return Observable.just(result)
                }
            }
            .observe(on: MainScheduler.instance)
            .flatMap { [unowned self] result -> Observable<Result<Bool>> in
                if (result.data == true) {
                    Logger.log(message: "subcribeRoomEvent roomClosed", level: .info)
                    return self.dismiss().asObservable().map { _ in result }
                } else {
                    //self.adapter.performUpdates(animated: false)
                    self.renderSpeakers()
                    return Observable.just(result)
                }
            }
            .subscribe(onNext: { [unowned self] result in
                let roomClosed = result.data
                if (!result.success) {
                    self.show(message: result.message ?? "unknown error".localized, type: .error)
                } else if (roomClosed == true) {
                    //self.leaveAction?(.leave, self.viewModel.room)
                } else {
                    self.renderToolbar()
                }
            })
            .disposed(by: disposeBag)

        viewModel.actionsSource()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [unowned self] result in
                switch self.viewModel.role {
                case .manager:
                    hosterToolbar?.onReceivedAction(result)
                    break
                case .leftSpeaker, .rightSpeaker:
                    break
                case .listener:
                    break
                }
            })
            .disposed(by: disposeBag)
        
        viewModel.subscribeMessages()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [unowned self] result in
                if (!result.success) {
                    self.show(message: result.message ?? "unknown error".localized, type: .error)
                } else {
                    self.chatListView.reloadData() {
                        self.chatListView.scroll(to: .top, animated: true)
                    }
                }
            })
            .disposed(by: disposeBag)
        
        viewModel.onTopListenersChange
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [unowned self] _ in
                
            })
            .disposed(by: disposeBag)
        
        viewModel.onMemberEnter
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [unowned self] member in
                if let member = member {
                    self.onMemberEnter(member: member)
                }
            })
            .disposed(by: disposeBag)
    }
    
    private func onMemberEnter(member: ClassroomMember) {
        Logger.log(message: "\(member.user.name) enter the live room", level: .info)
        let view = MemberEnterView()
        view.member = member
        
        self.view.addSubview(view)
        view.marginLeading(anchor: self.view.leadingAnchor, constant: 12)
            .marginTop(anchor: self.chatListView.topAnchor)
            .width(constant: 257)
            .height(constant: 24, relation: .greaterOrEqual)
            .active()
        
        let translationY: CGFloat = 257
        view.transform = CGAffineTransform(translationX: translationY, y: 0)
        view.alpha = 0
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut, animations: {
            view.alpha = 1
            view.transform = CGAffineTransform(translationX: 0, y: 0)
        }, completion: { success in
            UIView.animate(withDuration: 0.2, delay: 1.5, options: .curveEaseInOut, animations: {
                view.alpha = 0
                view.transform = CGAffineTransform(translationX: -translationY, y: 0)
            }, completion: { _ in
                view.removeFromSuperview()
            })
        })
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        enableInputMessage(false)
    }
        
    func enableInputMessage(_ enable: Bool = true) {
        if (enable) {
            if (!showInputView) {
                toolBarRootView.isHidden = true
                showInputView = true
                inputMessageView.text = nil
                inputMessageView.becomeFirstResponder()
                self.inputMessageRootView.alpha = 0
                UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut, animations: {
                    self.inputMessageRootView.alpha = 1
                })
            }
        } else {
            if (showInputView) {
                toolBarRootView.isHidden = false
                showInputView = false
                inputMessageView.endEditing(true)
                inputMessageRootView.isHidden = true
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        hosterVideoView.delegate = self
        hosterVideoView.member = viewModel.speakers.hoster
        
        let id = NSStringFromClass(MessageView.self)
        chatListView.register(MessageView.self, forCellReuseIdentifier: id)
        chatListView.dataSource = self
        chatListView.rowHeight = UITableView.automaticDimension
        chatListView.estimatedRowHeight = 30
        chatListView.separatorStyle = .none
        chatListView.showsVerticalScrollIndicator = false
        chatListView.showsHorizontalScrollIndicator = false
        chatListView.transform = CGAffineTransform(scaleX: 1, y: -1)
        chatListView.layer.borderWidth = 1;
        chatListView.layer.borderColor = UIColor.systemGray.cgColor
        inputMessageView.returnKeyType = .send
        inputMessageView.delegate = self
        
        renderToolbar()
        subcribeUIEvent()
        subcribeRoomEvent()
        setupWhiteboard()
    }
    
    private func setupWhiteboard() {
        let board = WhiteBoardView()
        board.frame = self.WhiteboardContianer.bounds;
        self.WhiteboardContianer.addSubview(board)
        board.topAnchor.constraint(equalTo: self.WhiteboardContianer.topAnchor).isActive = true
        board.leftAnchor.constraint(equalTo: self.WhiteboardContianer.leftAnchor).isActive = true
        board.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        
        
        let config = WhiteSdkConfiguration(app: "792/uaYcRG0I7ctP9A")
        self.whiteSdk = WhiteSDK(whiteBoardView: board, config: config, commonCallbackDelegate: self, audioMixerBridgeDelegate: self)

        let roomConfig = WhiteRoomConfig(uuid: "daef60b584ea4892a381c410ae15fe28", roomToken: "WHITEcGFydG5lcl9pZD1ZSEpVMmoxVXAyUzdoQTluV3dvaVlSRVZ3MlI5M21ibmV6OXcmc2lnPWJkODdlOGFkZDcwZmEzN2YzNWQ3OTAyYmViMWFlMDk2YjQ1ZWI0MmM6YWRtaW5JZD02Njcmcm9vbUlkPWRhZWY2MGI1ODRlYTQ4OTJhMzgxYzQxMGFlMTVmZTI4JnRlYW1JZD03OTImcm9sZT1yb29tJmV4cGlyZV90aW1lPTE2MTIwMzU1MTgmYWs9WUhKVTJqMVVwMlM3aEE5bld3b2lZUkVWdzJSOTNtYm5lejl3JmNyZWF0ZV90aW1lPTE1ODA0Nzg1NjYmbm9uY2U9MTU4MDQ3ODU2NTczODAw")

        self.whiteSdk!.joinRoom(with: roomConfig, callbacks: self) { (success, room, error) in
            if ((room) != nil) {
                
            } else {
                print("join room failed \(String(describing: error))")
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self
        
    }
    
    override var shouldAutorotate: Bool {
            return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return [.landscapeRight, .landscapeLeft]
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .landscapeLeft
    }
    
    deinit {
        Logger.log(message: "RoomController deinit", level: .info)
    }
    
    public static func instance() -> RoomController {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: Utils.bundle)
        let controller = storyBoard.instantiateViewController(withIdentifier: "RoomController") as! RoomController
        return controller
    }
}

extension RoomController: RoomControlDelegate {
    func onTap(view: RoleVideoView) {
        
    }
}

extension RoomController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }
}

extension RoomController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.viewModel.messageList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = NSStringFromClass(MessageView.self)
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as! MessageView
        cell.contentView.transform = CGAffineTransform(scaleX: 1, y: -1)
        cell.message = self.viewModel.messageList[self.viewModel.messageList.count - 1 - indexPath.row]
        return cell
    }
}

extension RoomController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let message = textField.text {
            textField.text = nil
            if (!message.isEmpty) {
                self.viewModel
                    .sendMessage(message: message)
                    .subscribe(onNext: { [unowned self] result in
                        if (!result.success) {
                            self.show(message: result.message ?? "unknown error".localized, type: .error)
                        }
                    })
                    .disposed(by: disposeBag)
            }
        }
        enableInputMessage(false)
        return true
    }
}


extension RoomController: WhiteRoomCallbackDelegate {
    
}

extension RoomController: WhiteCommonCallbackDelegate {
    
}

extension RoomController: WhiteAudioMixerBridgeDelegate {

    func startAudioMixing(_ filePath: String, loopback: Bool, replace: Bool, cycle: Int) {
        
    }
    
    func stopAudioMixing() {
        
    }
    
    func setAudioMixingPosition(_ position: Int) {
        
    }
    
}
