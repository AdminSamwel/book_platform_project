"""
Kichujio cha lugha chafu / Profanity filter
============================================
Hutumika kuangalia na kuficha maneno machafu kwenye maoni (comments/chat),
kwa lugha ya Kiswahili na Kiingereza.

- contains_profanity(text)  -> True/False
- clean_text(text)          -> (matangazo_yaliyofichwa, orodha_ya_maneno_machafu)
"""

import re

# Orodha ya maneno machafu / makali (Kiswahili + Kiingereza).
# Tumeandika kwa herufi ndogo, mfumo unalinganisha bila kujali herufi kubwa/ndogo.
BAD_WORDS = {
    # --- Kiswahili ---
    "mjinga", "mjinga wewe", "pumbavu", "shenzi", "mshenzi", "zubaa",
    "mzubaji", "mbwa wewe", "fala", "mfala", "ng'ombe", "ngombe",
    "kahaba", "malaya", "mama yako", "baba yako", "kuma", "mkundu",
    "tako", "mavi", "mbobi", "shoga", "hovyo", "mjinga sana",
    "mpumbavu", "bonobo", "kondoo", "punda", "mpuuzi", "muuza tumbo",
    "chizi", "wende kachoma", "nenda kachoma", "fyatu", "fyat",
    "mboro", "uume", "mkundu wako", "kumbafu", "msenge", "hoyee shoga",

    # --- Kiingereza ---
    "fuck", "f*ck", "fucking", "fucker", "shit", "bullshit", "bitch",
    "asshole", "ass hole", "bastard", "dick", "cock", "pussy", "cunt",
    "whore", "slut", "nigger", "nigga", "retard", "moron", "idiot",
    "stupid", "dumbass", "motherfucker", "wanker", "douche", "twat",
    "jerk off", "screw you", "piss off", "suck my", "go to hell",
}

# Tengeneza regex moja kwa ufanisi - inazingatia mipaka ya neno.
_PATTERN = re.compile(
    r"(" + "|".join(re.escape(w) for w in sorted(BAD_WORDS, key=len, reverse=True)) + r")",
    flags=re.IGNORECASE,
)


def contains_profanity(text: str) -> bool:
    """Rudisha True kama maandishi yana neno chafu lolote."""
    if not text:
        return False
    return bool(_PATTERN.search(text))


def find_bad_words(text: str) -> list:
    """Rudisha orodha ya maneno machafu yaliyopatikana (bila kurudia)."""
    if not text:
        return []
    found = _PATTERN.findall(text)
    seen = []
    for w in found:
        lw = w.lower()
        if lw not in seen:
            seen.append(lw)
    return seen


def clean_text(text: str) -> str:
    """Badilisha kila neno chafu na alama za nyota (****)."""
    if not text:
        return text

    def _mask(match):
        word = match.group(0)
        if len(word) <= 2:
            return "*" * len(word)
        return word[0] + "*" * (len(word) - 2) + word[-1]

    return _PATTERN.sub(_mask, text)
