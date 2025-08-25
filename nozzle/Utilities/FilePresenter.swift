import Foundation

// Lightweight NSFilePresenter to observe external edits to a single file
final class SingleFilePresenter: NSObject, NSFilePresenter {
    let presentedItemURL: URL?
    let presentedItemOperationQueue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        return q
    }()

    var onChange: (() -> Void)?

    init(url: URL, onChange: (() -> Void)? = nil) {
        self.presentedItemURL = url
        self.onChange = onChange
    }

    func presentedItemDidChange() {
        onChange?()
    }
}

