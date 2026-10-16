"""iOS-specific next-reroll wording; upstream supplies Penny heads/tails text."""

TEXTS = {
    "en_us": ("Next reroll: {1}", "Will reroll", "First reroll only (1/2); the second outcome is not predicted"),
    "ru": ("Следующий реролл: {1}", "Будет заменён", "Только первый реролл (1/2); второй исход не предсказан"),
    "uk_ua": ("Наступний рерол: {1}", "Буде замінено", "Лише перший рерол (1/2); другий результат не передбачено"),
    "de": ("Nächster Reroll: {1}", "Wird neu gewürfelt", "Nur erster Reroll (1/2); zweites Ergebnis nicht vorhergesagt"),
    "fr": ("Prochain reroll : {1}", "Sera remplacé", "Premier reroll seulement (1/2) ; second résultat non prédit"),
    "spa": ("Siguiente reroll: {1}", "Se cambiará", "Solo el primer reroll (1/2); segundo resultado no predicho"),
    "it": ("Prossimo reroll: {1}", "Verrà sostituito", "Solo primo reroll (1/2); secondo risultato non previsto"),
    "pt": ("Próximo reroll: {1}", "Será substituído", "Apenas primeiro reroll (1/2); segundo resultado não previsto"),
    "pt_br": ("Próximo reroll: {1}", "Será substituído", "Apenas primeiro reroll (1/2); segundo resultado não previsto"),
    "pl": ("Następny reroll: {1}", "Zostanie zmieniony", "Tylko pierwszy reroll (1/2); drugi wynik nieprzewidziany"),
    "cs_cz": ("Další reroll: {1}", "Bude změněn", "Pouze první reroll (1/2); druhý výsledek není předpovězen"),
    "bul": ("Следващ рерол: {1}", "Ще бъде заменен", "Само първият рерол (1/2); вторият резултат не е предвиден"),
    "el_gr": ("Επόμενο reroll: {1}", "Θα αντικατασταθεί", "Μόνο το πρώτο reroll (1/2)· το δεύτερο δεν προβλέπεται"),
    "nl_nl": ("Volgende reroll: {1}", "Wordt vervangen", "Alleen eerste reroll (1/2); tweede uitkomst niet voorspeld"),
    "ro_ro": ("Următorul reroll: {1}", "Va fi înlocuit", "Doar primul reroll (1/2); al doilea rezultat nu este prezis"),
    "tr_tr": ("Sonraki yenileme: {1}", "Yenilenecek", "Yalnızca ilk yenileme (1/2); ikinci sonuç tahmin edilmedi"),
    "ja_jp": ("次のリロール：{1}", "別のアイテムになる", "1回目のみ予測 (1/2)・2回目は未予測"),
    "ko_kr": ("다음 리롤: {1}", "아이템 변경", "첫 리롤만 예측 (1/2); 두 번째 결과는 미예측"),
    "zh_cn": ("下次重置：{1}", "将重置为其他道具", "仅预测第一次 (1/2)；未预测第二次结果"),
    "vi": ("Lần đổi tiếp theo: {1}", "Sẽ đổi vật phẩm", "Chỉ dự đoán lần đầu (1/2); không dự đoán lần thứ hai"),
}


def outcome_strings(language):
    return dict(zip(("EternalD6Next", "EternalD6Survives", "EternalD6FirstOnly"),
                    TEXTS.get(language, TEXTS["en_us"])))
