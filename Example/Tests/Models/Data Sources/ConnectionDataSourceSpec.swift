//
//  ConnectionDataSourceSpec.swift
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

import Quick
import Nimble

class ConnectionDataSourceSpec: BaseSpec {
    override func spec() {
        var firstConnection, secondConnection: Connection!
        var dataSource: ConnectionsDataSource!
        var viewModel: ConnectionListViewModel!

        beforeEach {
            firstConnection = Connection()
            firstConnection.id = "first"
            firstConnection.accessToken = "12345aaa"

            ConnectionRepository.save(firstConnection)

            secondConnection = Connection()
            secondConnection.id = "second"
            secondConnection.accessToken = "6789bbb"

            ConnectionRepository.save(secondConnection)

            viewModel = ConnectionListViewModel()
            dataSource = ConnectionsDataSource(viewModel: viewModel)
        }

        afterEach {
            ConnectionRepository.deleteAllConnections()
        }

        describe("sections") {
            it("should return correct number of sections") {
                expect(dataSource.sections).to(equal(2))
            }
        }

        describe("rows(for)") {
            it("should return one row for section") {
                expect(dataSource.rows(for: 0)).to(equal(1))
            }
        }

        describe("height(for)") {
            it("should return 86") {
                expect(dataSource.height(for: 0)).to(equal(86.0))
            }
        }

        describe("hasDataToShow") {
            it("should return true") {
                expect(dataSource.hasDataToShow).to(beTrue())
            }
        }
    }
}
