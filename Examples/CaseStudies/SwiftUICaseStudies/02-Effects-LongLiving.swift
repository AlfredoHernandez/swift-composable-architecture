import Combine
import ComposableArchitecture
import SwiftUI

private let readMe = """
  This application demonstrates how to handle long-living effects, for example notifications from \
  Notification Center.

  Run this application in the simulator, and take a few screenshots by going to \
  *Device › Screenshot* in the menu, and observe that the UI counts the number of times that \
  happens.

  Then, navigate to another screen and take screenshots there, and observe that this screen does \
  *not* count those screenshots.
  """

// MARK: - Application domain

struct LongLivingEffectsState: Equatable {
  var screenshotCount = 0
}

enum LongLivingEffectsAction {
  case userDidTakeScreenshotNotification
  case onAppear
  case onDisappear
}

struct LongLivingEffectsEnvironment {
  // An effect that emits Void whenever the user takes a screenshot of the device. We use this
  // instead of `NotificationCenter.default.publisher` directly in the reducer so that we can test
  // it.
  var userDidTakeScreenshot: Effect<Void, Never>
}

// MARK: - Business logic

let longLivingEffectsReducer = Reducer<
  LongLivingEffectsState, LongLivingEffectsAction, LongLivingEffectsEnvironment
> { state, action, environment in

  struct UserDidTakeScreenshotNotificationId: Hashable {}

  switch action {
  case .userDidTakeScreenshotNotification:
    state.screenshotCount += 1
    return .none

  case .onAppear:
    // When the view appears, start the effect that emits when screenshots are taken.
    return environment.userDidTakeScreenshot
      .map { LongLivingEffectsAction.userDidTakeScreenshotNotification }
      .cancellable(id: UserDidTakeScreenshotNotificationId())

  case .onDisappear:
    // When view disappears, stop the effect.
    return .cancel(id: UserDidTakeScreenshotNotificationId())
  }
}

// MARK: - SwiftUI view

struct LongLivingEffectsView: View {
  let store: MainActorStore<LongLivingEffectsState, LongLivingEffectsAction>
  @ObservedObject var viewStore: MainActorViewStore<LongLivingEffectsState, LongLivingEffectsAction>

  init(store: MainActorStore<LongLivingEffectsState, LongLivingEffectsAction>) {
    self.store = store
    self.viewStore = MainActorViewStore(store: self.store)
  }

  var body: some View {
    Form {
      Section(header: Text(template: readMe, .body)) {
        Text("A screenshot of this screen has been taken \(self.viewStore.screenshotCount) times.")
          .font(Font.headline)
      }

      Section {
        NavigationLink(destination: self.detailView) {
          Text("Navigate to another screen")
        }
      }
    }
    .navigationBarTitle("Long-living effects")
    .task {
      await self.viewStore.send(.onAppear)
    }
//    .onAppear { self.viewStore.send(.onAppear) }
//    .onDisappear { self.viewStore.send(.onDisappear) }
  }

  var detailView: some View {
    Text(
      """
      Take a screenshot of this screen a few times, and then go back to the previous screen to see \
      that those screenshots were not counted.
      """
    )
    .padding([.leading, .trailing], 64)
  }
}

// MARK: - SwiftUI previews

struct EffectsLongLiving_Previews: PreviewProvider {
  static var previews: some View {
    let appView = LongLivingEffectsView(
      store: MainActorStore(
        initialState: LongLivingEffectsState(),
        reducer: longLivingEffectsReducer,
        environment: LongLivingEffectsEnvironment(
          userDidTakeScreenshot: .none
        )
      )
    )

    return Group {
      NavigationView { appView }
      NavigationView { appView.detailView }
    }
  }
}