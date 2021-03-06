//
//  PasscodeKeyboard.swift
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
import TinyConstraints

protocol PasscodeKeyboardDelegate: class {
    func keyboard(_ keyboard: PasscodeKeyboard, didInputDigit digit: String)
    func clearPressed(on keyboard: PasscodeKeyboard)
    func biometricsPressed(on keyboard: PasscodeKeyboard)
}

final class PasscodeKeyboard: UIView {
    weak var delegate: PasscodeKeyboardDelegate?

    private let mainStackView = UIStackView(frame: .zero)
    private let clearButton = UIImage(named: "ClearButton", in: Bundle.authenticator_main, compatibleWith: nil)
    private let biometricsButton = BiometricsPresenter.keyboardImage ?? UIImage()

    init(shouldShowTouchID: Bool) {
        super.init(frame: .zero)
        let keyboardLayout: [[Any]] = [
            ["1", "4", "7", shouldShowTouchID ? biometricsButton : ""],
            ["2", "5", "8", "0"],
            ["3", "6", "9", clearButton ?? ""]
        ]
        setupMainStackView()
        for column in keyboardLayout {
            setupVerticalButtonsStackView(with: column)
        }
        layout()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Setup
private extension PasscodeKeyboard {
    func setupMainStackView() {
        mainStackView.axis = .horizontal
        mainStackView.alignment = .fill
        mainStackView.spacing = 0.0
        mainStackView.distribution = .fillEqually
    }

    func setupVerticalButtonsStackView(with array: [Any]) {
        let stackView = UIStackView(frame: .zero)
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 0.0
        stackView.distribution = .fillEqually
        for value in array {
            stackView.addArrangedSubview(createButton(with: value))
        }
        mainStackView.addArrangedSubview(stackView)
    }

    func createButton(with value: Any) -> UIButton {
        let button = PasscodeKeyboardButton()

        if let title = value as? String {
            button.setTitle(title, for: .normal)
            button.setTitleColor(.auth_darkGray, for: .normal)
            button.titleLabel?.font = .auth_26regular
        } else if let image = value as? UIImage {
            button.setImage(image, for: .normal)
        }
        button.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchUpInside)
        return button
    }
}

// MARK: - Actions
private extension PasscodeKeyboard {
    @objc func buttonPressed(_ sender: TaptileFeedbackButton) {
        if let image = sender.image(for: .normal) {
            if image == clearButton {
                self.delegate?.clearPressed(on: self)
            } else if image == biometricsButton {
                self.delegate?.biometricsPressed(on: self)
            }
        } else if let title = sender.title(for: .normal), !title.isEmpty {
            self.delegate?.keyboard(self, didInputDigit: title)
        }
    }
}

// MARK: - Layout
extension PasscodeKeyboard: Layoutable {
    func layout() {
        addSubview(mainStackView)
        mainStackView.edges(to: self)
    }
}

private final class PasscodeKeyboardButton: TaptileFeedbackButton {
    override var intrinsicContentSize: CGSize {
        return CGSize(width: 320.0, height: 100.0)
    }

    override var shadowColor: CGColor {
        return UIColor.auth_blue20.cgColor
    }
}
