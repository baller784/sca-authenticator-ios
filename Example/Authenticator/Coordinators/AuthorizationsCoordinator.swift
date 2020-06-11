//
//  AuthorizationCoordinator.swift
//  This file is part of the Salt Edge Authenticator distribution
//  (https://github.com/saltedge/sca-authenticator-ios)
//  Copyright © 2019 Salt Edge Inc.
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

final class AuthorizationsCoordinator: Coordinator {
    let rootViewController = AuthorizationsViewController()
    private let dataSource = AuthorizationsDataSource()
    private let viewModel = AuthorizationsViewModel()

    private var qrCoordinator: QRCodeCoordinator?
    private var connectionsCoordinator: ConnectionsCoordinator?
    private var settingsCoordinator: SettingsCoordinator?

    func start() {
        viewModel.dataSource = dataSource
        viewModel.setupPolling()
        rootViewController.viewModel = viewModel
        rootViewController.delegate = self
    }

    func start(with connectionId: String, authorizationId: String) {
        viewModel.singleAuthorization = (connectionId: connectionId, authorizationId: authorizationId)
        start()
    }

    func stop() {
        viewModel.stopPolling()
    }
}

// MARK: - AuthorizationsViewControllerDelegate
extension AuthorizationsCoordinator: AuthorizationsViewControllerDelegate {
    func scanQrPressed() {
        qrCoordinator = QRCodeCoordinator(rootViewController: rootViewController)
        qrCoordinator?.start()
    }

    func showMoreOptionsMenu() {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        let cancel = UIAlertAction(title: l10n(.cancel), style: .cancel)
        let connections = UIAlertAction(title: l10n(.viewConnections), style: .default) { [weak self] _ in
            guard let strongSelf = self else { return }

            strongSelf.connectionsCoordinator = ConnectionsCoordinator(rootViewController: strongSelf.rootViewController)
            strongSelf.connectionsCoordinator?.start()
        }
        let consents = UIAlertAction(title: l10n(.viewConsents), style: .default) { _ in
            print("Show Consents")
        }
        let settings = UIAlertAction(title: l10n(.viewSettings), style: .default) { [weak self] _ in
            guard let strongSelf = self else { return }

            strongSelf.settingsCoordinator = SettingsCoordinator(rootController: strongSelf.rootViewController)
            strongSelf.settingsCoordinator?.start()
        }

        [connections, consents, settings, cancel].forEach { actionSheet.addAction($0) }

        rootViewController.present(actionSheet, animated: true)
    }
}
