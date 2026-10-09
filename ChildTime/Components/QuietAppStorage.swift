import SwiftUI
import Combine

/// `@AppStorage` that redraws its view only when ITS key changes.
///
/// SwiftUI's `@AppStorage` re-ran the whole view on EVERY write to the same
/// UserDefaults — measured: an unrelated key written every 2s redrew the kid's
/// home every 2s, and during a quiz (progress, history, question memory all
/// saving) the hidden home and the app root redrew 3× per answer at 50–90ms
/// each on Rani's iPhone. This one still hears every write, but compares its
/// own value and publishes only a real change.
@propertyWrapper
struct QuietAppStorage<Value: Equatable>: DynamicProperty {
    @StateObject private var box: Box

    init(wrappedValue: Value, _ key: String, store: UserDefaults = .standard) {
        _box = StateObject(wrappedValue: Box(key: key, fallback: wrappedValue, store: store))
    }

    var wrappedValue: Value {
        get { box.value }
        nonmutating set { box.write(newValue) }
    }

    final class Box: ObservableObject {
        @Published private(set) var value: Value
        private let key: String
        private let fallback: Value
        private let store: UserDefaults
        private var sub: AnyCancellable?

        init(key: String, fallback: Value, store: UserDefaults) {
            self.key = key; self.fallback = fallback; self.store = store
            value = store.object(forKey: key) as? Value ?? fallback
            sub = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification, object: store)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.reload() }
        }

        private func reload() {
            let now = store.object(forKey: key) as? Value ?? fallback
            if now != value { value = now }
        }

        func write(_ newValue: Value) {
            store.set(newValue, forKey: key)
            if newValue != value { value = newValue }
        }
    }
}
