import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 2 // 默认选中排程页（C位）

    var body: some View {
        TabView(selection: $selectedTab) {
            FocusView()
                .tabItem {
                    Image(systemName: "timer")
                    Text("专注")
                }
                .tag(0)

            CoupleView()
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("情侣")
                }
                .tag(1)

            ScheduleView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("排程")
                }
                .tag(2)

            ChatView()
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("IM")
                }
                .tag(3)

            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("我的")
                }
                .tag(4)
        }
        .tint(.forest)
        .onAppear { Haptics.prepare() }
    }
}
