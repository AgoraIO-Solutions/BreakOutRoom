//
//  HomeController.swift
//  Classroom
//

import Foundation
import UIKit
import RxSwift
import RxCocoa
import Core


enum ClassRole {
    case teacher
    case student
    func description() -> String {
        switch self {
        case .teacher: return "Teacher".localized
        case .student: return "Student".localized
        }
    }
}

public class ClassRoomHomeController: BaseViewContoller {
    @IBOutlet weak var joinButton: UIButton!
    @IBAction func join(sender: UIButton) {
        guard let channelName = channelTextField.text else {return}
        //resign channel text field
        channelTextField.resignFirstResponder()
        viewModel.createRoom(with: channelName)
            .observe(on: MainScheduler.instance)
            .do(onSubscribe: {
                self.show(processing: true)
            }, onDispose: {
                self.show(processing: false)
            })
            .subscribe() { [unowned self] result in
                if (result.success) {
                    guard let room = result.data else {
                        return
                    }
                    viewModel.join(room: room)
                        .observe(on: MainScheduler.instance)
                        .do(onSubscribe: {
                            self.show(processing: true)
                        }, onDispose: {
                            self.show(processing: false)
                        })
                        .subscribe() { [unowned self] result in
                            if (result.success) {
                                let controller = RoomController.instance()
                                self.navigationController?.pushViewController(controller, animated: true)
                            } else {
                                self.show(message: result.message ?? "unknown error".localized, type: .error)
                            }
                        } onDisposed: {
                            self.show(processing: false)
                        }
                        .disposed(by: disposeBag)
                } else {
                    self.show(message: result.message ?? "unknown error".localized, type: .error)
                }
            } onDisposed: {
                self.show(processing: false)
            }
            .disposed(by: disposeBag)
    }
    
    @IBOutlet weak var channelTextField: UITextField!
    @IBOutlet var roleBtn: UIButton!
    var role:ClassRole = .teacher
    
    func getRole(_ role:ClassRole) -> UIAlertAction {
        return UIAlertAction(title: "\(role.description())", style: .default, handler: {[unowned self] action in
            self.role = role
            self.roleBtn.setTitle("\(role.description())", for: .normal)
        })
    }
    
    @IBAction func setRole() {
        let alert = UIAlertController(title: "Set Role".localized, message: nil, preferredStyle: .actionSheet)
        alert.addAction(getRole(.teacher))
        alert.addAction(getRole(.student))
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private var viewModel: HomeViewModel!
    
    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return [.portrait]
    }
    
    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    func configNavbar() {
        self.title = "Lecture Hall".localized
        if let navBar = navigationController?.navigationBar {
            navBar.tintColor = .systemBlue
            navBar.backItem?.backButtonTitle = "Back".localized
            
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.titleTextAttributes = [.foregroundColor: UIColor.systemBlue]
            navigationItem.standardAppearance = appearance
            navigationItem.scrollEdgeAppearance = appearance
        }
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
        roleBtn.setTitle("\(role.description())", for: .normal)
        configNavbar()
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        viewModel = HomeViewModel()
        viewModel.setup()
            .do(onSubscribe: {
                self.show(processing: true)
            }, onDispose: {
                self.show(processing: false)
            })
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [unowned self] result in
                if (!result.success) {
                    self.show(message: result.message ?? "unknown error".localized, type: .error)
                }
            })
            .disposed(by: disposeBag)
    }
    
    deinit {
        Logger.log(message: "HomeController deinit", level: .info)
        let _ = RoomManager.shared().leave().subscribe()
        RoomManager.shared().destory()
    }
    
    public static func instance() -> ClassRoomHomeController {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: Utils.bundle)
        let controller = storyBoard.instantiateViewController(withIdentifier: "HomeController") as! ClassRoomHomeController
        return controller
    }
}
