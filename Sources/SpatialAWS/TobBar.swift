//
//  TobBar.swift
//  spatial-aws
//
//  Created by walter on 7/10/24.
//

import AWSSSO
import SwiftUI
import WebKit
import XDK
import XDKAWSSSO

struct TopBar: View {
	@Binding var selectedAccount: AccountInfo?
	@Binding var selectedRole: RoleInfo?
	@Binding var selectedService: String
	@Binding var selectedRegion: String
	@Binding var roleExpiration: Date?
	@Binding var tokenExpiration: Date?
	@State private var isAccountMenuOpen = false
	@State private var isRoleMenuOpen = false

	var services = XDKAWSSSO.loadTheServices()
	var accounts: [AccountInfo]
	var regions: [String] = XDKAWSSSO.regionsList
	var onRefresh: () -> Void

	var body: some View {
		VStack {
//			Spacer()
			HStack {
				AccountPicker(selection: self.$selectedAccount, accounts: self.accounts)

				Divider()

				RolePicker(selection: self.$selectedRole, roles: self.selectedAccount?.roles ?? [])

				Divider()

				Label { TimeTicker(endDate: self.$roleExpiration) }
				//			Label { TimeTicker(endDate: self.$tokenExpiration) }
				//
				//			Text("Spatial AWS")
				//				.font(.headline)
			}
			HStack {
//				Divider()

				ServicePicker(selection: self.$selectedService, services: self.services)

				Divider()
				//
				RegionPicker(selection: self.$selectedRegion, regions: self.regions)
				//
				//			Spacer()
			}
		}

		.padding(.horizontal)
		.frame(height: 80)
//		.background(Color(.windowBackgroundColor))
//		.border(Color(.separatorColor), width: 1)
	}
}

struct AccountPicker: View {
	@Binding var selection: AccountInfo?
	let accounts: [AccountInfo]

	var body: some View {
		Picker("Account", selection: self.$selection) {
			ForEach(self.accounts, id: \.accountID) { account in
				Text(account.accountName == "nugg.xyz" ? "primary" : account.accountName).tag(account)
			}
		}
		.frame(width: 200)
	}
}

struct RolePicker: View {
	@Binding var selection: RoleInfo?
	let roles: [RoleInfo]

	var body: some View {
		Picker("Role", selection: self.$selection) {
			ForEach(self.roles, id: \.roleName) { role in
				Text(role.roleName).tag(role)
			}
		}
		.frame(width: 300)
	}
}

struct ServicePicker: View {
	@Binding var selection: String
	let services: [String]

	var body: some View {
		Picker("Service", selection: self.$selection) {
			ForEach(self.services, id: \.self) { service in
				Text(service).tag(service)
			}
		}
		.frame(width: 200)
	}
}

struct RegionPicker: View {
	@Binding var selection: String
	let regions: [String]

	var body: some View {
		Picker("Region", selection: self.$selection) {
			ForEach(self.regions, id: \.self) { region in
				Text(region).tag(region)
			}
		}
		.frame(width: 200)
	}
}
