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
	@Binding var expiration: Date?
	@State private var isAccountMenuOpen = false
	@State private var isRoleMenuOpen = false

	var accounts: [AccountInfo]
	var onRefresh: () -> Void

	var body: some View {
		HStack {
			AccountPicker(selection: self.$selectedAccount, accounts: self.accounts)

			Divider()

			RolePicker(selection: self.$selectedRole, roles: self.selectedAccount?.roles ?? [])

			Spacer()

			Label { TimeTicker(endDate: self.$expiration) }

			Text("Spatial AWS")
				.font(.headline)
		}
		.padding(.horizontal)
		.frame(height: 40)
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
				Text(account.accountName).tag(account)
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
		.frame(width: 200)
	}
}
