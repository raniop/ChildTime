# Location Push Service Extension — entitlement request (draft)

Form: https://developer.apple.com/contact/request/location-push-service-extension
Sign in as the Tofy account holder (Rani Ophir) and paste the answers below.

- **App name:** Tofy (טופי: לומדים ומרוויחים זמן מסך)
- **Apple ID:** 6773805449
- **Bundle ID:** com.rani.ChildTime
- **Team ID:** TFG2H9C76N

## How will your app use the Location Push Service Extension?

Tofy is a family app: parents manage their children's screen time and learning, and can choose to see where their child's phone is. Location sharing is off by default. It is switched on per child, only by a parent, after a consent screen that explains what is stored and who can see it. The child's phone then shows its own explanation before iOS asks for permission.

When a parent opens the family map or taps "Refresh", our server sends a location push to that child's device. The Location Push Service Extension answers with one current location, which is written to the family's private record and shown only to the parents of that family.

The extension would be used only for these explicit parent requests. There is no continuous tracking and no location history: we keep only the last location of each device. Turning sharing off deletes it immediately.

## Why is this needed?

Today we rely on silent background pushes. iOS throttles them and does not deliver them at all when the app has been closed from the app switcher. A parent who is worried about where their child is gets no answer exactly when it matters. The Location Push Service Extension is the mechanism Apple designed for "share my location when a family member asks".

## Privacy

- Location is sent only to our own backend (Firebase), never to third parties.
- There is no advertising, no analytics SDK and no tracking.
- The data is visible only to the parents of the same family.
- Only the last fix is kept. Arrival/departure notices are deleted as soon as they are delivered.
- The privacy policy is at https://tofyapp.com/privacy.
- The user, or a parent, can turn it off at any time in the app or in Settings.
