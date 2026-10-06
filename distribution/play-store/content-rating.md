# Google Play — Content rating (IARC questionnaire)

> Play Console → Policy and programs → App content → **Content rating** → Start questionnaire.
> Email for the IARC certificate: **hello@tofyapp.com**. Answers reflect the Android build as of 2026-10-06.

## Category

**"Reference, News, or Educational"** — Tofy is a learning app whose game elements (mini-games, lucky wheel, chests) are rewards for learning, and the Play category is Education.
(If Rani prefers **"Game"**, every answer below is the same; the Game branch only adds the violence-in-gameplay wording.)

## Answers

| Section | Question (paraphrased) | Answer | Why |
|---|---|---|---|
| Violence | Violence of any kind, fantasy or realistic; blood; violence toward characters? | **No** | Cartoon animals, questions, mini-games (memory, sorting, counting, balloons). The "boss" round is a quiz, not combat. |
| Fear | Content that may scare young children? | **No** | |
| Sexuality | Nudity, sexual content or innuendo? | **No** | |
| Language | Profanity or crude language? | **No** | No free text from users anywhere. |
| Controlled substances | Drugs, alcohol, tobacco references? | **No** | |
| Crude humor | Bodily humor, toilet humor? | **No** | |
| Gambling | Real-money gambling? | **No** | |
| Gambling | Simulated gambling (casino, slots, betting)? | **No** | The lucky wheel and daily chest are **free** rewards earned by answering questions; nothing is staked, and spins/chests can never be bought. |
| Misc | Does the app contain or promote **randomized items purchased with real money** (loot boxes)? | **No** | 💎 bought with money buy a **chosen** character in the shop (and sibling minutes) — never a random reward. Wheel spins and chests are only earned, never bought. ⚠️ If 💎 ever buy chests or spins → **Yes**. |
| User interaction | Can users **interact or communicate** with each other (chat, comments, posts, voice, sharing UGC)? | **Yes** | A friends leaderboard and live quiz: players see each other's first name/nickname, character and score. **No** chat, messages, photos, voice or free text between users. |
| User interaction | Is user-to-user communication moderated / limited? | Limited: no free-form content at all; friends added only by QR / code / link; parents can see and remove friends. | |
| Sharing | Does the app **share the user's personal information** with other users or third parties? | **Yes** — the child's first name/nickname on leaderboard cards (visible to friends, and on the "All players" board to any Tofy user). | Answer honestly; it yields the "Users Interact"/"Shares Info" notice, not a higher age. If the global board is changed to initials/nickname-only, this can become No. |
| Sharing | Does the app share the user's **current physical location** with other users? | **No** | |
| Purchases | Does the app allow purchase of **digital goods**? | **Yes** if the uploaded build includes Play Billing (Tofy+ subscription, question packs / world passes, 💎 packs — in progress in `billing/`); **No** for a build without it. | All purchases sit behind the parent code (`BillingParentGate`). |
| Internet | Does the app provide **unrestricted internet access** (browser, search)? | **No** | Only fixed links (privacy, terms, support) open in the external browser, from parent screens. |
| Misc | Is the app a **web browser or search engine**? | **No** | |
| Misc | Does the app contain **news** content? | **No** | |
| Misc | Does the app contain content promoting **hate, discrimination**? | **No** | |
| Misc | Is the app primarily about **digital goods / commerce**? | **No** | |

## Expected result

- **IARC generic / PEGI:** 3 · **ESRB:** Everyone · **USK:** 0 · **ClassInd:** L · **ACB:** G
- Interactive elements: **Users Interact**, **Shares Info** (from the leaderboard), **In-App Purchases** (with Play Billing).

## Re-take the questionnaire when

- Play Billing (Tofy+ / 💎) is added → Digital purchases = Yes (and loot-box question if 💎 buy random rewards).
- Any free-text / photo exchange between users is added.
- The "All players" board is removed or anonymised (Sharing → No).
