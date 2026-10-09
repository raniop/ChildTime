package com.rani.tofy.kid.ui

import com.rani.tofy.i18n.tr

/**
 * "הִגַּעְתָּ לַמַּקְסִימוּם הַיּוֹמִי! … נִשְׁמְרוּ לְמָחָר" in one place, so one minute reads
 * "דַּקָּה אַחַת נִשְׁמְרָה" and not "1 דַּקּוֹת נִשְׁמְרוּ" — BankedNote.swift.
 */
object BankedNote {
    fun capReached(banked: Int, carry: Int, max: Int, isGirl: Boolean): String =
        if (banked == 1) {
            if (isGirl) tr("הִגַּעַתְּ לַמַּקְסִימוּם הַיּוֹמִי! דַּקָּה אַחַת נִשְׁמְרָה לְמָחָר 🎁 (%lld/%lld)", carry, max)
            else tr("הִגַּעְתָּ לַמַּקְסִימוּם הַיּוֹמִי! דַּקָּה אַחַת נִשְׁמְרָה לְמָחָר 🎁 (%lld/%lld)", carry, max)
        } else {
            if (isGirl) tr("הִגַּעַתְּ לַמַּקְסִימוּם הַיּוֹמִי! %lld דַּקּוֹת נִשְׁמְרוּ לְמָחָר 🎁 (%lld/%lld)", banked, carry, max)
            else tr("הִגַּעְתָּ לַמַּקְסִימוּם הַיּוֹמִי! %lld דַּקּוֹת נִשְׁמְרוּ לְמָחָר 🎁 (%lld/%lld)", banked, carry, max)
        }

    fun savedForTomorrow(minutes: Int): String =
        if (minutes == 1) tr("🎁 דַּקָּה אַחַת נִשְׁמְרָה לְמָחָר.") else tr("🎁 %lld דַּקּוֹת נִשְׁמְרוּ לְמָחָר.", minutes)
}
