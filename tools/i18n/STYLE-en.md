# Tofy — English (US) translation guide

Tofy is a family app: children earn screen time by answering learning questions;
parents set the rules. The Hebrew source has two voices — keep them distinct.

## Voices
- **Kid-facing** (question screen, worlds, rewards, the fox companion, shop, games):
  warm, short, upbeat, 2nd person, simple words a 6–10-year-old reads. Exclamation
  marks are fine here. Never shaming: mistakes are "almost!", "so close".
- **Parent-facing** (dashboard, settings, reports, paywall, onboarding, alerts):
  clear, calm, concise US English. Sentence case. Contractions are fine. No hype.

## Hard rules
1. **Placeholders are sacred.** Keep every `%@`, `%lld`, `%d`, `%.1f`, `%%` exactly —
   same count and types. You may reorder with positional forms (`%1$@`, `%2$lld`).
   `%%` is a literal percent sign.
2. **Keep emoji** and their position (start/end) where they carry meaning.
3. **Gender variants → one English sentence.** The source often has two keys that
   differ only by Hebrew gender (עָנָה / עָנְתָה, "בּוֹא"/"בּוֹאִי", "ילד/ה"). Translate both
   identically unless a pronoun is needed (he/she) — prefer names or "they"/"your child".
3b. A placeholder that stands for a Hebrew gendered *word* (e.g. `%@` filled with
   "מצא"/"מצאה") will receive the English translation of that word — write the
   sentence so it still reads naturally.
4. **Length:** UI text lives on phone buttons and tiles — stay close to the Hebrew
   length; short labels stay short.
5. **Hebrew prefix glued to a placeholder** (`לְ%@`, `מ%@`, `בְּ%@`, `שֶׁל %@`) is a
   preposition + name: "to %@", "from %@", "in %@", "%@'s".
6. **Don't translate** brand names: Tofy, Tofy+, Apple ID, Face ID, iPad, iPhone,
   Screen Time (Apple's feature). Keep `QR` as is.
7. Numbers/currency inside the text stay as the placeholder provides them.
8. If the Hebrew is a fragment meant to be concatenated (starts/ends with a space or
   "·"), keep the same leading/trailing spaces and separators.

## Glossary (use exactly)
| Hebrew | English |
|---|---|
| טוֹפִי / טופי | Tofy |
| טוֹפִי+ | Tofy+ |
| טוֹפִי טַיים | Tofy Time |
| דַּקּוֹת מִשְׂחָק / זְמַן מִשְׂחָק | play minutes / play time |
| זְמַן מָסָךְ | screen time |
| כּוֹכָבִים ⭐ | stars |
| יַהֲלוֹמִים 💎 | diamonds |
| עוֹלָם / עוֹלָמוֹת | world / worlds |
| הַזִּירָה | the Arena |
| מַטָּלוֹת / מטלות בית | chores |
| מַצַּב יֶלֶד | Kid Mode |
| מַכְשִׁיר הוֹרֶה / מַכְשִׁיר יֶלֶד | parent device / child's device |
| קוֹד הוֹרֶה | parent code |
| שַׁעַר הוֹרִים | parent gate |
| מַתָּנָה (דקות מתנה / טופי+ במתנה) | gift (gift minutes / Tofy+ gift) |
| תֵּבָה יוֹמִית | daily chest |
| גַּלְגַּל הַמַּזָּל | lucky wheel |
| שְׁאֵלַת בּוֹנוּס | bonus question |
| שְׁאֵלַת זָהָב | golden question |
| רֶצֶף | streak ("5 in a row") |
| רֶמֶז | hint |
| דּוּחַ / דּוּחוֹת | report / reports |
| תּוֹבָנוֹת | insights |
| הַמִּשְׁפָּחָה / לוּחַ הַמִּשְׁפָּחָה | the family / family board |
| חֲבֵרִים | friends |
| מִשְׂחָק חַי | live game |
| כִּתָּה א׳ … ח׳ | 1st grade … 8th grade |
| גַּן חוֹבָה / גַּן טְרוֹם־חוֹבָה | Kindergarten / Pre-K |
| חֲבִילַת שְׁאֵלוֹת / עוֹלָם בְּתַשְׁלוּם | question pack / premium world |
| הַרְפַּתְקָה חֲכָמָה | Smart Adventure |
| הֲנָחָה לְאַח / לְאָחוֹת | sibling discount |
| שָׁמוּר / נִשְׁמַר לְמָחָר | saved for tomorrow |

## Output
A JSON object mapping each Hebrew key to its English value, nothing else.
