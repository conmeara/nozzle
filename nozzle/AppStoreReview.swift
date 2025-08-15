import StoreKit
import Defaults

class AppStoreReview {
  class func ask() {
    Defaults[.numberOfUsages] += 1
    guard Defaults[.numberOfUsages] > 50 else { return }

    let today = Date()
    let lastReviewRequestDate = Defaults[.lastReviewRequestedAt]
    guard let minimumRequestDate = Calendar.current.date(byAdding: .month, value: 1, to: lastReviewRequestDate),
          today > minimumRequestDate else {
      return
    }

    Defaults[.lastReviewRequestedAt] = today

    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
      if #available(macOS 15.0, *) {
        if let window = NSApp.keyWindow,
           let contentViewController = window.contentViewController {
          AppStore.requestReview(in: contentViewController)
        }
        // No fallback on macOS 15.0+ - simply skip if no view controller available
      } else {
        SKStoreReviewController.requestReview()
      }
    }
  }
}
