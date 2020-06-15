//
//  AuthorizationsViewModel
//  This file is part of the Salt Edge Authenticator distribution
//  (https://github.com/saltedge/sca-authenticator-ios)
//  Copyright © 2020 Salt Edge Inc.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, version 3 or later.
//
//  This program is distributed in the hope that it will be useful, but
//  WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
//  General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program. If not, see <http://www.gnu.org/licenses/>.
//
//  For the additional permissions granted for Salt Edge Authenticator
//  under Section 7 of the GNU General Public License see THIRD_PARTY_NOTICES.md
//

import UIKit
import SEAuthenticator

enum AuthorizationsViewModelState: Equatable {
    case changedConnectionsData
    case reloadData
    case scrollTo(Int)
    case presentFail(String)
    case scanQrPressed(Bool)
    case normal

    static func == (lhs: AuthorizationsViewModelState, rhs: AuthorizationsViewModelState) -> Bool {
        switch (lhs, rhs) {
        case (.changedConnectionsData, .changedConnectionsData), (.reloadData, .reloadData), (.normal, .normal): return true
        case let (.scrollTo(index1), .scrollTo(index2)): return index1 == index2
        case let (.presentFail(message1), .presentFail(message2)): return message1 == message2
        case let (.scanQrPressed(value1), .scanQrPressed(value2)): return value1 == value2
        default: return false
        }
    }
}

enum AuthorizationType {
    case list
    case single
}

protocol AuthorizationsViewModelEventsDelegate: class {
    func reloadData()
    func shouldDismiss()
    func scroll(to index: Int)
}

class AuthorizationsViewModel {
    private struct Images {
        static let noAuthorizations: UIImage = UIImage(named: "noAuthorizations", in: .authenticator_main, compatibleWith: nil)!
        static let noConnections: UIImage = UIImage(named: "noConnections", in: .authenticator_main, compatibleWith: nil)!
    }

    weak var delegate: AuthorizationsViewModelEventsDelegate?
    var state = Observable<AuthorizationsViewModelState>(.normal)

    var dataSource: AuthorizationsDataSource!
    private var connectionsListener: RealmConnectionsListener?

    private var poller: SEPoller?
    private var connections = ConnectionsCollector.activeConnections

    private var type: AuthorizationType

    var singleAuthorization: (connectionId: String, authorizationId: String)? {
        willSet {
            setupPolling()
        }
        didSet {
            getEncryptedAuthorizationsIfAvailable()
        }
    }

    init(type: AuthorizationType = .list) {
        self.type = type
        connectionsListener = RealmConnectionsListener(
            onDataChange: {
                self.state.value = .changedConnectionsData
            }
        )
    }

    func resetState() {
        state.value = .normal
    }

    var emptyViewData: EmptyViewData {
        if dataSource.hasConnections {
            return EmptyViewData(
                image: Images.noAuthorizations,
                title: l10n(.noAuthorizations),
                description: l10n(.noAuthorizationsDescription),
                buttonTitle: l10n(.scanQr)
            )
        } else {
            return EmptyViewData(
                image: Images.noConnections,
                title: l10n(.noConnections),
                description: l10n(.noConnectionsDescription),
                buttonTitle: l10n(.connect)
            )
        }
    }

    func confirmAuthorization(by authorizationId: String) {
        guard let data = dataSource.confirmationData(for: authorizationId),
            let detailViewModel = dataSource.viewModel(with: authorizationId) else { return }

        detailViewModel.state.value = .processing

        AuthorizationsInteractor.confirm(
            data: data,
            success: {
                detailViewModel.state.value = .success
                detailViewModel.actionTime = Date()
                after(3.0) {
                    self.delegate?.shouldDismiss()
                }
            },
            failure: { _ in
                detailViewModel.state.value = .undefined
                detailViewModel.actionTime = Date()
                after(3.0) {
                    self.delegate?.shouldDismiss()
                }
            }
        )
    }

    func denyAuthorization(by authorizationId: String) {
        guard let data = dataSource.confirmationData(for: authorizationId),
            let detailViewModel = dataSource.viewModel(with: authorizationId) else { return }

        detailViewModel.state.value = .processing

        AuthorizationsInteractor.deny(
            data: data,
            success: {
                detailViewModel.state.value = .denied
                detailViewModel.actionTime = Date()
                after(3.0) {
                    self.delegate?.shouldDismiss()
                }
            },
            failure: { _ in
                detailViewModel.state.value = .undefined
                detailViewModel.actionTime = Date()
                after(3.0) {
                    self.delegate?.shouldDismiss()
                }
            }
        )
    }

    private func updateDataSource(with authorizations: [SEAuthorizationData]) {
        if dataSource.update(with: authorizations) {
            delegate?.reloadData()
            state.value = .reloadData
        }

        if let authorizationToScroll = singleAuthorization {
            if let detailViewModel = dataSource.viewModel(
                by: authorizationToScroll.connectionId,
                authorizationId: authorizationToScroll.authorizationId
            ),
            let index = dataSource.index(of: detailViewModel) {
                delegate?.scroll(to: index)
                state.value = .scrollTo(index)
            } else {
                state.value = .presentFail(l10n(.authorizationNotFound))
            }
            singleAuthorization = nil
        }
    }
}

// MARK: - Polling
extension AuthorizationsViewModel {
    func setupPolling() {
        if poller == nil {
            poller = SEPoller(targetClass: self, selector: #selector(getEncryptedAuthorizationsIfAvailable))
            getEncryptedAuthorizationsIfAvailable()
            poller?.startPolling()
        }
    }

    func stopPolling() {
        poller?.stopPolling()
        poller = nil
    }
}

// MARK: - Actions
extension AuthorizationsViewModel {
    func scanQrPressed() {
        AVCaptureHelper.requestAccess(
            success: {
                self.state.value = .scanQrPressed(true)
            },
            failure: {
                self.state.value = .scanQrPressed(false)
            }
        )
    }
}

// MARK: - Data Source
extension AuthorizationsViewModel {
    var hasDataToShow: Bool {
        return dataSource.hasDataToShow
    }

    var numberOfRows: Int {
        return dataSource.rows
    }

    var numberOfSections: Int {
        return dataSource.sections
    }

    func detailViewModel(at index: Int) -> AuthorizationDetailViewModel? {
        return dataSource.viewModel(at: index)
    }
}

// MARK: - Networking
private extension AuthorizationsViewModel {
    @objc func getEncryptedAuthorizationsIfAvailable() {
        if poller != nil, connections.count > 0 {
            refresh()
        } else {
            updateDataSource(with: [])
        }
    }

    @objc func refresh() {
        AuthorizationsInteractor.refresh(
            connections: Array(connections),
            success: { [weak self] encryptedAuthorizations in
                guard let strongSelf = self else { return }

                DispatchQueue.global(qos: .background).async {
                    let decryptedAuthorizations = encryptedAuthorizations.compactMap {
                        AuthorizationsPresenter.decryptedData(from: $0)
                    }

                    DispatchQueue.main.async {
                        strongSelf.updateDataSource(with: decryptedAuthorizations)
                    }
                }
            },
            failure: { error in
                print(error)
            },
            connectionNotFoundFailure: { connectionId in
                if let id = connectionId, let connection = ConnectionsCollector.with(id: id) {
                    ConnectionRepository.setInactive(connection)
                }
            }
        )
    }
}
